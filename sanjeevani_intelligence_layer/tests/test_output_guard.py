"""
Tests for the output safety guard — the most critical security module.

Every test here encodes a property that must hold for patient safety.
Treat test failures here as clinical safety issues, not just bugs.
"""
import sys
sys.path.insert(0, "/home/claude/sanjeevani_pro")

import pytest
from sanjeevani.core.models import RiskLevel, RiskResult
from sanjeevani.safety.output_guard import validate


def risk(level: RiskLevel, score: int = 0) -> RiskResult:
    return RiskResult(score=score, level=level, alerts=())


def risk_high() -> RiskResult:
    return risk(RiskLevel.HIGH, score=8)


def risk_med() -> RiskResult:
    return risk(RiskLevel.MEDIUM, score=3)


def risk_low() -> RiskResult:
    return risk(RiskLevel.LOW, score=0)


class TestParsing:

    def test_well_formed_output_parsed_correctly(self):
        raw = (
            "Possible condition: Respiratory infection\n"
            "Advice: Refer to PHC immediately\n"
            "Referral needed: Yes"
        )
        rec = validate(raw, risk_med(), ())
        assert rec.is_fallback is False
        assert rec.condition == "Respiratory infection"
        assert rec.advice == "Refer to PHC immediately"
        assert rec.referral_needed is True

    def test_referral_no_parsed_correctly(self):
        raw = (
            "Possible condition: Mild viral illness\n"
            "Advice: Rest and monitor at home\n"
            "Referral needed: No"
        )
        rec = validate(raw, risk_low(), ())
        assert rec.is_fallback is False
        assert rec.referral_needed is False

    def test_case_insensitive_yes(self):
        raw = "Possible condition: X\nAdvice: Y\nReferral needed: YES"
        rec = validate(raw, risk_low(), ())
        assert rec.referral_needed is True

    def test_case_insensitive_no(self):
        raw = "Possible condition: X\nAdvice: Y\nReferral needed: NO"
        rec = validate(raw, risk_low(), ())
        assert rec.referral_needed is False

    def test_flexible_colon_spacing(self):
        raw = (
            "Possible condition : Infection\n"
            "Advice : See a doctor\n"
            "Referral needed : Yes"
        )
        rec = validate(raw, risk_low(), ())
        assert rec.is_fallback is False

    def test_extra_whitespace_in_fields_stripped(self):
        raw = (
            "Possible condition:   Fever   \n"
            "Advice:   Rest and fluids   \n"
            "Referral needed: No"
        )
        rec = validate(raw, risk_low(), ())
        assert rec.condition == "Fever"
        assert rec.advice == "Rest and fluids"


class TestFallbackTriggers:

    def test_empty_string_triggers_fallback(self):
        assert validate("", risk_low(), ()).is_fallback is True

    def test_none_coerced_empty_triggers_fallback(self):
        # Guard against None being passed from a failed inference call
        assert validate("", risk_med(), ()).is_fallback is True

    def test_whitespace_only_triggers_fallback(self):
        assert validate("   \n\t  ", risk_low(), ()).is_fallback is True

    def test_unstructured_prose_triggers_fallback(self):
        raw = "The patient seems to be doing fine, nothing to worry about."
        assert validate(raw, risk_low(), ()).is_fallback is True

    def test_partial_structure_triggers_fallback(self):
        """Only one field present — should fail, not partially parse."""
        raw = "Possible condition: Fever"
        assert validate(raw, risk_low(), ()).is_fallback is True

    def test_missing_referral_field_triggers_fallback(self):
        raw = "Possible condition: Fever\nAdvice: Rest at home"
        assert validate(raw, risk_low(), ()).is_fallback is True


class TestHighRiskOverrideRule:
    """
    The non-negotiable safety property:
    HIGH risk score ALWAYS forces referral_needed=True,
    regardless of what the model's text says.
    """

    def test_high_risk_forces_referral_when_model_says_no(self):
        raw = (
            "Possible condition: Mild fever\n"
            "Advice: Rest and drink fluids\n"
            "Referral needed: No"
        )
        rec = validate(raw, risk_high(), ())
        assert rec.is_fallback is False, (
            "Well-formed output should be parsed even when overridden"
        )
        assert rec.referral_needed is True, (
            "HIGH risk MUST force referral=True even when model says No. "
            "This is the primary clinical safety guarantee of this package."
        )

    def test_high_risk_forces_referral_in_fallback_too(self):
        """Even the fallback template must force referral for HIGH risk."""
        rec = validate("", risk_high(), ())
        assert rec.is_fallback is True
        assert rec.referral_needed is True

    def test_high_risk_model_yes_referral_is_preserved(self):
        """When both agree on referral, the result should be True."""
        raw = (
            "Possible condition: Severe respiratory infection\n"
            "Advice: Refer immediately\n"
            "Referral needed: Yes"
        )
        rec = validate(raw, risk_high(), ())
        assert rec.referral_needed is True

    def test_medium_risk_model_no_is_respected(self):
        """MEDIUM risk does not force referral — model output is used."""
        raw = (
            "Possible condition: Mild viral illness\n"
            "Advice: Monitor at home\n"
            "Referral needed: No"
        )
        rec = validate(raw, risk_med(), ())
        assert rec.referral_needed is False

    def test_low_risk_model_no_is_respected(self):
        raw = (
            "Possible condition: No concerning pattern\n"
            "Advice: Routine monitoring\n"
            "Referral needed: No"
        )
        rec = validate(raw, risk_low(), ())
        assert rec.referral_needed is False


class TestFallbackContentQuality:
    """
    Fallback recommendations must always be non-empty, clinically safe,
    and risk-level appropriate.
    """

    def test_fallback_condition_never_empty(self):
        for r in [risk_low(), risk_med(), risk_high()]:
            rec = validate("", r, ())
            assert rec.condition.strip(), f"Fallback condition empty for {r.level}"

    def test_fallback_advice_never_empty(self):
        for r in [risk_low(), risk_med(), risk_high()]:
            rec = validate("", r, ())
            assert rec.advice.strip(), f"Fallback advice empty for {r.level}"

    def test_high_risk_fallback_advice_mentions_referral(self):
        rec = validate("", risk_high(), ())
        assert "refer" in rec.advice.lower() or "facility" in rec.advice.lower()

    def test_fallback_carries_risk_result(self):
        r = risk_high()
        rec = validate("", r, ())
        assert rec.risk is r

    def test_fallback_sources_preserved(self):
        from sanjeevani.core.models import KnowledgePassage
        p = KnowledgePassage("id1", "IMNCI 4.2", "Some text", 0.8)
        rec = validate("", risk_low(), (p,))
        assert rec.sources == (p,)


class TestMetadataPassthrough:

    def test_backend_name_carried_through(self):
        raw = (
            "Possible condition: Fever\n"
            "Advice: Monitor\n"
            "Referral needed: No"
        )
        rec = validate(raw, risk_low(), (), backend="test-backend", latency_ms=42.0)
        assert rec.backend_used == "test-backend"
        assert rec.latency_ms == 42.0

    def test_fallback_carries_backend_and_latency(self):
        rec = validate("", risk_low(), (), backend="failed-backend", latency_ms=5000.0)
        assert rec.backend_used == "failed-backend"
        assert rec.latency_ms == 5000.0

    def test_none_backend_allowed(self):
        rec = validate("", risk_low(), (), backend=None)
        assert rec.backend_used is None
