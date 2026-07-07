"""
IntelligenceEngine — the sole public API of this package.

External callers (Flutter app, CLI tools, notebooks, tests) import
exactly ONE thing from this package: IntelligenceEngine. Nothing else.

This single-import design means:
  • The package's internal structure can change without breaking callers.
  • There is one obvious place to look for the API contract.
  • Integration tests can import only this file and exercise everything.

Pipeline (in order, with failure modes):

  Step 1 — Input guard (safety boundary)
    sanitize_transcript(raw_transcript)
    → InputError if input is None, empty, or unsalvageable
    → This exception propagates to the caller (it's a programming error)

  Step 2 — Vitals validation
    PatientVitals(hr, spo2, temp)
    → BoundaryError if any reading is physiologically impossible
    → This exception propagates to the caller (re-check the sensor)

  Step 3 — Risk assessment (deterministic, cannot fail)
    risk_engine.assess(vitals)
    → Always produces a RiskResult
    → This is the floor for the final referral decision

  Step 4 — Knowledge retrieval (returns empty tuple on no match)
    store.retrieve(query)
    → Empty tuple if nothing clears the similarity threshold
    → Never raises — the prompt_builder handles empty passages safely

  Step 5 — Prompt construction
    prompt_builder.build(vitals, risk, passages)
    → Always produces a string

  Step 6 — Inference (may raise InferenceError)
    backend.generate(prompt)
    → InferenceError is caught HERE and produces raw_output=""
    → This triggers the safety fallback in step 7
    → Never propagates to the caller

  Step 7 — Output validation and safe fallback
    output_guard.validate(raw_output, risk, passages, ...)
    → Always returns a ClinicalRecommendation (never raises, never None)
    → is_fallback=True if model output was unusable

  Return → ClinicalRecommendation
"""
from __future__ import annotations

import logging
from typing import Optional

from sanjeevani.config import LOG_DIR
from sanjeevani.core import prompt_builder, risk_engine
from sanjeevani.core.models import ClinicalRecommendation, PatientVitals
from sanjeevani.exceptions import InferenceError, InputError
from sanjeevani.inference.base import LLMBackend
from sanjeevani.knowledge.store import KnowledgeStore
from sanjeevani.safety import input_guard, output_guard
from sanjeevani.utils.logging_setup import setup as setup_logging

log = logging.getLogger("sanjeevani.engine")


class IntelligenceEngine:
    """
    The Sanjeevani intelligence layer.

    Construct once at application startup. The constructor downloads and
    caches the embedding model on first run — subsequent runs use the cache.

    Example — development (Kaggle / Colab / GPU machine):
        from sanjeevani.engine import IntelligenceEngine
        from sanjeevani.inference.huggingface import HuggingFaceBackend

        engine = IntelligenceEngine(backend=HuggingFaceBackend())

    Example — production (Android app, fully offline):
        from sanjeevani.engine import IntelligenceEngine
        from sanjeevani.inference.llamacpp import LlamaCppBackend

        backend = LlamaCppBackend()
        if not backend.health_check():
            raise RuntimeError("On-device model not ready — check server startup")
        engine = IntelligenceEngine(backend=backend)

    The analyse() call is identical in both cases.
    """

    def __init__(
        self,
        backend: LLMBackend,
        knowledge_store: Optional[KnowledgeStore] = None,
    ) -> None:
        setup_logging(LOG_DIR)
        self._backend = backend
        self._store   = knowledge_store or KnowledgeStore()
        log.info(
            "IntelligenceEngine ready | backend=%s store_entries=%d",
            backend.name,
            self._store._index.ntotal if hasattr(self._store, "_index") else "?",
        )

    def analyse(
        self,
        vitals:     PatientVitals,
        transcript: str = "",
    ) -> ClinicalRecommendation:
        """
        Analyse a patient's vitals and produce a clinical recommendation.

        Args:
            vitals:     Validated PatientVitals. Construction raises
                        BoundaryError if any reading is implausible —
                        let that propagate; the caller's UI should show
                        'please re-check this reading'.
            transcript: Optional cleaned transcript from STT. Pass raw
                        STT output through input_guard.sanitize_transcript()
                        first. An empty string is valid (vitals-only mode).

        Returns:
            ClinicalRecommendation — always, even if the model failed.
            Check is_fallback to know whether the AI contributed.

        Raises:
            BoundaryError: If vitals contain implausible readings.
            InputError:    If a transcript was provided but is unusable.
            (No other exceptions propagate from this method.)
        """
        # ── Step 1: sanitize transcript (if provided) ──────────────────────
        clean_transcript = ""
        if transcript is not None and transcript != "":
            clean_transcript = input_guard.sanitize_transcript(transcript)
        elif transcript is None:
            raise InputError("transcript argument must be a string, not None.")

        # ── Step 2: vitals already validated at construction (trust it) ───
        # ── Step 3: deterministic risk assessment ──────────────────────────
        risk = risk_engine.assess(vitals)

        # ── Step 4: semantic retrieval ────────────────────────────────────
        query = " ".join(filter(None, [", ".join(risk.alerts), clean_transcript]))
        passages = self._store.retrieve(query)

        # ── Step 5: grounded prompt construction ──────────────────────────
        prompt = prompt_builder.build(vitals, risk, passages)

        # ── Step 6: inference (catch ALL failures → fallback) ─────────────
        raw_output   = ""
        backend_name: Optional[str]   = None
        latency_ms:   Optional[float] = None

        try:
            result       = self._backend.generate(prompt)
            raw_output   = result.text
            backend_name = result.backend
            latency_ms   = result.latency_ms
            log.info(
                "Inference success | backend=%s latency_ms=%.0f chars=%d",
                backend_name, latency_ms, len(raw_output),
            )
        except InferenceError as exc:
            log.error(
                "Inference failed — activating safety fallback | error=%s: %s",
                type(exc).__name__, exc,
            )
            # raw_output stays "" → output_guard will use fallback templates

        # ── Step 7: validate output and return ────────────────────────────
        recommendation = output_guard.validate(
            raw_output=raw_output,
            risk=risk,
            passages=passages,
            backend=backend_name,
            latency_ms=latency_ms,
        )

        log.info(
            "analyse() complete | risk=%s referral=%s fallback=%s",
            risk.level.value,
            recommendation.referral_needed,
            recommendation.is_fallback,
        )
        return recommendation
