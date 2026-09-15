# Problem Statement

## Background

Electric utilities operate thousands of transformers and substations, each one
a single point of failure for the customers downstream of it. Grid reliability
depends on knowing, ahead of time, which assets are most likely to fail and
when — because the cost of finding out reactively is enormous: the US
military-scale analogy in the industry is blunt but accurate for utilities
too — a single major transformer or substation failure causes blackouts
costing **$1M+ per hour** and can strand tens of thousands of customers,
including hospitals and water treatment plants that cannot tolerate an
outage.

## The Problem

Most utilities still run **calendar-based maintenance**: a transformer gets
inspected or serviced every N years regardless of its actual condition. This
wastes money inspecting healthy assets on schedule, while assets that
degrade *between* scheduled inspections fail with no warning.

Meanwhile, the sensors already installed on modern grid equipment — measuring
**temperature, vibration, partial discharge, and oil quality** — routinely
show degradation signatures **weeks before failure**. Rising partial
discharge and falling oil quality are classic leading indicators of
insulation breakdown inside a transformer. That data exists. It is rarely
turned into a ranked, actionable decision in time to matter.

Separately, **weather forecasts** are a second, independent risk signal:
a heat wave pushes already-stressed equipment closer to its thermal limit; a
storm's wind and precipitation directly threaten already-weakened
transformers and substations. Utilities have this forecast data too. What
they don't have, in most cases, is a system that **combines** sensor
degradation and weather risk into a single view *before* the storm hits —
sensor data and weather forecasts today live in separate systems and are
almost never fused into one prioritized, time-boxed action list.

## Who is Affected

- **Grid operations / reliability engineers** at a utility, responsible for
  deciding which of hundreds or thousands of assets get inspected or
  serviced this week, with limited crew capacity and a limited maintenance
  budget.
- **Crew dispatch / field operations managers**, who need to know not just
  *which* asset is at risk but *by when* — so a crew can be pre-positioned
  ahead of a forecast storm instead of dispatched reactively after a call
  from an angry city council member.
- **Downstream customers**, disproportionately including critical loads like
  hospitals and water treatment facilities, whose outage risk is directly a
  function of how well this prioritization works.

## Why It Matters

- **Direct cost**: $1M+/hour in blackout costs for a major asset failure,
  before counting regulatory penalties, emergency repair premiums, and
  reputational damage.
- **Misallocated maintenance spend**: calendar-based maintenance spends
  money inspecting assets that don't need it while assets that do need it
  go unchecked between cycles — a classic Type I/Type II error problem with
  a $1M+/hour cost on the false-negative side.
- **Preventable outages become "unexpected" ones**: when the sensor
  signature was there weeks in advance and the storm was in the 7-day
  forecast, an outage that hits during severe weather is not a surprise —
  it is a coordination failure between data that already existed in two
  separate systems.

## Why Existing Solutions Fall Short

- **Calendar-based CMMS/maintenance systems** schedule by fixed interval, not
  by observed condition — they cannot see a transformer degrading ahead of
  its scheduled inspection date.
- **Condition-monitoring sensor platforms** typically surface raw
  sensor dashboards or simple threshold alarms per asset, without
  synthesizing multiple sensors into one explainable score, and without any
  connection to weather forecasts or a resulting action plan.
- **Weather-forecasting tools** are consumed separately by a different team
  (storm response / emergency operations) than the team monitoring asset
  condition, so the two risk signals are rarely combined into one
  prioritized decision before the event happens.
- **The gap is integration and explainability**, not sensing: the raw data
  utilities need already exists in three separate systems. Grid Failure
  Advisor's contribution is fusing them into one ranked, explainable,
  time-boxed action list — which is exactly what the problem statement asks
  for and what none of the point solutions above do on their own.
