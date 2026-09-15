# Demo Video Script — Grid Failure Advisor

Target length: **3-5 minutes**. Everything below is written to fit comfortably
in ~4 minutes at a normal speaking pace. Read it out loud once before
recording — trim anything that feels rushed.

---

## Before you hit record

1. **Start both servers** (two terminals):
   ```bash
   # Terminal 1 — backend
   cd src/backend
   .venv\Scripts\activate
   uvicorn app.main:app --reload --port 8000

   # Terminal 2 — frontend
   cd src/frontend
   npm run dev
   ```
2. Open **http://localhost:5173** in a clean browser window (close other tabs,
   hide bookmarks bar, use a normal window size like 1440×900 — don't
   maximize on an ultrawide, it'll look odd on YouTube).
3. Close any notifications/Slack popups. Do a full-screen or windowed capture
   of just the browser.
4. **Recording tool** — pick one, all free:
   - **Windows Game Bar**: `Win + G` → record button (built into Windows 11, easiest)
   - **OBS Studio**: more control, slightly more setup
   - **Loom**: records + uploads + gives you a shareable link in one step (recommended — saves you the separate YouTube upload step)
5. Do one silent practice run clicking through the flow below before recording with audio, so you don't fumble live.

---

## The script

Speak naturally — this is a guide, not something to read robotically. Bold
lines are exact suggested phrasing; *italic* lines are what to click/show.

### [0:00–0:20] Hook + Problem

*Screen: browser open on the dashboard, but don't scroll yet — or a blank
tab, then navigate in.*

> **"Utility transformer failures cause blackouts costing over a million
> dollars an hour. Most utilities still run calendar-based maintenance —
> inspect every part on a fixed schedule — even though sensors already show
> failure signatures weeks in advance. The problem isn't the sensors. It's
> that sensor data, weather forecasts, and incident history live in three
> separate systems and never get combined in time to act. That's what we
> built: Grid Failure Advisor."**

### [0:20–0:55] Dashboard walkthrough

*Screen: navigate to `http://localhost:5173`, the dashboard loads.*

> **"This is the dashboard. Fifty grid assets — transformers and
> substations — every one of them scored 0 to 100 on predicted failure
> risk, ranked highest-risk first. You can filter by region or by tier."**

*Click the Region and Risk Tier filters once each to show they work, then
clear them.*

> **"Notice these aren't guesses — every score is computed live from real
> sensor readings, weather forecasts, and incident history."**

### [0:55–2:00] Asset detail — the core differentiator

*Click the top row (highest risk score — should be a Critical-tier asset).*

> **"Let's open the highest-risk asset. This is where it gets interesting."**

*Point to the risk score and tier badge at the top.*

> **"This asset scored [read the actual number] — Critical. But I don't
> want you to just trust a number. Here's why it scored that way."**

*Scroll to / point at the "Why This Score" panel.*

> **"Every single point is traced to a named factor. Twenty-five points
> because there's a storm forecast for this region this week. Eighteen
> points because partial discharge — a leading indicator of insulation
> breakdown — has risen sharply above this asset's own 15-day baseline.
> Eighteen more because oil quality is falling. This isn't a black box —
> it's fully explainable."**

*Scroll to the four sensor charts.*

> **"These are the actual sensor trends — temperature, vibration, partial
> discharge, oil quality — over the last 30 days. You can see the
> degradation happening in real time, weeks before this asset would
> actually fail."**

*Scroll to the weather panel, point at the highlighted storm day.*

> **"And here's the compounding risk — the actual weather forecast for this
> asset's region, with the storm day flagged. Sensor risk and weather risk,
> combined, automatically."**

### [2:00–2:40] Maintenance plan

*Click "Maintenance Plan" in the top nav.*

> **"All of that turns into action here. This is a prioritized, region-grouped
> maintenance and crew pre-positioning plan. Assets aren't just ranked by
> risk — they're ranked by risk times grid impact severity, so a
> transformer feeding a hospital outranks an equally risky asset serving a
> handful of houses."**

*Point at a "by [date]" deadline callout.*

> **"And notice the deadline — it's not some fixed 30-day window. It's
> pulled forward to land before this region's forecast storm. That's the
> weather-timing the problem statement asks for, actually implemented."**

### [2:40–3:30] Grid Copilot + IBM Bob / MCP integration

*Open the Copilot panel (top-right tab).*

> **"One more piece — the Grid Copilot. An operator can just ask a
> question."**

*Type and send: "which assets are highest risk near Eastgate?" (swap the
region name for whichever one is actually top-ranked in your run — check the
dashboard first) — wait for the answer.*

> **"That answer isn't generated by an LLM guessing — it's grounded in a
> real tool call to our backend, and you can see exactly which tool was
> called right here."**

*Click "Tools called" to expand it, point at the tool name.*

> **"And here's what makes our IBM Bob integration real, not just a
> mention in a README: that same tool is exposed through a standalone MCP
> server, so Bob — or any MCP client — can call it directly, completely
> independent of this web app, and get back the exact same numbers."**

*(Optional, if you're comfortable doing it live: switch to a terminal and run
the MCP verification command from `docs/architecture.md` to show it live. If
that feels risky to demo live, skip it — the explanation above is enough.)*

### [3:30–4:00] Close — impact

*Screen: back on the dashboard, or a static closing shot.*

> **"Grid Failure Advisor turns sensor data, weather forecasts, and incident
> history that already exist — but sit in separate systems — into one
> explainable, prioritized action plan, with a real IBM Bob integration
> that's load-bearing, not decorative. Thanks for watching."**

---

## After recording

1. Watch it back once — check audio is audible and nothing important got cut off.
2. Upload:
   - **Loom**: share → set to "Anyone with the link" → copy the link
   - **YouTube**: upload → set visibility to **Unlisted** (not Private) → copy the link
3. Put the real link in **`demo/demo-video-link.txt`** (replace the whole
   placeholder line — see `FINAL_SUBMISSION_NOTES.md` at the repo root for
   exactly how).
