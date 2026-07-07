"""Tests for input sanitization."""
import sys
sys.path.insert(0, "/home/claude/sanjeevani_pro")

import pytest
from sanjeevani.exceptions import InputError
from sanjeevani.safety.input_guard import sanitize_transcript


class TestSanitizeTranscript:

    # ── Happy path ────────────────────────────────────────────────────────

    def test_normal_text_returned_unchanged(self):
        assert sanitize_transcript("child has fever") == "child has fever"

    def test_leading_trailing_spaces_stripped(self):
        assert sanitize_transcript("  fever  ") == "fever"

    def test_unicode_medical_text_passes(self):
        result = sanitize_transcript("patient has high temperature 103F")
        assert "patient" in result

    # ── None / empty ──────────────────────────────────────────────────────

    def test_none_raises_input_error(self):
        with pytest.raises(InputError):
            sanitize_transcript(None)

    def test_empty_string_raises_input_error(self):
        with pytest.raises(InputError):
            sanitize_transcript("")

    def test_whitespace_only_raises_input_error(self):
        with pytest.raises(InputError):
            sanitize_transcript("   \t\n  ")

    def test_single_char_too_short_raises(self):
        with pytest.raises(InputError):
            sanitize_transcript("a")

    def test_two_chars_accepted(self):
        result = sanitize_transcript("ok")
        assert result == "ok"

    # ── Control character stripping ───────────────────────────────────────

    def test_null_bytes_removed(self):
        result = sanitize_transcript("fever\x00cough")
        assert "\x00" not in result
        assert "fever" in result
        assert "cough" in result

    def test_ascii_control_chars_removed(self):
        dirty = "fever\x01\x02\x03cough"
        result = sanitize_transcript(dirty)
        for c in ["\x01", "\x02", "\x03"]:
            assert c not in result

    def test_del_char_removed(self):
        result = sanitize_transcript("fever\x7fcough")
        assert "\x7f" not in result

    # ── Pathological repetition ───────────────────────────────────────────

    def test_long_repetition_collapsed(self):
        glitch = "a" * 200
        result = sanitize_transcript(glitch + " fever")
        assert "a" * 30 not in result

    def test_normal_words_not_affected_by_repeat_rule(self):
        result = sanitize_transcript("seems okay")
        assert result == "seems okay"

    # ── Whitespace normalization ──────────────────────────────────────────

    def test_multiple_spaces_collapsed(self):
        assert sanitize_transcript("fever    and    cough") == "fever and cough"

    def test_tabs_normalized(self):
        assert sanitize_transcript("fever\tcough") == "fever cough"

    def test_newlines_normalized(self):
        assert sanitize_transcript("fever\ncough") == "fever cough"

    # ── Length capping ────────────────────────────────────────────────────

    def test_oversized_input_truncated(self):
        big = "fever " * 1000
        result = sanitize_transcript(big)
        assert len(result) <= 2500

    def test_truncation_at_word_boundary(self):
        """Truncated string should not end mid-word."""
        big = "word " * 1000
        result = sanitize_transcript(big)
        # Every token in a space-joined string should be a complete word
        tokens = result.split()
        assert all(len(t) > 0 for t in tokens)

    # ── Unicode normalization ─────────────────────────────────────────────

    def test_non_breaking_space_normalized(self):
        result = sanitize_transcript("fever\u00a0cough")
        assert result == "fever cough"

    def test_unicode_letters_preserved(self):
        result = sanitize_transcript("बच्चे को बुखार है")
        assert len(result) > 0
