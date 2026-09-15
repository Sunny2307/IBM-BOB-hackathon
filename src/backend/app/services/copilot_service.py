"""Grid Copilot: `ask()` is the public entry point, and it always has a
DETERMINISTIC keyword/intent router (`_ask_deterministic`, below) as its
answer of last resort. No LLM call is required for a correct answer — this is
a deliberate resilience decision so the live demo never depends on network
access to an LLM provider or a valid API key.

If LLM_PROVIDER=groq and GROQ_API_KEY is set (see .env.example), `ask()`
first tries app.services.llm_copilot: a real LLM (Groq's free-tier,
OpenAI-compatible API) with TOOL CALLING grounded on the exact same
grid_tools functions the deterministic router and the MCP server use, so it
can only state facts pulled from real data, never invented ones. On ANY
failure of that path (missing key, timeout, HTTP error, malformed response),
`ask()` falls back to `_ask_deterministic` UNCHANGED — this is what keeps the
"zero dependency on a live API key" guarantee true.
"""

import os
import re

from app.services import data_loader, grid_tools, llm_copilot

TIER_WORDS = ["critical", "high", "medium", "low"]


def _find_region(question: str) -> str | None:
    q = question.lower()
    for region in data_loader.get_regions():
        if region.lower() in q:
            return region
    return None


def _find_tier(question: str) -> str | None:
    q = question.lower()
    for tier in TIER_WORDS:
        if tier in q:
            return tier.capitalize()
    return None


def _find_asset_id(question: str) -> str | None:
    match = re.search(r"AST-\d+", question, re.IGNORECASE)
    if match:
        candidate = match.group(0).upper()
        if data_loader.get_asset(candidate):
            return candidate

    q = question.lower()
    for asset in data_loader.get_assets():
        if asset["name"].lower() in q:
            return asset["asset_id"]
    return None


def _format_at_risk_answer(result: dict) -> str:
    assets = result["assets"]
    if not assets:
        scope = f" in {result['region_filter']}" if result["region_filter"] else ""
        return f"No assets currently meet the '{result['min_tier']}' risk threshold{scope}."

    scope = f" in {result['region_filter']}" if result["region_filter"] else ""
    lines = [f"{a['name']} — {a['risk_tier']} (score {a['risk_score']}/100, {a['region']})" for a in assets[:5]]
    header = f"Top {len(lines)} highest-risk assets{scope}:"
    return header + "\n" + "\n".join(f"- {line}" for line in lines)


def _format_explain_answer(breakdown: dict) -> str:
    asset = data_loader.get_asset(breakdown["asset_id"])
    top_factors = sorted(breakdown["components"], key=lambda c: c["contribution"], reverse=True)[:3]
    factor_lines = [f"- {f['factor']} (+{f['contribution']} pts): {f['explanation']}" for f in top_factors]
    return (
        f"{asset['name']} is {breakdown['risk_tier']} risk (score {breakdown['risk_score']}/100). "
        f"Top contributing factors:\n" + "\n".join(factor_lines)
    )


def _format_plan_answer(plan: dict) -> str:
    all_items = [(r["region"], item) for r in plan["regions"] for item in r["items"]]
    if not all_items:
        return "No assets currently require prioritized maintenance action."

    all_items.sort(key=lambda pair: pair[1]["priority_score"], reverse=True)
    lines = [
        f"{item['asset_name']} ({region}) — {item['recommended_action']} by {item['recommended_by_date']}"
        for region, item in all_items[:5]
    ]
    return "Top prioritized maintenance actions:\n" + "\n".join(f"- {line}" for line in lines)


async def ask(question: str, history: list[dict] | None = None) -> dict:
    """Public entry point used by the /copilot/ask route.

    Tries the optional Groq tool-calling LLM path first (only when
    LLM_PROVIDER=groq and GROQ_API_KEY are both set), passing along the
    conversation history the frontend already tracks. Falls back to the
    deterministic router on ANY exception from that path, so the app never
    depends on a live API key to answer correctly.
    """
    history = history or []
    provider = os.getenv("LLM_PROVIDER", "none").lower()
    api_key = os.getenv("GROQ_API_KEY")

    if provider == "groq" and api_key:
        try:
            return await llm_copilot.ask_llm(question, history)
        except Exception as exc:  # noqa: BLE001 - deliberate: any failure at all falls back
            print(f"[copilot] LLM path failed ({exc.__class__.__name__}: {exc}); using deterministic router.")

    return _ask_deterministic(question)


def _ask_deterministic(question: str) -> dict:
    q = question.lower().strip()
    tool_calls = []

    if q in {"hello", "hi", "hey"} or q.startswith(("good morning", "good afternoon")):
        return {
            "answer": (
                "Grid Copilot online. I can check highest-risk assets, explain an asset score, "
                "or build a maintenance plan."
            ),
            "tool_calls": [],
            "data": None,
        }

    is_explain = any(w in q for w in ["why", "explain", "breakdown", "reason"])
    asset_id = _find_asset_id(question) if is_explain or "ast-" in q else None

    if asset_id:
        result = grid_tools.explain_asset_risk(asset_id)
        tool_calls.append({"tool": "explain_asset_risk", "args": {"asset_id": asset_id}})
        answer = _format_explain_answer(result)
        return {"answer": answer, "tool_calls": tool_calls, "data": result}

    if any(w in q for w in ["maintenance", "crew", "pre-position", "prepos", "plan"]):
        region = _find_region(question)
        result = grid_tools.get_maintenance_plan(region=region)
        tool_calls.append({"tool": "get_maintenance_plan", "args": {"region": region}})
        answer = _format_plan_answer(result)
        return {"answer": answer, "tool_calls": tool_calls, "data": result}

    if any(w in q for w in ["risk", "at-risk", "at risk", "worst", "highest", "dangerous", "fail"]):
        region = _find_region(question)
        tier = _find_tier(question) or "Medium"
        result = grid_tools.get_at_risk_assets(region=region, min_tier=tier)
        tool_calls.append(
            {"tool": "get_at_risk_assets", "args": {"region": region, "min_tier": tier, "limit": 10}}
        )
        answer = _format_at_risk_answer(result)
        return {"answer": answer, "tool_calls": tool_calls, "data": result}

    return {
        "answer": (
            f"I couldn't identify a grid operation in '{question}'. "
            "Try asking which assets are highest risk, why an asset is risky, "
            "or what the maintenance plan is for a region."
        ),
        "tool_calls": [],
        "data": None,
    }
