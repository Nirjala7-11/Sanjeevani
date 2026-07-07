"""
Security-specific tests.

These tests verify properties that have direct security or privacy
implications. Failures here are security incidents, not just bugs.
"""
import sys
sys.path.insert(0, "/home/claude/sanjeevani_pro")

import pytest
from sanjeevani.exceptions import InferenceError
from sanjeevani.inference.llamacpp import LlamaCppBackend, _assert_loopback


class TestLoopbackEnforcement:
    """
    The LlamaCppBackend must ONLY connect to loopback addresses.
    Connecting to any other address routes patient data off-device.
    """

    # ── Addresses that MUST be accepted ──────────────────────────────────

    def test_ipv4_loopback_accepted(self):
        _assert_loopback("127.0.0.1")  # must not raise

    def test_localhost_name_accepted(self):
        _assert_loopback("localhost")

    def test_ipv6_loopback_accepted(self):
        _assert_loopback("::1")

    def test_ipv4_loopback_range_accepted(self):
        """127.x.x.x addresses are all loopback in IPv4."""
        _assert_loopback("127.0.0.2")

    # ── Addresses that MUST be rejected ──────────────────────────────────

    def test_public_ipv4_rejected(self):
        with pytest.raises(InferenceError, match="SECURITY VIOLATION"):
            _assert_loopback("8.8.8.8")

    def test_private_lan_ipv4_rejected(self):
        with pytest.raises(InferenceError, match="SECURITY VIOLATION"):
            _assert_loopback("192.168.1.100")

    def test_another_private_range_rejected(self):
        with pytest.raises(InferenceError, match="SECURITY VIOLATION"):
            _assert_loopback("10.0.0.1")

    def test_any_address_0_0_0_0_rejected(self):
        with pytest.raises(InferenceError, match="SECURITY VIOLATION"):
            _assert_loopback("0.0.0.0")

    def test_arbitrary_hostname_rejected(self):
        with pytest.raises(InferenceError, match="SECURITY VIOLATION"):
            _assert_loopback("my-cloud-server.example.com")

    def test_cloud_provider_hostname_rejected(self):
        with pytest.raises(InferenceError, match="SECURITY VIOLATION"):
            _assert_loopback("model.openai.com")

    def test_gradio_live_rejected(self):
        """Ensure Gradio's share=True tunnel endpoint is rejected."""
        with pytest.raises(InferenceError, match="SECURITY VIOLATION"):
            _assert_loopback("gradio.live")

    # ── Error message quality ─────────────────────────────────────────────

    def test_rejection_message_contains_offending_host(self):
        try:
            _assert_loopback("192.168.1.50")
        except InferenceError as e:
            assert "192.168.1.50" in str(e)

    def test_rejection_message_mentions_loopback(self):
        try:
            _assert_loopback("8.8.8.8")
        except InferenceError as e:
            assert "127.0.0.1" in str(e)

    # ── Backend construction enforcement ─────────────────────────────────

    def test_backend_construction_refuses_non_loopback(self):
        """The check must fire at construction, not just in generate()."""
        with pytest.raises(InferenceError, match="SECURITY VIOLATION"):
            LlamaCppBackend(host="192.168.1.1", port=8080)

    def test_backend_construction_accepts_loopback(self):
        backend = LlamaCppBackend(host="127.0.0.1", port=8080)
        assert "127.0.0.1" in backend.base_url

    def test_backend_health_check_returns_false_when_server_down(self):
        """health_check() must return False (not raise) when server isn't running."""
        backend = LlamaCppBackend(host="127.0.0.1", port=19999)
        result = backend.health_check()
        assert result is False

    def test_backend_generate_raises_inference_error_when_server_down(self):
        """generate() must raise InferenceError (not requests.ConnectionError)."""
        backend = LlamaCppBackend(host="127.0.0.1", port=19999)
        with pytest.raises(InferenceError):
            backend.generate("test prompt")


class TestSecretHandling:

    def test_get_secret_returns_none_not_empty_string(self, monkeypatch):
        from sanjeevani.config import get_secret
        monkeypatch.delenv("HF_TOKEN", raising=False)
        result = get_secret("HF_TOKEN")
        assert result is None
        assert result != ""

    def test_empty_env_var_returns_none(self, monkeypatch):
        from sanjeevani.config import get_secret
        monkeypatch.setenv("HF_TOKEN", "")
        assert get_secret("HF_TOKEN") is None

    def test_whitespace_env_var_returns_none(self, monkeypatch):
        from sanjeevani.config import get_secret
        monkeypatch.setenv("HF_TOKEN", "    ")
        assert get_secret("HF_TOKEN") is None
