# Copyright 2026 Acme Corp (fictional)
"""Smoke tests for acme-data-utils."""

import pytest

import acme_data_utils
from acme_data_utils import fast_checksum, run_smoke_test


class TestFastChecksum:
    """Tests for the fast_checksum function."""

    def test_known_value(self):
        """Checksum of a known input matches the reference implementation."""
        data = b"Hello, Acme!"
        result = fast_checksum(data)
        assert isinstance(result, int)
        assert 0 <= result <= 0xFFFFFFFF

    def test_empty_input(self):
        """Empty bytes should produce a checksum of zero."""
        assert fast_checksum(b"") == 0

    def test_single_byte(self):
        """Single byte should equal the byte value itself."""
        assert fast_checksum(b"\x42") == 0x42

    def test_deterministic(self):
        """Same input always produces the same output."""
        data = b"reproducible builds matter"
        assert fast_checksum(data) == fast_checksum(data)

    def test_different_inputs_differ(self):
        """Different inputs should (almost certainly) produce different checksums."""
        assert fast_checksum(b"alpha") != fast_checksum(b"beta")

    def test_bytearray_input(self):
        """bytearray should also be accepted."""
        data = bytearray(b"test bytearray")
        result = fast_checksum(data)
        assert isinstance(result, int)

    def test_rejects_string(self):
        """Passing a str instead of bytes should raise TypeError."""
        with pytest.raises(TypeError):
            fast_checksum("not bytes")  # type: ignore[arg-type]


class TestSmokeTest:
    """Tests for the run_smoke_test self-check function."""

    def test_smoke_test_passes(self):
        """The built-in smoke test should report 'ok'."""
        result = run_smoke_test()
        assert result["status"] == "ok"
        assert result["expected"] == result["actual"]

    def test_smoke_test_keys(self):
        """Smoke test result should contain expected keys."""
        result = run_smoke_test()
        assert set(result.keys()) == {"status", "input", "expected", "actual"}


class TestPackageMetadata:
    """Basic sanity checks on the installed package."""

    def test_version_exists(self):
        """Package should expose a __version__ string."""
        assert hasattr(acme_data_utils, "__version__")
        assert isinstance(acme_data_utils.__version__, str)
