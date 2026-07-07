"""
Tests for configuration immutability, secret handling, and path setup.
"""
import sys, os
sys.path.insert(0, "/home/claude/sanjeevani_pro")

import pytest
from sanjeevani.config import CFG, AppConfig, get_secret


class TestConfigImmutability:

    def test_config_is_frozen(self):
        with pytest.raises((AttributeError, TypeError)):
            CFG.scoring.cut_low = 999

    def test_nested_config_frozen(self):
        with pytest.raises((AttributeError, TypeError)):
            CFG.clinical.hr_elevated_bpm = 0

    def test_vital_bounds_frozen(self):
        with pytest.raises((AttributeError, TypeError)):
            CFG.bounds.hr_max_bpm = 999

    def test_cfg_is_app_config(self):
        assert isinstance(CFG, AppConfig)


class TestScoringCalibration:
    """
    Verify that the scoring calibration satisfies the stated design property:
    any single CRITICAL-tier alert must reach HIGH on its own.
    """

    def test_single_critical_spo2_reaches_high(self):
        """spo2_critical alone must exceed cut_medium."""
        w = CFG.scoring
        assert w.spo2_critical > w.cut_medium, (
            f"spo2_critical ({w.spo2_critical}) must exceed cut_medium "
            f"({w.cut_medium}) so a critically low SpO2 alone reaches HIGH"
        )

    def test_single_critical_hr_reaches_high(self):
        w = CFG.scoring
        assert w.hr_critical > w.cut_medium

    def test_single_high_fever_reaches_high(self):
        w = CFG.scoring
        assert w.high_fever > w.cut_medium

    def test_low_band_is_zero_based(self):
        """LOW band must include score=0 (all normal)."""
        assert CFG.scoring.cut_low >= 0

    def test_bands_are_ordered(self):
        w = CFG.scoring
        assert w.cut_low < w.cut_medium


class TestSecretHandling:

    def test_absent_env_var_returns_none(self, monkeypatch):
        monkeypatch.delenv("HF_TOKEN", raising=False)
        assert get_secret("HF_TOKEN") is None

    def test_empty_env_var_treated_as_absent(self, monkeypatch):
        monkeypatch.setenv("HF_TOKEN", "")
        assert get_secret("HF_TOKEN") is None

    def test_whitespace_only_env_var_treated_as_absent(self, monkeypatch):
        monkeypatch.setenv("HF_TOKEN", "   ")
        assert get_secret("HF_TOKEN") is None

    def test_present_env_var_returned(self, monkeypatch):
        monkeypatch.setenv("HF_TOKEN", "hf_test_value")
        result = get_secret("HF_TOKEN")
        assert result == "hf_test_value"

    def test_different_keys_independent(self, monkeypatch):
        monkeypatch.setenv("KEY_A", "value_a")
        monkeypatch.delenv("KEY_B", raising=False)
        assert get_secret("KEY_A") == "value_a"
        assert get_secret("KEY_B") is None
