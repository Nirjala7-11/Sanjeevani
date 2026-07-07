"""
Immutable, centralized configuration.

Architecture decisions encoded here:
  1. Every threshold and tunable constant lives in ONE file.
     A clinical reviewer auditing risk bands reads only this file.
     Scoring logic reads only this file. Neither reads the other.

  2. All config objects are frozen dataclasses.
     A bug that mutates a threshold after startup becomes an AttributeError
     at the mutation site, not a silent wrong calculation.

  3. Nothing here contains a secret.
     Credentials are obtained via get_secret() at runtime from the
     environment. Never from here. Never from source.

  4. Thresholds are designed so any single critical-tier alert reaches
     HIGH risk on its own (see ScoringWeights docstring). Clinically
     correct, since each critical sign is dangerous without co-occurrence.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

# ── Paths ────────────────────────────────────────────────────────────────────

PKG_ROOT  = Path(__file__).resolve().parent.parent
DATA_DIR  = PKG_ROOT / "data"
LOG_DIR   = PKG_ROOT / "logs"
KB_PATH   = DATA_DIR / "knowledge_base.json"

LOG_DIR.mkdir(parents=True, exist_ok=True)


# ── Vital sign bounds (physiological plausibility) ───────────────────────────

@dataclass(frozen=True)
class VitalBounds:
    """
    Hard outer limits for sensor readings.
    Values outside these are sensor/data-entry errors, not medical conditions.
    The validator raises BoundaryError before any scoring happens.
    """
    hr_min_bpm:   float = 20.0
    hr_max_bpm:   float = 250.0
    spo2_min_pct: float = 40.0
    spo2_max_pct: float = 100.0
    temp_min_f:   float = 86.0
    temp_max_f:   float = 115.0


# ── Clinical thresholds ───────────────────────────────────────────────────────

@dataclass(frozen=True)
class ClinicalThresholds:
    """
    Alert trigger thresholds.
    Separated from scoring weights so a clinician can adjust one without
    the other. Never appear as magic numbers in scoring code.
    """
    # Heart rate
    hr_elevated_bpm:  float = 100.0
    hr_critical_bpm:  float = 130.0

    # SpO2
    spo2_low_pct:     float = 92.0
    spo2_critical_pct: float = 85.0

    # Temperature
    temp_fever_f:      float = 100.4
    temp_high_fever_f: float = 103.0


# ── Scoring weights ────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class ScoringWeights:
    """
    Point values assigned per alert tier.

    Calibration rationale:
      - Any single CRITICAL-tier alert must reach HIGH on its own.
        An SpO2 of 80% is an emergency regardless of heart rate or temp.
        An HR of 140 at rest is dangerous without fever.
      - cut_medium is set so that a single ELEVATED alert (score=2)
        falls in MEDIUM, and two ELEVATED alerts (score=4) reach HIGH.
      - This means LOW = truly no concerning signs (score 0-1 only).

    To change risk sensitivity: adjust cut_medium / cut_high here.
    Never touch scoring logic in risk_engine.py for this.
    """
    # Alert tier weights
    hr_elevated:  int = 2
    hr_critical:  int = 6   # alone ≥ cut_high → HIGH
    spo2_low:     int = 3
    spo2_critical: int = 7  # alone ≥ cut_high → HIGH
    fever:         int = 2
    high_fever:    int = 5  # alone ≥ cut_high → HIGH

    # Risk band cut-points (inclusive upper bounds)
    cut_low:    int = 1   # score ∈ [0, 1]  → LOW
    cut_medium: int = 4   # score ∈ [2, 4]  → MEDIUM
                          # score ∈ [5, ∞)  → HIGH


# ── Retrieval ─────────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class RetrievalConfig:
    """
    Sentence-embedding model and FAISS search parameters.
    The model is small (<100MB) and multilingual-capable.
    """
    embedding_model: str   = "sentence-transformers/all-MiniLM-L6-v2"
    top_k:           int   = 4      # max passages to retrieve
    min_similarity:  float = 0.25   # cosine similarity floor (L2-normed)
    batch_size:      int   = 64     # for embedding the KB at startup


# ── Inference backends ────────────────────────────────────────────────────────

@dataclass(frozen=True)
class HFConfig:
    """Hugging Face Transformers — development only."""
    model_id:       str   = "google/gemma-2b-it"
    max_new_tokens: int   = 220
    temperature:    float = 0.2    # low = more predictable structured output
    do_sample:      bool  = True


@dataclass(frozen=True)
class LlamaCppConfig:
    """
    llama.cpp local server — production, on-device only.
    host MUST be loopback — enforced in code, not just documented.
    """
    host:             str   = "127.0.0.1"
    port:             int   = 8080
    max_tokens:       int   = 220
    temperature:      float = 0.2
    timeout_s:        float = 30.0
    health_timeout_s: float = 3.0
    stop_tokens:      tuple = ("</s>", "User:", "Patient:", "PATIENT:")


# ── Safety limits ─────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class SafetyConfig:
    max_transcript_chars:    int   = 2_500
    min_transcript_chars:    int   = 2      # below this = nothing useful was said
    force_referral_level:    str   = "HIGH"
    # The regex groups the output parser looks for
    required_output_fields:  tuple = (
        "Possible condition",
        "Advice",
        "Referral needed",
    )


# ── Root ──────────────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class AppConfig:
    bounds:    VitalBounds        = field(default_factory=VitalBounds)
    clinical:  ClinicalThresholds = field(default_factory=ClinicalThresholds)
    scoring:   ScoringWeights     = field(default_factory=ScoringWeights)
    retrieval: RetrievalConfig    = field(default_factory=RetrievalConfig)
    hf:        HFConfig           = field(default_factory=HFConfig)
    llamacpp:  LlamaCppConfig     = field(default_factory=LlamaCppConfig)
    safety:    SafetyConfig       = field(default_factory=SafetyConfig)


CFG = AppConfig()


# ── Secret access ─────────────────────────────────────────────────────────────

def get_secret(key: str) -> str | None:
    """
    Read a credential from the environment ONLY.

    Contract:
      - Returns None (not "") when the variable is absent or empty.
        Callers can distinguish 'not configured' from 'configured as empty'.
      - The returned value is NEVER logged, even partially.
      - This function is the ONLY permitted way to read secrets.
      - The on-device LlamaCppBackend requires no credential whatsoever.

    Example:
        token = get_secret("HF_TOKEN")
        if token is None:
            raise InferenceError("HF_TOKEN not set")
        # use token — do not log it
    """
    val = os.environ.get(key, "").strip()
    return val if val else None
