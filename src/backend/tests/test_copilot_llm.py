"""Proves three things about the new Groq tool-calling layer, without ever
needing a real Groq API key:

  (a) When LLM_PROVIDER=groq and GROQ_API_KEY are both set, copilot_service.ask
      actually goes through the LLM path (app.services.llm_copilot), including
      the tool-calling round-trip against real grid_tools data.
  (b) ANY failure in that path (timeout, bad response, etc.) falls back to the
      existing deterministic router with its EXACT output — never a partial
      or guessed answer.
  (c) With LLM_PROVIDER=none / no key (the default), behavior is byte-for-byte
      identical to the pre-existing deterministic router.

httpx.AsyncClient is monkeypatched with a small fake so no network call is
ever made.
"""

import asyncio

import httpx
import pytest

from app.services import copilot_service, grid_tools, llm_copilot


class _FakeResponse:
    def __init__(self, status_code: int, payload: dict):
        self.status_code = status_code
        self._payload = payload

    def json(self):
        return self._payload


class _FakeAsyncClient:
    """Stands in for httpx.AsyncClient: returns the queued responses in order."""

    def __init__(self, responses):
        self._responses = list(responses)

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc_info):
        return False

    async def post(self, url, headers=None, json=None):
        return self._responses.pop(0)


class _FailingAsyncClient:
    """Simulates a network-level failure (e.g. timeout) on entry."""

    async def __aenter__(self):
        raise httpx.ConnectTimeout("simulated timeout")

    async def __aexit__(self, *exc_info):
        return False


def _install_fake_client(monkeypatch, responses):
    monkeypatch.setattr(llm_copilot.httpx, "AsyncClient", lambda *a, **k: _FakeAsyncClient(responses))


def _install_failing_client(monkeypatch):
    monkeypatch.setattr(llm_copilot.httpx, "AsyncClient", lambda *a, **k: _FailingAsyncClient())


# --- (a) LLM path is actually attempted / used when configured -------------


def test_llm_path_used_for_direct_answer_when_configured(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    monkeypatch.setenv("GROQ_API_KEY", "fake-key-for-test")

    marker_answer = "LLM-DIRECT-ANSWER-MARKER-12345"
    fake_response = _FakeResponse(
        200, {"choices": [{"message": {"role": "assistant", "content": marker_answer}}]}
    )
    _install_fake_client(monkeypatch, [fake_response])

    result = asyncio.run(copilot_service.ask("hello there", history=[]))

    assert result["answer"] == marker_answer
    assert result["tool_calls"] == []
    # The deterministic router would have answered the "hello" greeting text
    # instead — proving this really is the LLM path, not a coincidental match.
    assert result["answer"] != copilot_service._ask_deterministic("hello there")["answer"]


def test_llm_path_executes_real_tool_calls_grounded_on_real_data(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    monkeypatch.setenv("GROQ_API_KEY", "fake-key-for-test")

    tool_call_response = _FakeResponse(
        200,
        {
            "choices": [
                {
                    "message": {
                        "role": "assistant",
                        "content": None,
                        "tool_calls": [
                            {
                                "id": "call_1",
                                "function": {"name": "list_regions", "arguments": "{}"},
                            }
                        ],
                    }
                }
            ]
        },
    )
    final_response = _FakeResponse(
        200, {"choices": [{"message": {"role": "assistant", "content": "Here are the regions."}}]}
    )
    _install_fake_client(monkeypatch, [tool_call_response, final_response])

    result = asyncio.run(copilot_service.ask("what regions do we operate in?", history=[]))

    assert result["answer"] == "Here are the regions."
    assert result["tool_calls"] == [{"tool": "list_regions", "args": {}}]
    # The tool result returned is the REAL data, not anything invented.
    assert result["data"] == grid_tools.list_regions()


def test_llm_path_receives_conversation_history():
    """The history the frontend already tracks must actually reach the model
    as prior messages, not be dropped."""
    history = [{"role": "user", "content": "earlier question"}, {"role": "assistant", "content": "earlier answer"}]
    messages = llm_copilot._build_messages("current question", history)

    assert messages[0]["role"] == "system"
    assert {"role": "user", "content": "earlier question"} in messages
    assert {"role": "assistant", "content": "earlier answer"} in messages
    assert messages[-1] == {"role": "user", "content": "current question"}


# --- (b) any failure falls back to the deterministic router, unchanged -----


@pytest.mark.parametrize(
    "question",
    [
        "which assets are highest risk?",
        "why is AST-001 risky?",
        "what's the maintenance plan for Eastgate?",
    ],
)
def test_llm_network_failure_falls_back_to_deterministic_exactly(monkeypatch, question):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    monkeypatch.setenv("GROQ_API_KEY", "fake-key-for-test")
    _install_failing_client(monkeypatch)

    expected = copilot_service._ask_deterministic(question)
    result = asyncio.run(copilot_service.ask(question, history=[]))

    assert result == expected


def test_llm_malformed_response_falls_back_to_deterministic(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    monkeypatch.setenv("GROQ_API_KEY", "fake-key-for-test")
    _install_fake_client(monkeypatch, [_FakeResponse(200, {"unexpected": "shape"})])

    question = "which assets are highest risk?"
    expected = copilot_service._ask_deterministic(question)
    result = asyncio.run(copilot_service.ask(question, history=[]))

    assert result == expected


def test_llm_http_error_falls_back_to_deterministic(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    monkeypatch.setenv("GROQ_API_KEY", "fake-key-for-test")
    _install_fake_client(monkeypatch, [_FakeResponse(401, {"error": "unauthorized"})])

    question = "which assets are highest risk?"
    expected = copilot_service._ask_deterministic(question)
    result = asyncio.run(copilot_service.ask(question, history=[]))

    assert result == expected


def test_missing_api_key_with_provider_groq_falls_back_to_deterministic(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    monkeypatch.delenv("GROQ_API_KEY", raising=False)

    question = "which assets are highest risk?"
    expected = copilot_service._ask_deterministic(question)
    result = asyncio.run(copilot_service.ask(question, history=[]))

    assert result == expected


# --- (c) default configuration (no key) is byte-for-byte the old behavior --


@pytest.mark.parametrize(
    "question",
    [
        "hello",
        "which assets are highest risk?",
        "why is AST-001 risky?",
        "what's the maintenance plan for Eastgate?",
        "some question with no matching intent at all",
    ],
)
def test_provider_none_matches_pre_existing_deterministic_behavior_exactly(monkeypatch, question):
    monkeypatch.setenv("LLM_PROVIDER", "none")
    monkeypatch.delenv("GROQ_API_KEY", raising=False)

    expected = copilot_service._ask_deterministic(question)
    result = asyncio.run(copilot_service.ask(question, history=[]))

    assert result == expected
