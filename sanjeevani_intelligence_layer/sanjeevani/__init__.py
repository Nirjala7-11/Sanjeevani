"""
Sanjeevani Intelligence Layer
==============================
Offline-first, RAG-grounded clinical decision-support for rural ASHA workers.

Public API — import only these:
    from sanjeevani.engine import IntelligenceEngine
    from sanjeevani.core.models import PatientVitals, ClinicalRecommendation
    from sanjeevani.exceptions import SanjeevaniError, BoundaryError, InputError
    from sanjeevani.inference.huggingface import HuggingFaceBackend   # dev only
    from sanjeevani.inference.llamacpp import LlamaCppBackend          # production
    from sanjeevani.safety.input_guard import sanitize_transcript      # for callers doing STT
"""
__version__ = "1.0.0"
__all__ = ["IntelligenceEngine"]
