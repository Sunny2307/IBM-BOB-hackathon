"""Ensures synthetic data exists before any test runs, so `pytest` works
standalone on a fresh clone regardless of whether generate_synthetic_data.py
was already run."""

import subprocess
import sys
from pathlib import Path

import pytest

BACKEND_ROOT = Path(__file__).resolve().parent.parent
DATA_FILE = BACKEND_ROOT / "app" / "data" / "generated" / "assets.json"


@pytest.fixture(scope="session", autouse=True)
def ensure_synthetic_data():
    if not DATA_FILE.exists():
        subprocess.run(
            [sys.executable, str(BACKEND_ROOT / "scripts" / "generate_synthetic_data.py")],
            check=True,
            cwd=BACKEND_ROOT,
        )
    # Clear any cached load from a previous process/import so tests see fresh data.
    from app.services import data_loader

    data_loader._load_all.cache_clear()
