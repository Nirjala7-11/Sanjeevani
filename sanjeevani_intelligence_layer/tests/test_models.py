"""
Tests for typed data models — validation, immutability, serialization.
"""
import sys
sys.path.insert(0, "/home/claude/sanjeevani_pro")

import pytest
from sanjeevani.core.models import (
    ClinicalRecommendation, KnowledgePassage,
    PatientVitals, RiskLevel, RiskResult,
)
from sanjeevani.exceptions import BoundaryError


class TestPatientVitals:

    def test_valid_vitals_accepted(self):
        v = PatientVitals(75.0, 98.0, 98.6)
        assert v.heart_rate_bpm == 75.0
        assert v.spo2_pct == 98.0
        assert v.temperature_f == 98.6

    def test_frozen_after_construction(self):
        v = PatientVitals(75.0, 98.0, 98.6)
        with pytest.raises((AttributeError, TypeError)):
            v.heart_rate_bpm = 100

    # Heart rate bounds
    def test_hr_below_minimum_rejected(self):
        with pytest.raises(BoundaryError, match="Heart rate"):
            PatientVitals(5.0, 98.0, 98.6)

    def test_hr_above_maximum_rejected(self):
        with pytest.raises(BoundaryError, match="Heart rate"):
            PatientVitals(500.0, 98.0, 98.6)

    def test_hr_at_minimum_accepted(self):
        v = PatientVitals(20.0, 98.0, 98.6)
        assert v.heart_rate_bpm == 20.0

    def test_hr_at_maximum_accepted(self):
        v = PatientVitals(250.0, 98.0, 98.6)
        assert v.heart_rate_bpm == 250.0

    # SpO2 bounds
    def test_spo2_above_100_rejected(self):
        with pytest.raises(BoundaryError, match="SpO2"):
            PatientVitals(75.0, 101.0, 98.6)

    def test_spo2_at_100_accepted(self):
        v = PatientVitals(75.0, 100.0, 98.6)
        assert v.spo2_pct == 100.0

    def test_spo2_below_minimum_rejected(self):
        with pytest.raises(BoundaryError):
            PatientVitals(75.0, 10.0, 98.6)

    # Temperature bounds
    def test_temperature_too_high_rejected(self):
        with pytest.raises(BoundaryError, match="Temperature"):
            PatientVitals(75.0, 98.0, 200.0)

    def test_temperature_too_low_rejected(self):
        with pytest.raises(BoundaryError):
            PatientVitals(75.0, 98.0, 50.0)

    def test_temperature_at_bounds_accepted(self):
        v1 = PatientVitals(75.0, 98.0, 86.0)
        v2 = PatientVitals(75.0, 98.0, 115.0)
        assert v1.temperature_f == 86.0
        assert v2.temperature_f == 115.0

    # Error message quality
    def test_boundary_error_message_contains_value(self):
        try:
            PatientVitals(999.0, 98.0, 98.6)
        except BoundaryError as e:
            assert "999" in str(e)

    def test_boundary_error_message_contains_label(self):
        try:
            PatientVitals(999.0, 98.0, 98.6)
        except BoundaryError as e:
            assert "Heart rate" in str(e)


class TestRiskResult:

    def test_high_risk_requires_referral(self):
        r = RiskResult(score=10, level=RiskLevel.HIGH, alerts=())
        assert r.requires_referral is True

    def test_medium_risk_does_not_require_referral(self):
        r = RiskResult(score=3, level=RiskLevel.MEDIUM, alerts=())
        assert r.requires_referral is False

    def test_low_risk_does_not_require_referral(self):
        r = RiskResult(score=0, level=RiskLevel.LOW, alerts=())
        assert r.requires_referral is False

    def test_frozen(self):
        r = RiskResult(score=0, level=RiskLevel.LOW, alerts=())
        with pytest.raises((AttributeError, TypeError)):
            r.score = 99

    def test_alerts_is_tuple(self):
        r = RiskResult(score=2, level=RiskLevel.MEDIUM, alerts=("Fever",))
        assert isinstance(r.alerts, tuple)


class TestClinicalRecommendation:

    def _make(self, **kwargs) -> ClinicalRecommendation:
        defaults = dict(
            condition="Test condition",
            advice="Test advice",
            referral_needed=False,
            risk=RiskResult(score=0, level=RiskLevel.LOW, alerts=()),
            sources=(),
        )
        defaults.update(kwargs)
        return ClinicalRecommendation(**defaults)

    def test_to_dict_has_required_keys(self):
        rec = self._make()
        d = rec.to_dict()
        for key in ("condition", "advice", "referral_needed",
                    "risk_level", "risk_score", "alerts",
                    "is_fallback", "sources"):
            assert key in d, f"Missing key: {key}"

    def test_to_dict_risk_level_is_string(self):
        rec = self._make()
        d = rec.to_dict()
        assert isinstance(d["risk_level"], str)

    def test_to_dict_sources_serialized(self):
        passage = KnowledgePassage(
            entry_id="kb-001",
            source_ref="IMNCI 4.2",
            text="Some protocol text",
            similarity=0.85,
        )
        rec = self._make(sources=(passage,))
        d = rec.to_dict()
        assert len(d["sources"]) == 1
        assert d["sources"][0]["entry_id"] == "kb-001"
        assert d["sources"][0]["similarity"] == 0.85

    def test_default_is_fallback_false(self):
        rec = self._make()
        assert rec.is_fallback is False

    def test_frozen(self):
        rec = self._make()
        with pytest.raises((AttributeError, TypeError)):
            rec.condition = "changed"
