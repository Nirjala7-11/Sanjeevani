"""
Package-wide exception hierarchy.

Every exception the public API can raise inherits from SanjeevaniError.
This means callers need to handle exactly ONE base type, while still being
able to catch specific sub-types for fine-grained handling if they need it.

Hierarchy:
  SanjeevaniError
    ├── InputError          — bad or unusable caller input (validation failures)
    │     └── BoundaryError — vital reading outside physiological range
    ├── KnowledgeError      — knowledge base missing, corrupt, or empty
    └── InferenceError      — LLM backend failed to produce usable output

SanjeevaniError is the only type the public IntelligenceEngine.analyse()
method may propagate. All other internal errors are caught, logged, and
converted to a safe fallback ClinicalRecommendation rather than raised.
"""
from __future__ import annotations


class SanjeevaniError(Exception):
    """Base class for all errors from this package."""


class InputError(SanjeevaniError):
    """Raised when caller input is malformed, empty, or unprocessable."""


class BoundaryError(InputError):
    """
    Raised when a vital reading is outside physiological plausibility limits.

    This is almost always a sensor or data-entry error and should be surfaced
    to the health worker as 'please re-check this reading' rather than
    treated as an application fault.
    """


class KnowledgeError(SanjeevaniError):
    """
    Raised at startup when the knowledge base cannot be loaded.
    This is a hard failure — the system cannot reason without verified
    protocol content and must not attempt to operate with an empty store.
    """


class InferenceError(SanjeevaniError):
    """
    Raised by inference backends when generation fails for any reason.
    Callers (the orchestrator) must catch this and activate the safety
    fallback rather than propagating it to the health worker.
    """
