# acme-data-utils

A minimal Python package used internally at **Acme Corp** for fast
data-processing checksums.

## Quick Start

### Prerequisites

- Python 3.9+
- `pip` and `setuptools>=64`

### Install from source

```bash
pip install .
```

### Build a distributable package

```bash
# Install build frontend
pip install build

# Produce sdist (.tar.gz) and wheel (.whl) in dist/
python -m build
```

### Run tests

```bash
pip install ".[test]"
pytest tests/
```

## Package Structure

```
acme-data-utils/
├── acme_data_utils/
│   ├── __init__.py       # Exposes fast_checksum, run_smoke_test, __version__
│   └── core.py           # Checksum implementation
├── tests/
│   └── test_smoke.py     # pytest-based test suite
├── setup.py              # Build configuration
├── setup.cfg             # Package metadata
├── pyproject.toml        # Build system declaration
└── README.md             # This file
```

## Usage

```python
from acme_data_utils import fast_checksum, run_smoke_test

# Compute a checksum
checksum = fast_checksum(b"some data payload")
print(f"Checksum: {checksum:#010x}")

# Run the built-in self-test
result = run_smoke_test()
print(result)  # {'status': 'ok', 'input': b'Hello, Acme!', 'expected': ..., 'actual': ...}
```

## License

Proprietary — Acme Corp internal use only.
