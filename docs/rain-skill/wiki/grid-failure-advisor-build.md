# Grid Failure Advisor — Build Notes

Built 2026-09-15 for the IBM BoB AI Innovation Hackathon 2026 (deadline
11:45 PM same day, U1 problem statement — Power Outage Prediction & Grid
Equipment Failure Advisor). See [u1-grid-failure-advisor.md](../../../u1-grid-failure-advisor.md)
for the original execution plan.

## Stack
Python FastAPI backend (`src/backend`) + React/Vite/TS frontend
(`src/frontend`), synthetic data (deterministic generator, seed 42), MCP
server for IBM Bob integration.

## Key decisions and why
- **Rule-based risk scoring, not ML** — explainability and speed under time
  pressure; every point of the 0-100 score traces to a named factor. See
  `app/services/risk_engine.py`.
- **MCP server and the in-app Copilot share one implementation**
  (`app/services/grid_tools.py`) — this is what makes "IBM Bob integration"
  load-bearing rather than name-dropped. Verified: `mcp.call_tool()` returns
  the same numbers the dashboard shows.
- **Deterministic Copilot, no LLM key required** — protects the live demo
  from Wi-Fi/API-key failures.
- **mcp pinned to `>=1.28.1,<2.0.0`** — mcp 2.x renamed `FastMCP` to
  `MCPServer` (breaking API change); pinned below that line to keep the
  patched-CVE 1.x line without a rewrite under time pressure.

## Verification performed (not just "should work")
- Backend: curl against every endpoint with real generated data
- MCP: `asyncio.run(mcp.call_tool(...))` returns real, matching data
- Frontend: Playwright drove the actual running app (dashboard → asset
  detail → maintenance plan → copilot), screenshotted all 4 states, zero
  console errors, confirmed no "DEMO DATA" fallback banner anywhere
- Security: pip-audit + npm audit run, real CVEs found (starlette/mcp/
  python-dotenv/setuptools) and fixed by upgrading; re-verified nothing
  broke; independent security-auditor agent pass found only two
  low-severity/non-exploitable input-constraint items, which were hardened
  anyway (Pydantic `Field` + `Path` regex)

## What's NOT done (human-only, cannot be automated)
1. Real team name and roster (placeholder: "Grid Failure Advisors" /
   Malay Sheta, inferred from session email — needs confirmation)
2. Demo video recording — `demo/demo-video-link.txt` still has the
   template's placeholder URL; this is the one item that will fail the
   repo's `validate.yml` GitHub Action until fixed
3. `git add`/commit/push — nothing has been pushed; local verification only
