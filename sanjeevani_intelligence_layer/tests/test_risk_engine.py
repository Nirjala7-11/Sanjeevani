"""
Tests for the deterministic risk scoring engine.

These tests document and enforce the clinical logic, not just implementation
details. If a test fails after a config change, that means the clinical
calibration changed — which needs deliberate review, not just a test fix.
"""
import sys
sys.path.insert(0, "/home/claude/sanjeevani_pro")

import pytest
from sanjeevani.config import CFG
from sanjeevani.core.models import PatientVitals, RiskLevel
from sanjeevani.core.risk_engine import _band, _build_alerts, _compute_score, assess


def vitals(hr=75.0, spo2=98.0, temp=98.0) -> PatientVitals:
    """Convenience factory for test vitals."""
    return PatientVitals(hr, spo2, temp)


class TestScoreComputation:

    def test_all_normal_scores_zero(self):
        assert _compute_score(vitals()) == 0

    def test_elevated_hr_adds_elevated_weight(self):
        v = vitals(hr=CFG.clinical.hr_elevated_bpm + 1)
        assert _compute_score(v) == CFG.scoring.hr_elevated

    def test_critical_hr_adds_critical_weight_not_elevated(self):
        """Critical tier fires; elevated tier must NOT double-count."""
        v = vitals(hr=CFG.clinical.hr_critical_bpm + 1)
        score = _compute_score(v)
        assert score == CFG.scoring.hr_critical
        assert score != CFG.scoring.hr_elevated + CFG.scoring.hr_critical

    def test_low_spo2_adds_low_weight(self):
        v = vitals(spo2=CFG.clinical.spo2_low_pct - 1)
        assert _compute_score(v) == CFG.scoring.spo2_low

    def test_critical_spo2_adds_critical_weight_not_low(self):
        v = vitals(spo2=CFG.clinical.spo2_critical_pct - 1)
        score = _compute_score(v)
        assert score == CFG.scoring.spo2_critical

    def test_fever_adds_fever_weight(self):
        v = vitals(temp=CFG.clinical.temp_fever_f + 0.5)
        assert _compute_score(v) == CFG.scoring.fever

    def test_high_fever_adds_high_fever_weight_not_fever(self):
        v = vitals(temp=CFG.clinical.temp_high_fever_f + 0.5)
        score = _compute_score(v)
        assert score == CFG.scoring.high_fever

    def test_combined_all_elevated_tier_accumulates(self):
        v = vitals(
            hr=CFG.clinical.hr_elevated_bpm + 5,
            spo2=CFG.clinical.spo2_low_pct - 1,
            temp=CFG.clinical.temp_fever_f + 1,
        )
        expected = (
            CFG.scoring.hr_elevated +
            CFG.scoring.spo2_low +
            CFG.scoring.fever
        )
        assert _compute_score(v) == expected

    def test_score_is_non_negative(self):
        assert _compute_score(vitals()) >= 0


class TestRiskBanding:

    def test_score_zero_is_low(self):
        assert _band(0) == RiskLevel.LOW

    def test_cut_low_score_is_low(self):
        assert _band(CFG.scoring.cut_low) == RiskLevel.LOW

    def test_cut_low_plus_one_is_medium(self):
        assert _band(CFG.scoring.cut_low + 1) == RiskLevel.MEDIUM

    def test_cut_medium_is_medium(self):
        assert _band(CFG.scoring.cut_medium) == RiskLevel.MEDIUM

    def test_cut_medium_plus_one_is_high(self):
        assert _band(CFG.scoring.cut_medium + 1) == RiskLevel.HIGH

    def test_very_high_score_is_high(self):
        assert _band(100) == RiskLevel.HIGH


class TestCriticalAlertsReachHigh:
    """
    Design property: any single critical-tier alert must produce HIGH risk.
    This test class makes that property explicit and testable.
    """

    def test_critically_low_spo2_alone_is_high(self):
        v = vitals(spo2=CFG.clinical.spo2_critical_pct - 1)
        r = assess(v)
        assert r.level == RiskLevel.HIGH, (
            f"SpO2 at {CFG.clinical.spo2_critical_pct - 1}% must reach HIGH "
            f"risk alone. Got {r.level.value} (score={r.score}). "
            f"Check spo2_critical weight vs cut_medium in config."
        )

    def test_critically_high_hr_alone_is_high(self):
        v = vitals(hr=CFG.clinical.hr_critical_bpm + 1)
        r = assess(v)
        assert r.level == RiskLevel.HIGH, (
            f"HR at {CFG.clinical.hr_critical_bpm + 1} bpm must reach HIGH "
            f"risk alone. Got {r.level.value} (score={r.score})."
        )

    def test_high_fever_alone_is_high(self):
        v = vitals(temp=CFG.clinical.temp_high_fever_f + 0.5)
        r = assess(v)
        assert r.level == RiskLevel.HIGH, (
            f"Temp at {CFG.clinical.temp_high_fever_f + 0.5}°F must reach "
            f"HIGH risk alone. Got {r.level.value} (score={r.score})."
        )


class TestAlertMessages:

    def test_no_alerts_for_normal_vitals(self):
        r = assess(vitals())
        assert r.alerts == ()

    def test_elevated_hr_alert_message_contains_value(self):
        hr = CFG.clinical.hr_elevated_bpm + 10
        r = assess(vitals(hr=hr))
        assert any(str(int(hr)) in a for a in r.alerts)

    def test_fever_alert_message_contains_temperature(self):
        temp = CFG.clinical.temp_fever_f + 1
        r = assess(vitals(temp=temp))
        assert any(str(temp) in a for a in r.alerts)

    def test_critical_spo2_alert_message_distinct_from_low(self):
        low_r      = assess(vitals(spo2=CFG.clinical.spo2_low_pct - 1))
        critical_r = assess(vitals(spo2=CFG.clinical.spo2_critical_pct - 1))
        assert low_r.alerts != critical_r.alerts

    def test_alerts_are_tuple_type(self):
        r = assess(vitals(hr=110, spo2=88, temp=102))
        assert isinstance(r.alerts, tuple)


class TestAssessIntegration:

    def test_classic_pneumonia_pattern_is_high(self):
        """120 bpm / SpO2 88% / 102°F — the example from the project brief."""
        r = assess(vitals(hr=120, spo2=88, temp=102))
        assert r.level == RiskLevel.HIGH
        assert r.requires_referral is True

    def test_all_normal_is_low_no_referral(self):
        r = assess(vitals())
        assert r.level == RiskLevel.LOW
        assert r.requires_referral is False
        assert r.score == 0

    def test_determinism_100_runs(self):
        """Same input must produce identical output every time — no randomness."""
        v = vitals(hr=110, spo2=90, temp=101)
        results = {(assess(v).score, assess(v).level) for _ in range(100)}
        assert len(results) == 1, "Risk score is non-deterministic — this is a bug"

    def test_result_is_immutable(self):
        r = assess(vitals())
        with pytest.raises((AttributeError, TypeError)):
            r.score = 999
