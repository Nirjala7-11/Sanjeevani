"""Tests for grounded prompt construction."""
import sys
sys.path.insert(0, "/home/claude/sanjeevani_pro")

from sanjeevani.core.models import KnowledgePassage, PatientVitals, RiskLevel, RiskResult
from sanjeevani.core.prompt_builder import build


def make_risk(level=RiskLevel.HIGH, score=8, alerts=("High fever",)) -> RiskResult:
    return RiskResult(score=score, level=level, alerts=alerts)


def make_vitals() -> PatientVitals:
    return PatientVitals(120.0, 88.0, 102.0)


def make_passage(i=1) -> KnowledgePassage:
    return KnowledgePassage(
        entry_id=f"kb-00{i}",
        source_ref=f"IMNCI 4.{i}",
        text=f"Protocol text {i} about respiratory conditions",
        similarity=0.9,
    )


class TestPromptBuilder:

    def test_prompt_is_string(self):
        assert isinstance(build(make_vitals(), make_risk(), ()), str)

    def test_prompt_not_empty(self):
        assert len(build(make_vitals(), make_risk(), ())) > 100

    def test_prompt_contains_vitals(self):
        prompt = build(make_vitals(), make_risk(), ())
        assert "120" in prompt  # heart rate
        assert "88" in prompt   # spo2
        assert "102" in prompt  # temperature

    def test_prompt_contains_risk_level(self):
        prompt = build(make_vitals(), make_risk(level=RiskLevel.HIGH), ())
        assert "HIGH" in prompt

    def test_prompt_contains_risk_score(self):
        prompt = build(make_vitals(), make_risk(score=8), ())
        assert "8" in prompt

    def test_prompt_contains_alerts(self):
        prompt = build(make_vitals(), make_risk(alerts=("High fever", "Low oxygen")), ())
        assert "High fever" in prompt
        assert "Low oxygen" in prompt

    def test_prompt_contains_retrieved_passages(self):
        p = make_passage(1)
        prompt = build(make_vitals(), make_risk(), (p,))
        assert "Protocol text 1" in prompt
        assert "IMNCI 4.1" in prompt

    def test_prompt_contains_output_format_instructions(self):
        prompt = build(make_vitals(), make_risk(), ())
        assert "Possible condition" in prompt
        assert "Advice" in prompt
        assert "Referral needed" in prompt

    def test_prompt_contains_system_instruction(self):
        prompt = build(make_vitals(), make_risk(), ())
        # System instruction should prohibit hallucination
        assert "ONLY" in prompt or "only" in prompt

    def test_no_matching_passages_noted_in_prompt(self):
        prompt = build(make_vitals(), make_risk(), ())
        assert "NO MATCHING PROTOCOL" in prompt or "no" in prompt.lower()

    def test_multiple_passages_all_included(self):
        passages = tuple(make_passage(i) for i in range(1, 4))
        prompt = build(make_vitals(), make_risk(), passages)
        for i in range(1, 4):
            assert f"Protocol text {i}" in prompt

    def test_prompt_contains_no_patient_identifier(self):
        """Prompt must not include hardcoded identifiers."""
        prompt = build(make_vitals(), make_risk(), ())
        assert "patient_id" not in prompt
        assert "patient_id" not in prompt and "patient_name" not in prompt
