"""
Grounded, structured prompt construction.

The safety principle: the LLM is NEVER asked an open-ended question.
Every prompt contains:
  (a) A hard system instruction prohibiting hallucination.
  (b) The deterministic risk result — the ground truth the LLM must
      be consistent with.
  (c) The retrieved protocol passages — the ONLY medical source it may use.
  (d) A mandatory output format that the output_guard parses.

This makes the model's task "fill in a constrained template given these
facts" rather than "tell me what you know about this patient" — far safer.
"""
from __future__ import annotations

from sanjeevani.core.models import KnowledgePassage, PatientVitals, RiskResult

_SYSTEM_INSTRUCTION = """\
You are a clinical decision-support module embedded in Sanjeevani, an offline
health assistant used by ASHA community health workers in rural India.

RULES YOU MUST FOLLOW WITHOUT EXCEPTION:
1. Base your entire response ONLY on the verified protocol text provided below.
2. Do NOT invent conditions, drug names, dosages, or procedures not present
   in that text.
3. Do NOT contradict the rule-based risk score. If the score says HIGH, your
   recommendation must be urgent.
4. If the protocol text is insufficient to answer confidently, say so
   explicitly and recommend referral rather than guessing.
5. Respond in EXACTLY the structure specified. No preamble. No commentary.\
"""

_OUTPUT_FORMAT = """\
Respond using EXACTLY this structure. No extra text before or after:

Possible condition: <one short clinical phrase>
Advice: <one or two sentences of clear, actionable guidance>
Referral needed: <Yes or No>\
"""


def _format_passages(passages: tuple[KnowledgePassage, ...]) -> str:
    if not passages:
        return (
            "[NO MATCHING PROTOCOL FOUND]\n"
            "No closely matching verified protocol was retrieved for these "
            "symptoms. Default to general caution: recommend referral if any "
            "doubt exists."
        )
    lines = []
    for i, p in enumerate(passages, 1):
        lines.append(f"[Protocol {i} — {p.source_ref}]")
        lines.append(p.text)
    return "\n".join(lines)


def build(
    vitals:   PatientVitals,
    risk:     RiskResult,
    passages: tuple[KnowledgePassage, ...],
) -> str:
    """
    Build the grounded prompt.
    Returns a complete, ready-to-send prompt string.
    """
    alerts_str   = "\n".join(f"  • {a}" for a in risk.alerts) if risk.alerts else "  • None"
    passages_str = _format_passages(passages)

    return (
        f"{_SYSTEM_INSTRUCTION}\n\n"
        f"━━━ PATIENT VITALS ━━━\n"
        f"  Heart rate : {vitals.heart_rate_bpm:.0f} bpm\n"
        f"  SpO2       : {vitals.spo2_pct:.0f}%\n"
        f"  Temperature: {vitals.temperature_f:.1f} °F\n\n"
        f"━━━ RULE-BASED RISK ASSESSMENT ━━━\n"
        f"  Score : {risk.score}\n"
        f"  Level : {risk.level.value}\n"
        f"  Alerts:\n{alerts_str}\n\n"
        f"━━━ VERIFIED PROTOCOL INFORMATION ━━━\n"
        f"(Use ONLY the passages below. Do not use general knowledge.)\n\n"
        f"{passages_str}\n\n"
        f"━━━ REQUIRED OUTPUT FORMAT ━━━\n"
        f"{_OUTPUT_FORMAT}"
    )
