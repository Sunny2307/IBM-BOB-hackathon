// Local fallback data — used ONLY when the real API is unreachable, so the UI
// stays demo-able if the backend isn't running. Not a source of truth; field
// shapes match app/models/schemas.py exactly.
import type {
  Asset,
  CopilotResponse,
  MaintenancePlan,
  RiskBreakdown,
} from "./types";

export const MOCK_ASSETS: Asset[] = [
  {
    asset_id: "AST-014",
    name: "North Valley Transformer 03",
    type: "transformer",
    lat: 37.9,
    lon: -121.3,
    region: "North Valley",
    install_year: 1998,
    capacity_mva: 50,
    customers_served: 8200,
    grid_impact_severity: 9,
    has_hospital_critical_load: true,
    has_water_treatment_load: false,
    has_redundancy: false,
    risk_score: 91,
    risk_tier: "Critical",
  },
  {
    asset_id: "AST-208",
    name: "Riverside Substation 02",
    type: "substation",
    lat: 33.95,
    lon: -117.4,
    region: "Riverside",
    install_year: 2006,
    capacity_mva: 90,
    customers_served: 3400,
    grid_impact_severity: 6,
    has_hospital_critical_load: false,
    has_water_treatment_load: false,
    has_redundancy: true,
    risk_score: 74,
    risk_tier: "High",
  },
  {
    asset_id: "AST-091",
    name: "North Valley Transformer 07",
    type: "transformer",
    lat: 37.88,
    lon: -121.25,
    region: "North Valley",
    install_year: 2015,
    capacity_mva: 10,
    customers_served: 1100,
    grid_impact_severity: 4,
    has_hospital_critical_load: false,
    has_water_treatment_load: false,
    has_redundancy: true,
    risk_score: 48,
    risk_tier: "Medium",
  },
  {
    asset_id: "AST-330",
    name: "Highland Substation 01",
    type: "substation",
    lat: 39.7,
    lon: -104.9,
    region: "Highland",
    install_year: 2019,
    capacity_mva: 138,
    customers_served: 6500,
    grid_impact_severity: 7,
    has_hospital_critical_load: false,
    has_water_treatment_load: true,
    has_redundancy: true,
    risk_score: 22,
    risk_tier: "Low",
  },
  {
    asset_id: "AST-142",
    name: "Riverside Transformer 05",
    type: "transformer",
    lat: 33.99,
    lon: -117.35,
    region: "Riverside",
    install_year: 2001,
    capacity_mva: 75,
    customers_served: 12400,
    grid_impact_severity: 9,
    has_hospital_critical_load: false,
    has_water_treatment_load: false,
    has_redundancy: false,
    risk_score: 88,
    risk_tier: "Critical",
  },
];

function series(base: number, drift: number, days = 30): { date: string; value: number }[] {
  return Array.from({ length: days }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - (days - i));
    return {
      date: d.toISOString().slice(0, 10),
      value: Math.round((base + (drift * i) / days + Math.sin(i) * 1.5) * 10) / 10,
    };
  });
}

export const MOCK_RISK_BREAKDOWN: RiskBreakdown = {
  asset_id: "AST-014",
  risk_score: 91,
  risk_tier: "Critical",
  components: [
    {
      factor: "Sensor Anomaly — Oil Quality",
      contribution: 18,
      explanation:
        "Oil quality has fallen 34% versus its 15-day baseline, consistent with developing equipment stress.",
    },
    {
      factor: "Sensor Anomaly — Partial Discharge",
      contribution: 18,
      explanation:
        "Partial discharge has risen 58% versus its 15-day baseline, consistent with developing equipment stress.",
    },
    {
      factor: "Weather Risk",
      contribution: 25,
      explanation:
        "Storm warning forecast for North Valley within 5 days — compounds any existing equipment stress in this region.",
    },
    {
      factor: "Historical Incident Rate",
      contribution: 16.5,
      explanation:
        "Transformers of similar age (28 yrs, 'old' bracket) show 8 historical incidents in the record.",
    },
    {
      factor: "Sensor Anomaly — Vibration",
      contribution: 8.5,
      explanation: "Vibration has risen 42% versus its 15-day baseline.",
    },
    {
      factor: "Sensor Anomaly — Temperature",
      contribution: 5.0,
      explanation: "Temperature shows a mild deviation from baseline; worth monitoring.",
    },
    {
      factor: "Baseline Operational Risk",
      contribution: 5.0,
      explanation: "Fixed floor reflecting that any energized grid asset carries nonzero risk.",
    },
  ],
  sensor_series: {
    temperature: series(62, 8),
    vibration: series(2.1, 0.9),
    partial_discharge: series(80, 45),
    oil_quality: series(78, -30),
  },
  weather_context: {
    region: "North Valley",
    forecast: Array.from({ length: 7 }, (_, i) => {
      const d = new Date();
      d.setDate(d.getDate() + i);
      return {
        date: d.toISOString().slice(0, 10),
        temp_high_f: 75 + i,
        wind_speed_mph: 12 + i * 6,
        precip_probability: Math.min(0.9, i * 0.15),
        storm_warning: i === 4,
      };
    }),
  },
};

export const MOCK_MAINTENANCE_PLAN: MaintenancePlan = {
  generated_at: new Date().toISOString().slice(0, 10),
  regions: [
    {
      region: "North Valley",
      weather_summary: "Storm warning in 5 days — high wind and precipitation risk.",
      items: [
        {
          asset_id: "AST-014",
          asset_name: "North Valley Transformer 03",
          risk_score: 91,
          risk_tier: "Critical",
          priority_score: 819,
          recommended_action: "Dispatch crew for emergency inspection now; pre-stage replacement parts/transformer.",
          recommended_by_date: new Date(Date.now() + 4 * 86400000).toISOString().slice(0, 10),
          rationale: "Risk score 91 (Critical) x grid impact severity 9/10; pre-positioned ahead of the storm warning.",
        },
        {
          asset_id: "AST-091",
          asset_name: "North Valley Transformer 07",
          risk_score: 48,
          risk_tier: "Medium",
          priority_score: 192,
          recommended_action: "Schedule inspection in the next routine maintenance window.",
          recommended_by_date: new Date(Date.now() + 21 * 86400000).toISOString().slice(0, 10),
          rationale: "Risk score 48 (Medium) x grid impact severity 4/10; standard response window.",
        },
      ],
    },
    {
      region: "Riverside",
      weather_summary: "No severe weather in the 7-day forecast.",
      items: [
        {
          asset_id: "AST-142",
          asset_name: "Riverside Transformer 05",
          risk_score: 88,
          risk_tier: "Critical",
          priority_score: 792,
          recommended_action: "Dispatch crew for emergency inspection now; pre-stage replacement parts/transformer.",
          recommended_by_date: new Date(Date.now() + 3 * 86400000).toISOString().slice(0, 10),
          rationale: "Risk score 88 (Critical) x grid impact severity 9/10; high customer impact if failure occurs.",
        },
        {
          asset_id: "AST-208",
          asset_name: "Riverside Substation 02",
          risk_score: 74,
          risk_tier: "High",
          priority_score: 444,
          recommended_action: "Schedule priority inspection within days; order replacement parts if degradation confirmed.",
          recommended_by_date: new Date(Date.now() + 10 * 86400000).toISOString().slice(0, 10),
          rationale: "Risk score 74 (High) x grid impact severity 6/10.",
        },
      ],
    },
  ],
};

export function getMockAsset(id: string): Asset {
  return MOCK_ASSETS.find((a) => a.asset_id === id) ?? { ...MOCK_ASSETS[0], asset_id: id };
}

export function getMockRiskBreakdown(id: string): RiskBreakdown {
  return { ...MOCK_RISK_BREAKDOWN, asset_id: id };
}

export const MOCK_COPILOT_RESPONSE: CopilotResponse = {
  answer:
    "Top 2 highest-risk assets: North Valley Transformer 03 — Critical (score 91/100, North Valley), Riverside Transformer 05 — Critical (score 88/100, Riverside).",
  tool_calls: [{ tool: "get_at_risk_assets", args: { region: null, min_tier: "High", limit: 5 } }],
  data: { count: 2 },
};
