"""Ensures synthetic data exists before any test runs, so `pytest` works
standalone on a fresh clone regardless of whether generate_synthetic_data.py
was already run.

Also pins WEATHER_SOURCE=synthetic for the whole suite: these tests assert
logic, and the seeded forecast is the only way to assert it deterministically.
Against live weather they would pass or fail based on today's actual sky (and
need network), which is not a property of the code. The live path gets its own
offline tests in test_weather_live.py.
"""

import os
import subprocess
import sys
from pathlib import Path

import pytest

BACKEND_ROOT = Path(__file__).resolve().parent.parent
DATA_FILE = BACKEND_ROOT / "app" / "data" / "generated" / "assets.json"


@pytest.fixture(scope="session", autouse=True)
def pin_synthetic_weather():
    os.environ["WEATHER_SOURCE"] = "synthetic"


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


@pytest.fixture(scope="session", autouse=True)
def close_db_pool():
    """Closes the psycopg pool before interpreter shutdown.

    Without this, psycopg_pool's __del__ tries to join its worker threads after
    Python has started finalizing and raises PythonFinalizationError — harmless
    but it prints a traceback after a green run, which reads as a failure.
    """
    yield
    from app import db

    db.close()
