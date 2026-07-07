"""
Tests for the exception hierarchy.
Ensures every public exception is catchable via the base SanjeevaniError.
"""
import sys
sys.path.insert(0, "/home/claude/sanjeevani_pro")

import pytest
from sanjeevani.exceptions import (
    BoundaryError, InferenceError, InputError,
    KnowledgeError, SanjeevaniError,
)


class TestExceptionHierarchy:

    def test_boundary_error_is_input_error(self):
        exc = BoundaryError("test")
        assert isinstance(exc, InputError)

    def test_input_error_is_sanjeevani_error(self):
        assert isinstance(InputError("x"), SanjeevaniError)

    def test_boundary_error_is_sanjeevani_error(self):
        assert isinstance(BoundaryError("x"), SanjeevaniError)

    def test_knowledge_error_is_sanjeevani_error(self):
        assert isinstance(KnowledgeError("x"), SanjeevaniError)

    def test_inference_error_is_sanjeevani_error(self):
        assert isinstance(InferenceError("x"), SanjeevaniError)

    def test_catch_all_via_base(self):
        """Callers catching SanjeevaniError get every subtype."""
        for exc_class in (InputError, BoundaryError, KnowledgeError, InferenceError):
            try:
                raise exc_class("test message")
            except SanjeevaniError:
                pass  # expected — all subtypes must be catchable here

    def test_message_preserved(self):
        msg = "Heart rate 999 out of range"
        exc = BoundaryError(msg)
        assert msg in str(exc)
