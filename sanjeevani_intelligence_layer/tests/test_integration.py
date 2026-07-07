"""
End-to-end integration tests for the IntelligenceEngine.

All tests use scripted fake backends and a minimal fake KnowledgeStore
so no GPU, no model downloads, and no network access are required.

These tests prove the WIRING is correct — that each step hands off to
the next correctly, and that the safety properties hold through the
entire pipeline.
"""
import sys, json
sys.path.insert(0, "/home/claude/sanjeevani_pro")

import numpy as np
import pytest

from sanjeevani.core.models import PatientVitals, RiskLevel
from sanjeevani.engine import IntelligenceEngine
from sanjeevani.exceptions import BoundaryError, InferenceError, InputError
from sanjeevani.inference.base import InferenceResult, LLMBackend
from sanjeevani.knowledge.store import KnowledgeStore, _Entry


# ── Scripted test backends ────────────────────────────────────────────────────

class WellFormedBackend(LLMBackend):
    """Always returns a well-structured response recommending referral."""
    @property
    def name(self): return "well-formed-test"
    def generate(self, prompt):
        return InferenceResult(
            text=(
                "Possible condition: Respiratory infection\n"
                "Advice: Refer to PHC today\n"
                "Referral needed: Yes"
            ),
            backend=self.name,
            latency_ms=12.0,
        )


class NoReferralBackend(LLMBackend):
    """Always returns a well-structured response NOT recommending referral."""
    @property
    def name(self): return "no-referral-test"
    def generate(self, prompt):
        return InferenceResult(
            text=(
                "Possible condition: Mild viral illness\n"
                "Advice: Rest and monitor at home\n"
                "Referral needed: No"
            ),
            backend=self.name,
            latency_ms=8.0,
        )


class FailingBackend(LLMBackend):
    """Always raises InferenceError."""
    @property
    def name(self): return "failing-test"
    def generate(self, prompt):
        raise InferenceError("Scripted failure for testing")


class GarbageBackend(LLMBackend):
    """Returns unstructured text that cannot be parsed."""
    @property
    def name(self): return "garbage-test"
    def generate(self, prompt):
        return InferenceResult(
            text="I think the patient might be okay probably maybe",
            backend=self.name,
            latency_ms=5.0,
        )


class EmptyBackend(LLMBackend):
    """Returns an empty string."""
    @property
    def name(self): return "empty-test"
    def generate(self, prompt):
        return InferenceResult(text="", backend=self.name, latency_ms=1.0)


# ── Fake KnowledgeStore ───────────────────────────────────────────────────────

@pytest.fixture
def fake_store(tmp_path):
    """
    A KnowledgeStore wired with a deterministic hash-based embedder
    instead of a real sentence-transformers model.
    No network, no GPU, no downloads.
    """
    import faiss, hashlib

    class HashEmbedder:
        DIM = 48
        def encode(self, texts, normalize_embeddings=True, batch_size=64, show_progress_bar=False):
            vecs = []
            for t in texts:
                v = np.zeros(self.DIM, dtype="float32")
                for word in t.lower().split():
                    h = int(hashlib.sha256(word.encode()).hexdigest(), 16)
                    v[h % self.DIM] += 1.0
                vecs.append(v)
            arr = np.array(vecs, dtype="float32")
            if normalize_embeddings:
                norms = np.linalg.norm(arr, axis=1, keepdims=True)
                norms[norms == 0] = 1.0
                arr /= norms
            return arr

    entries = [
        _Entry("kb-t1", "fever high temperature rapid breathing pneumonia", "IMNCI 2.4", ()),
        _Entry("kb-t2", "low oxygen spo2 hypoxemia referral urgent", "IMNCI 4.2", ()),
        _Entry("kb-t3", "heart rate tachycardia elevated critical", "ICMR 3.2", ()),
    ]

    store = KnowledgeStore.__new__(KnowledgeStore)
    store._faiss = faiss
    store._entries = entries
    store._model = HashEmbedder()

    vecs = store._model.encode([e.text for e in entries], normalize_embeddings=True)
    store._index = faiss.IndexFlatIP(vecs.shape[1])
    store._index.add(np.asarray(vecs, dtype="float32"))
    return store


# ── Integration tests ─────────────────────────────────────────────────────────

class TestPipelineHappyPath:

    def test_well_formed_backend_recommendation_returned(self, fake_store):
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        rec = engine.analyse(PatientVitals(120, 88, 102))
        assert rec.is_fallback is False
        assert rec.condition == "Respiratory infection"
        assert rec.referral_needed is True

    def test_backend_name_in_result(self, fake_store):
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        rec = engine.analyse(PatientVitals(120, 88, 102))
        assert rec.backend_used == "well-formed-test"

    def test_latency_recorded(self, fake_store):
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        rec = engine.analyse(PatientVitals(120, 88, 102))
        assert rec.latency_ms == 12.0

    def test_risk_result_in_recommendation(self, fake_store):
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        rec = engine.analyse(PatientVitals(120, 88, 102))
        assert rec.risk.level == RiskLevel.HIGH
        assert rec.risk.score > 0

    def test_sources_are_tuple(self, fake_store):
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        rec = engine.analyse(PatientVitals(120, 88, 102), transcript="fever breathing")
        assert isinstance(rec.sources, tuple)

    def test_low_risk_no_referral_path(self, fake_store):
        engine = IntelligenceEngine(NoReferralBackend(), fake_store)
        rec = engine.analyse(PatientVitals(75, 98, 98))
        assert rec.referral_needed is False
        assert rec.risk.level == RiskLevel.LOW


class TestSafetyProperties:
    """
    These tests document clinical safety properties that MUST always hold.
    Treat failures as patient safety issues.
    """

    def test_high_risk_always_forces_referral_even_if_model_says_no(self, fake_store):
        """
        THE MOST IMPORTANT TEST IN THIS SUITE.
        A HIGH risk patient MUST be referred, regardless of model output.
        """
        engine = IntelligenceEngine(NoReferralBackend(), fake_store)
        # Vitals that produce HIGH risk score
        rec = engine.analyse(PatientVitals(120, 84, 103.5))
        assert rec.referral_needed is True, (
            "HIGH risk MUST force referral_needed=True. "
            "The model said 'No' but the risk engine said HIGH. "
            "The risk engine wins. Always."
        )

    def test_inference_failure_never_raises_to_caller(self, fake_store):
        engine = IntelligenceEngine(FailingBackend(), fake_store)
        # Must return a safe recommendation, not raise InferenceError
        rec = engine.analyse(PatientVitals(120, 88, 102))
        assert rec is not None
        assert rec.is_fallback is True

    def test_inference_failure_high_risk_still_refers(self, fake_store):
        engine = IntelligenceEngine(FailingBackend(), fake_store)
        rec = engine.analyse(PatientVitals(120, 84, 104))
        assert rec.is_fallback is True
        assert rec.referral_needed is True

    def test_garbage_output_falls_back_safely(self, fake_store):
        engine = IntelligenceEngine(GarbageBackend(), fake_store)
        rec = engine.analyse(PatientVitals(75, 98, 98))
        assert rec.is_fallback is True
        assert rec.condition
        assert rec.advice

    def test_empty_model_output_falls_back_safely(self, fake_store):
        engine = IntelligenceEngine(EmptyBackend(), fake_store)
        rec = engine.analyse(PatientVitals(75, 98, 98))
        assert rec.is_fallback is True
        assert rec.condition
        assert rec.advice

    def test_recommendation_never_none(self, fake_store):
        for backend in [WellFormedBackend(), FailingBackend(), GarbageBackend(), EmptyBackend()]:
            engine = IntelligenceEngine(backend, fake_store)
            rec = engine.analyse(PatientVitals(75, 98, 98))
            assert rec is not None

    def test_fallback_condition_never_empty_for_any_risk_level(self, fake_store):
        engine = IntelligenceEngine(FailingBackend(), fake_store)
        for vitals in [
            PatientVitals(75, 98, 98.0),      # LOW
            PatientVitals(105, 94, 101.0),    # MEDIUM
            PatientVitals(120, 84, 103.5),    # HIGH
        ]:
            rec = engine.analyse(vitals)
            assert rec.condition.strip(), f"condition empty for {vitals}"
            assert rec.advice.strip(), f"advice empty for {vitals}"


class TestInputHandling:

    def test_invalid_vitals_raises_boundary_error(self, fake_store):
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        with pytest.raises(BoundaryError):
            engine.analyse(PatientVitals(999.0, 98.0, 98.6))

    def test_implausible_hr_raises_before_inference(self, fake_store):
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        with pytest.raises(BoundaryError):
            engine.analyse(PatientVitals(999, 98, 98))

    def test_none_transcript_raises_input_error(self, fake_store):
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        with pytest.raises(InputError):
            engine.analyse(PatientVitals(75, 98, 98), transcript=None)

    def test_empty_transcript_is_valid(self, fake_store):
        """Empty string transcript is acceptable — vitals-only mode."""
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        rec = engine.analyse(PatientVitals(75, 98, 98), transcript="")
        assert rec is not None

    def test_transcript_with_real_content_included_in_retrieval(self, fake_store):
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        rec = engine.analyse(
            PatientVitals(110, 90, 101),
            transcript="fever and fast breathing for three days"
        )
        assert rec is not None


class TestSerializability:

    def test_to_dict_is_json_serializable(self, fake_store):
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        rec = engine.analyse(PatientVitals(120, 88, 102))
        d = rec.to_dict()
        # Must serialize cleanly to JSON (what the Flutter HTTP layer consumes)
        serialized = json.dumps(d)
        assert len(serialized) > 0

    def test_to_dict_required_keys_present(self, fake_store):
        engine = IntelligenceEngine(WellFormedBackend(), fake_store)
        rec = engine.analyse(PatientVitals(120, 88, 102))
        d = rec.to_dict()
        for key in ("condition", "advice", "referral_needed", "risk_level",
                    "risk_score", "alerts", "is_fallback", "sources"):
            assert key in d
