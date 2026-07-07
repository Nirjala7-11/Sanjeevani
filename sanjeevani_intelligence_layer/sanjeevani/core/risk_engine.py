"""
Deterministic, LLM-free risk scoring engine.

Why this is intentionally the simplest, most boring module in the package:

  1. Reproducibility: same vitals always produce the same score.
     Determinism is non-negotiable in a medical decision-support tool.

  2. Auditability: a doctor can read assess() and verify it by hand.
     There are no probabilistic components, no hidden state, no side effects.

  3. Independence: this runs correctly whether or not any model is
     available. The risk score exists even when inference fails.
     The output_guard uses it to construct a safe fallback recommendation.

  4. Trust hierarchy: the risk score is the FLOOR, not the ceiling.
     The LLM may escalate a recommendation; it may never de-escalate one
     the risk engine set. This property is enforced in output_guard.py.

Zero network calls. Zero model dependencies. Zero side effects.
"""
from __future__ import annotations

import logging

from sanjeevani.config import CFG
from sanjeevani.core.models import PatientVitals, RiskLevel, RiskResult

log = logging.getLogger("sanjeevani.core.risk_engine")


def _compute_score(v: PatientVitals) -> int:
    """Pure function: PatientVitals → integer score. No side effects."""
    w = CFG.scoring
    t = CFG.clinical
    score = 0

    # Heart rate (mutually exclusive — only the higher tier fires)
    if   v.heart_rate_bpm >= t.hr_critical_bpm:  score += w.hr_critical
    elif v.heart_rate_bpm >  t.hr_elevated_bpm:  score += w.hr_elevated

    # SpO2 (lower is worse — inverted comparison)
    if   v.spo2_pct <= t.spo2_critical_pct: score += w.spo2_critical
    elif v.spo2_pct <  t.spo2_low_pct:      score += w.spo2_low

    # Temperature
    if   v.temperature_f >= t.temp_high_fever_f: score += w.high_fever
    elif v.temperature_f >  t.temp_fever_f:      score += w.fever

    return score


def _band(score: int) -> RiskLevel:
    """Map a numeric score to a RiskLevel band."""
    w = CFG.scoring
    if score <= w.cut_low:    return RiskLevel.LOW
    if score <= w.cut_medium: return RiskLevel.MEDIUM
    return RiskLevel.HIGH


def _build_alerts(v: PatientVitals) -> tuple[str, ...]:
    """Human-readable labels for each fired alert trigger."""
    t = CFG.clinical
    alerts: list[str] = []

    if   v.heart_rate_bpm >= t.hr_critical_bpm:
        alerts.append(f"Critically high heart rate ({v.heart_rate_bpm:.0f} bpm)")
    elif v.heart_rate_bpm >  t.hr_elevated_bpm:
        alerts.append(f"Elevated heart rate ({v.heart_rate_bpm:.0f} bpm)")

    if   v.spo2_pct <= t.spo2_critical_pct:
        alerts.append(f"Critically low oxygen — SpO2 {v.spo2_pct:.0f}%")
    elif v.spo2_pct <  t.spo2_low_pct:
        alerts.append(f"Low oxygen — SpO2 {v.spo2_pct:.0f}%")

    if   v.temperature_f >= t.temp_high_fever_f:
        alerts.append(f"High fever ({v.temperature_f:.1f}°F)")
    elif v.temperature_f >  t.temp_fever_f:
        alerts.append(f"Fever ({v.temperature_f:.1f}°F)")

    return tuple(alerts)


def assess(vitals: PatientVitals) -> RiskResult:
    """
    Single public entry point.
    Pure function: PatientVitals → RiskResult.
    Cannot fail if vitals passed validation.
    """
    score  = _compute_score(vitals)
    level  = _band(score)
    alerts = _build_alerts(vitals)

    log.info(
        "Risk assessed | score=%d level=%s alerts_count=%d",
        score, level.value, len(alerts),
    )

    return RiskResult(score=score, level=level, alerts=alerts)
