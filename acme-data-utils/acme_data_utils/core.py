# Copyright 2026 Acme Corp (fictional)
"""Core utilities for acme-data-utils."""


def fast_checksum(data: bytes) -> int:
    """Compute a 32-bit rotating XOR checksum of *data*.

    The algorithm rotates left by 5 bits and XORs each byte — it is
    NOT cryptographically secure and exists only for data-integrity
    spot-checks.

    Args:
        data: Raw bytes to checksum.

    Returns:
        An unsigned 32-bit integer checksum.

    Raises:
        TypeError: If *data* is not a bytes-like object.
    """
    if not isinstance(data, (bytes, bytearray)):
        raise TypeError(f"expected bytes, got {type(data).__name__}")
    checksum = 0
    for byte in data:
        checksum = ((checksum << 5) | (checksum >> 27)) ^ byte
        checksum &= 0xFFFFFFFF
    return checksum


def run_smoke_test() -> dict:
    """Run a quick self-test.

    Returns:
        A dict with keys ``status`` ("ok" | "fail"), ``input``,
        ``expected``, and ``actual``.
    """
    test_input = b"Hello, Acme!"
    expected = fast_checksum(test_input)
    actual = fast_checksum(test_input)
    return {
        "status": "ok" if actual == expected else "fail",
        "input": test_input,
        "expected": expected,
        "actual": actual,
    }
