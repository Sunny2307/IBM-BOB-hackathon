"""Route/schema-level tests for POST /copilot/ask.

The unit tests in test_copilot_llm.py exercise copilot_service.ask() directly
and never go through Pydantic validation. That gap is exactly how a real bug
shipped: CopilotRequest.history is capped at max_length=20 (schemas.py) but
the frontend originally sent its full, unbounded history, so any chat past
~11 exchanges got a 422 the client misreported as "backend unreachable".
These tests pin the actual HTTP contract so that regressions here fail CI
instead of a live user's 11th question.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _history(n: int) -> list[dict]:
    return [{"role": "user", "content": f"turn {i}"} for i in range(n)]


def test_ask_with_no_history_succeeds():
    response = client.post("/copilot/ask", json={"question": "which assets are highest risk?"})
    assert response.status_code == 200
    assert "answer" in response.json()


def test_ask_with_max_allowed_history_succeeds():
    response = client.post(
        "/copilot/ask",
        json={"question": "what about now?", "history": _history(20)},
    )
    assert response.status_code == 200


def test_ask_with_too_much_history_is_rejected():
    response = client.post(
        "/copilot/ask",
        json={"question": "what about now?", "history": _history(21)},
    )
    assert response.status_code == 422


def test_ask_with_oversized_message_content_is_rejected():
    response = client.post(
        "/copilot/ask",
        json={"question": "ok", "history": [{"role": "user", "content": "x" * 2001}]},
    )
    assert response.status_code == 422
