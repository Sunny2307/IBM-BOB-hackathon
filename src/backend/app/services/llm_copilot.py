"""Optional Groq tool-calling layer for Grid Copilot.

This is a real LLM (Groq's free-tier, OpenAI-compatible chat-completions API)
wired up with TOOL CALLING against the exact same functions in grid_tools.py
that power the deterministic router, the REST API, and the MCP server. The
model can only state facts it pulled back from a tool call against real
in-memory data — it never has a way to answer without going through
`app.services.grid_tools`, so it cannot invent asset IDs, scores, or dates.

This module is entirely additive and OPT-IN (LLM_PROVIDER=groq + GROQ_API_KEY
must both be set). It never swallows its own errors: every failure mode
(missing key, timeout, non-2xx, malformed response, malformed tool-call
arguments, too many tool-calling rounds) raises LLMCopilotError so the caller
(app.services.copilot_service.ask) can decide the fallback. That caller falls
back to the deterministic keyword router on ANY exception from here — that is
what keeps the app's "zero dependency on a live API key" guarantee true.
"""

import json
import os

import httpx

from app.services import grid_tools

GROQ_CHAT_COMPLETIONS_URL = "https://api.groq.com/openai/v1/chat/completions"
DEFAULT_MODEL = "llama-3.3-70b-versatile"
REQUEST_TIMEOUT_SECONDS = 8.0
MAX_TOOL_ROUNDS = 3

SYSTEM_PROMPT = (
    "You are Grid Copilot, an operational assistant embedded in the Grid "
    "Failure Advisor app for utility grid operators. You have tools that "
    "query the live, in-memory synthetic asset/sensor/weather/incident data "
    "for this deployment. You must ONLY state facts returned by your tool "
    "calls — never invent asset IDs, risk scores, regions, dates, or counts. "
    "If a tool call returns an error or an empty result, say so plainly "
    "instead of guessing. Be concise and operational in tone, like a message "
    "to a grid operator making a real-time decision, not a chatty assistant. "
    "Always call at least one tool before answering any question about "
    "assets, risk, or maintenance; only skip tool calls for greetings or "
    "small talk."
)

TOOLS: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "get_at_risk_assets",
            "description": (
                "Get the highest-risk grid assets (transformers/substations), "
                "ranked by predicted failure risk score. Optionally filter by "
                "region and a minimum risk tier."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "region": {
                        "type": "string",
                        "description": "Region name to filter by, e.g. 'Eastgate'. Omit for all regions.",
                    },
                    "min_tier": {
                        "type": "string",
                        "enum": ["Critical", "High", "Medium", "Low"],
                        "description": "Minimum risk tier to include. Default 'Medium'.",
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of assets to return. Default 10.",
                    },
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_asset_detail",
            "description": "Get full metadata and the current risk score/tier for one grid asset by its ID (e.g. 'AST-014').",
            "parameters": {
                "type": "object",
                "properties": {
                    "asset_id": {"type": "string", "description": "Asset ID, e.g. 'AST-014'."},
                },
                "required": ["asset_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "explain_asset_risk",
            "description": (
                "Get the full explainable risk breakdown for one grid asset: every "
                "scoring component (sensor anomalies, weather risk, historical "
                "incident rate) with its point contribution and a plain-language "
                "explanation, plus the underlying sensor readings and weather forecast."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "asset_id": {"type": "string", "description": "Asset ID, e.g. 'AST-014'."},
                },
                "required": ["asset_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_maintenance_plan",
            "description": (
                "Get the prioritized, region-grouped maintenance and crew "
                "pre-positioning plan: which assets to act on, what action to "
                "take, and by what date, timed against upcoming severe weather. "
                "Optionally filter to one region."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "region": {
                        "type": "string",
                        "description": "Region name to filter by. Omit for all regions.",
                    },
                    "top_n": {
                        "type": "integer",
                        "description": "Maximum number of plan items to return. Default 10.",
                    },
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_regions",
            "description": "List every region with monitored grid assets.",
            "parameters": {"type": "object", "properties": {}, "required": []},
        },
    },
]

TOOL_FUNCTIONS = {
    "get_at_risk_assets": grid_tools.get_at_risk_assets,
    "get_asset_detail": grid_tools.get_asset_detail,
    "explain_asset_risk": grid_tools.explain_asset_risk,
    "get_maintenance_plan": grid_tools.get_maintenance_plan,
    "list_regions": grid_tools.list_regions,
}


class LLMCopilotError(RuntimeError):
    """Raised on any failure of the Groq tool-calling path. The caller
    (copilot_service.ask) catches this and falls back to the deterministic
    router — this module never silently degrades on its own."""


def _execute_tool(name: str, arguments: dict) -> dict:
    func = TOOL_FUNCTIONS.get(name)
    if func is None:
        return {"error": f"Unknown tool '{name}'"}
    try:
        return func(**arguments)
    except (TypeError, AttributeError, ValueError, KeyError) as exc:
        return {"error": f"Invalid arguments for '{name}': {exc}"}


def _build_messages(question: str, history: list[dict]) -> list[dict]:
    messages: list[dict] = [{"role": "system", "content": SYSTEM_PROMPT}]
    for msg in history:
        role = msg.get("role")
        content = msg.get("content")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": question})
    return messages


async def ask_llm(question: str, history: list[dict]) -> dict:
    """Runs the Groq tool-calling loop for one question and returns a dict
    shaped like the deterministic router's answer: {answer, tool_calls, data}.
    Raises LLMCopilotError on any failure — never returns a partial/guessed
    answer."""
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise LLMCopilotError("GROQ_API_KEY is not set")

    model = os.getenv("GROQ_MODEL") or DEFAULT_MODEL
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    messages = _build_messages(question, history)

    tool_calls_made: list[dict] = []
    last_tool_data = None

    async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT_SECONDS) as client:
        for _round in range(MAX_TOOL_ROUNDS):
            payload = {
                "model": model,
                "messages": messages,
                "tools": TOOLS,
                "tool_choice": "auto",
            }
            try:
                response = await client.post(GROQ_CHAT_COMPLETIONS_URL, headers=headers, json=payload)
            except httpx.HTTPError as exc:
                raise LLMCopilotError(f"Groq request failed: {exc.__class__.__name__}") from exc

            if response.status_code >= 400:
                raise LLMCopilotError(f"Groq returned HTTP {response.status_code}")

            try:
                body = response.json()
                message = body["choices"][0]["message"]
            except (KeyError, IndexError, ValueError, TypeError) as exc:
                raise LLMCopilotError(f"Malformed Groq response: {exc}") from exc

            requested_calls = message.get("tool_calls")
            if not requested_calls:
                answer = message.get("content")
                if not answer:
                    raise LLMCopilotError("Groq returned no content and no tool calls")
                return {"answer": answer, "tool_calls": tool_calls_made, "data": last_tool_data}

            messages.append(message)
            for call in requested_calls:
                fn = call.get("function", {})
                name = fn.get("name")
                try:
                    arguments = json.loads(fn.get("arguments") or "{}")
                except json.JSONDecodeError as exc:
                    raise LLMCopilotError(f"Malformed tool arguments from Groq: {exc}") from exc

                result = _execute_tool(name, arguments)
                tool_calls_made.append({"tool": name, "args": arguments})
                last_tool_data = result
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": call.get("id"),
                        "content": json.dumps(result),
                    }
                )

    raise LLMCopilotError(f"Exceeded {MAX_TOOL_ROUNDS} tool-calling rounds without a final answer")
