"""
Output validation, override enforcement, and deterministic fallback.

This is the most important security module in the package.

Three responsibilities:

  1. PARSING
     Extract structured fields from the model's free-text output.
     If the model ignored the format, declare parsing failed.

  2. OVERRIDE ENFORCEMENT (the non-negotiable rule)
     The rule-based risk engine is the floor, never the ceiling.
     If the engine scored HIGH, referral is forced — regardless of
     what the model said. The model may ESCALATE; it may NEVER
     DE-ESCALATE a risk the deterministic engine established.

     This rule exists because:
       • Quantized models hallucinate or under-follow instructions.
       • A model that says 'no referral needed' for SpO2=80% could
         directly cause patient harm if that output reached the worker.
       • The risk score is always correct (it's arithmetic); the model
         output is always uncertain. The certain answer overrides.

  3. SAFE FALLBACK
     When parsing fails, or inference threw InferenceError, the guard
     constructs a deterministic ClinicalRecommendation from templates.
     The health worker ALWAYS receives a complete, usable response.
     The pipeline NEVER returns None. The pipeline NEVER raises from here.
"""
from __future__ import annotations

import logging
import re
from typing import Optional

from sanjeevani.core.models import (
    ClinicalRecommendation,
    KnowledgePassage,
    RiskLevel,
    RiskResult,
)

log = logging.getLogger("sanjeevani.safety.output_guard")

# Matches the required three-line structured output, case-insensitively,
# with flexible whitespace and colon variants.
_STRUCTURE_RE = re.compile(
    r"Possible condition\s*[:\-]\s*(?P<condition>.+?)\s*"
    r"Advice\s*[:\-]\s*(?P<advice>.+?)\s*"
    r"Referral needed\s*[:\-]\s*(?P<referral>yes|no|YES|NO|Yes|No)",
    re.IGNORECASE | re.DOTALL,
)

# Deterministic fallback templates, one per risk level.
# These are shown when the model's output cannot be used.
_FALLBACK: dict[RiskLevel, tuple[str, str, bool]] = {
    RiskLevel.HIGH: (
        "Unable to determine — AI analysis unavailable",
        "The rule-based risk assessment indicates HIGH risk from the measured "
        "vitals alone. Refer the patient to the nearest Primary Health Centre "
        "or facility immediately. Do not wait for symptoms to worsen.",
        True,
    ),
    RiskLevel.MEDIUM: (
        "Unable to determine — AI analysis unavailable",
        "The rule-based risk assessment indicates MEDIUM risk. Monitor the "
        "patient closely. If symptoms worsen, or do not improve within 24 "
        "hours, refer to the nearest health facility.",
        False,
    ),
    RiskLevel.LOW: (
        "No high-risk vital sign pattern detected",
        "Vital signs are within normal range. Continue routine monitoring. "
        "If new symptoms appear or the patient's condition changes, reassess.",
        False,
    ),
}


def _make_fallback(
    risk:        RiskResult,
    passages:    tuple[KnowledgePassage, ...],
    reason:      str,
    backend:     Optional[str],
    latency_ms:  Optional[float],
) -> ClinicalRecommendation:
    log.warning("Output guard fallback | reason=%r level=%s", reason, risk.level.value)
    condition, advice, referral = _FALLBACK[risk.level]
    return ClinicalRecommendation(
        condition=condition,
        advice=advice,
        referral_needed=referral,
        risk=risk,
        sources=passages,
        is_fallback=True,
        backend_used=backend,
        latency_ms=latency_ms,
    )


def validate(
    raw_output:  str,
    risk:        RiskResult,
    passages:    tuple[KnowledgePassage, ...],
    backend:     Optional[str]  = None,
    latency_ms:  Optional[float] = None,
) -> ClinicalRecommendation:
    """
    Parse and validate raw model output.

    Always returns a valid ClinicalRecommendation. Never raises.
    Never returns None.

    Args:
        raw_output : Raw text from the inference backend (may be empty).
        risk       : The deterministic risk result from risk_engine.assess().
        passages   : Retrieved knowledge passages (may be empty tuple).
        backend    : Name of the backend that produced raw_output, for audit.
        latency_ms : Inference latency in milliseconds, for audit.

    Returns:
        ClinicalRecommendation with is_fallback=False if parsing succeeded,
        or is_fallback=True if the fallback template was used.
    """
    # ── Guard: empty output ────────────────────────────────────────────────
    if not raw_output or not raw_output.strip():
        return _make_fallback(risk, passages, "empty model output", backend, latency_ms)

    # ── Parse structured fields ───────────────────────────────────────────
    m = _STRUCTURE_RE.search(raw_output)
    if not m:
        return _make_fallback(
            risk, passages,
            "model did not follow required output structure",
            backend, latency_ms,
        )

    condition = m.group("condition").strip()
    advice    = m.group("advice").strip()

    if not condition or not advice:
        return _make_fallback(
            risk, passages,
            "parsed condition or advice field was empty",
            backend, latency_ms,
        )

    model_says_referral = m.group("referral").strip().lower() == "yes"

    # ── Override rule ──────────────────────────────────────────────────────
    # HIGH risk always forces referral, regardless of model output.
    # The model may ADD a referral for non-HIGH cases; it may never REMOVE
    # one that the risk engine established.
    final_referral = risk.requires_referral or model_says_referral

    if risk.requires_referral and not model_says_referral:
        log.warning(
            "Override rule fired: model suggested no referral for "
            "HIGH risk (score=%d). Forcing referral=True.",
            risk.score,
        )

    log.info(
        "Output guard passed | is_fallback=False referral=%s backend=%s",
        final_referral, backend,
    )

    return ClinicalRecommendation(
        condition=condition,
        advice=advice,
        referral_needed=final_referral,
        risk=risk,
        sources=passages,
        is_fallback=False,
        backend_used=backend,
        latency_ms=latency_ms,
    )
