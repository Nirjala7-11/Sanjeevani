"""
Typed, immutable data models for the intelligence layer.

Design decisions:
  1. All objects are frozen dataclasses — immutable after construction.
     An object that exists is guaranteed valid. There is no 'partially
     constructed' or 'mutated after validation' state.

  2. Validation happens inside __post_init__, not in calling code.
     Every place that creates a PatientVitals can trust it without
     re-checking. There is no defensive re-validation downstream.

  3. No plain dicts anywhere in the call path.
     A typo like vitals["temprature"] raises AttributeError at the
     call site, not a silent None miles downstream.

  4. ClinicalRecommendation carries full provenance: risk score,
     retrieved sources (with similarity scores), which backend responded,
     latency, and whether the fallback was used. The Flutter UI can use
     all of this — the judgement call about what to show the user
     belongs to the UI, not to this package.
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Optional

from sanjeevani.config import CFG
from sanjeevani.exceptions import BoundaryError


# ── Enumerations ─────────────────────────────────────────────────────────────

class RiskLevel(str, Enum):
    LOW    = "LOW"
    MEDIUM = "MEDIUM"
    HIGH   = "HIGH"

    @property
    def display(self) -> str:
        return self.value.capitalize()


# ── Input models ──────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class PatientVitals:
    """
    Validated, immutable vital signs container.

    Raises BoundaryError on construction if any value is outside
    physiological plausibility bounds. Downstream code therefore never
    needs to re-check: if a PatientVitals object exists, it's valid.

    Args:
        heart_rate_bpm : Heart rate in beats per minute.
        spo2_pct       : Blood oxygen saturation, percentage.
        temperature_f  : Body temperature in Fahrenheit.
    """
    heart_rate_bpm: float
    spo2_pct:       float
    temperature_f:  float

    def __post_init__(self) -> None:
        b = CFG.bounds
        self._check("Heart rate (bpm)",   self.heart_rate_bpm, b.hr_min_bpm,   b.hr_max_bpm)
        self._check("SpO2 (%)",           self.spo2_pct,       b.spo2_min_pct, b.spo2_max_pct)
        self._check("Temperature (°F)",   self.temperature_f,  b.temp_min_f,   b.temp_max_f)

    @staticmethod
    def _check(label: str, val: float, lo: float, hi: float) -> None:
        if not (lo <= val <= hi):
            raise BoundaryError(
                f"{label} reading of {val} is outside the physiologically "
                f"plausible range [{lo}, {hi}]. This is almost certainly a "
                f"sensor or data-entry error. Ask the health worker to "
                f"re-check the reading before proceeding."
            )


# ── Intermediate models ───────────────────────────────────────────────────────

@dataclass(frozen=True)
class RiskResult:
    """
    Output of the deterministic risk engine.
    Never touches the LLM. Never fails if vitals are valid.
    """
    score:  int
    level:  RiskLevel
    alerts: tuple[str, ...]

    @property
    def requires_referral(self) -> bool:
        """True iff this result unconditionally forces a referral recommendation."""
        return self.level == RiskLevel.HIGH


@dataclass(frozen=True)
class KnowledgePassage:
    """One retrieved passage from the medical knowledge base."""
    entry_id:   str
    source_ref: str    # e.g. "IMNCI Guidelines, Section 4.2"
    text:       str
    similarity: float  # cosine similarity [0, 1] — for display and audit


# ── Output model ──────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class ClinicalRecommendation:
    """
    Final output of the intelligence layer — the only object the Flutter
    app needs to import and render.

    Fields:
        condition       : Short phrase describing the likely condition.
        advice          : One or two sentences of actionable guidance.
        referral_needed : True if the health worker should refer to a facility.
        risk            : The deterministic RiskResult that drove the pipeline.
        sources         : Knowledge base passages used to ground the model.
        is_fallback     : True if the model step failed and a safe template
                          was used instead. The UI should display this
                          differently (e.g. 'AI analysis unavailable').
        backend_used    : Which inference backend responded, or None if fallback.
        latency_ms      : End-to-end inference latency, or None if fallback.
    """
    condition:       str
    advice:          str
    referral_needed: bool
    risk:            RiskResult
    sources:         tuple[KnowledgePassage, ...]
    is_fallback:     bool             = False
    backend_used:    Optional[str]    = None
    latency_ms:      Optional[float]  = None

    def to_dict(self) -> dict:
        """Serialization helper for the Flutter HTTP layer."""
        return {
            "condition":       self.condition,
            "advice":          self.advice,
            "referral_needed": self.referral_needed,
            "risk_level":      self.risk.level.value,
            "risk_score":      self.risk.score,
            "alerts":          list(self.risk.alerts),
            "is_fallback":     self.is_fallback,
            "backend_used":    self.backend_used,
            "latency_ms":      self.latency_ms,
            "sources": [
                {
                    "entry_id":   s.entry_id,
                    "source_ref": s.source_ref,
                    "similarity": round(s.similarity, 4),
                }
                for s in self.sources
            ],
        }
