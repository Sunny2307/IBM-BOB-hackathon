// Types mirror the real FastAPI backend contract exactly (app/models/schemas.py).
// Reconciled against the live backend after both sides were built in parallel —
// see README "API contract" for notes on the reconciliation.

export type RiskTier = "Critical" | "High" | "Medium" | "Low";
export type AssetType = "transformer" | "substation";

export interface Asset {
  asset_id: string;
  name: string;
  type: AssetType;
  lat: number;
  lon: number;
  region: string;
  install_year: number;
  capacity_mva: number;
  customers_served: number;
  grid_impact_severity: number;
  has_hospital_critical_load: boolean;
  has_water_treatment_load: boolean;
  has_redundancy: boolean;
  risk_score: number;
  risk_tier: RiskTier;
}

export interface RiskComponent {
  factor: string;
  contribution: number;
  explanation: string;
}

export interface SensorReading {
  date: string;
  value: number;
}

export interface SensorSeries {
  temperature: SensorReading[];
  vibration: SensorReading[];
  partial_discharge: SensorReading[];
  oil_quality: SensorReading[];
}

export interface DailyForecast {
  date: string;
  temp_high_f: number;
  wind_speed_mph: number;
  precip_probability: number;
  storm_warning: boolean;
}

export interface WeatherContext {
  region: string;
  forecast: DailyForecast[];
}

export interface RiskBreakdown {
  asset_id: string;
  risk_score: number;
  risk_tier: RiskTier;
  components: RiskComponent[];
  sensor_series: SensorSeries;
  weather_context: WeatherContext;
}

export interface MaintenanceItem {
  asset_id: string;
  asset_name: string;
  risk_score: number;
  risk_tier: RiskTier;
  priority_score: number;
  recommended_action: string;
  recommended_by_date: string;
  rationale: string;
}

export interface RegionPlan {
  region: string;
  weather_summary: string;
  items: MaintenanceItem[];
}

export interface MaintenancePlan {
  generated_at: string;
  regions: RegionPlan[];
}

export interface ToolCall {
  tool: string;
  args: Record<string, unknown>;
}

export interface CopilotResponse {
  answer: string;
  tool_calls: ToolCall[];
  data: Record<string, unknown>;
}

export interface ChatTurn {
  question: string;
  answer: string;
  tool_calls: ToolCall[];
}

/** Conversation history shape sent to the LLM-backed /copilot/ask endpoint. */
export interface CopilotHistoryTurn {
  role: "user" | "assistant";
  content: string;
}

/** GET /health — also reports which weather feed the risk model is running on. */
export interface Health {
  status: string;
  last_updated: string | null;
  weather_source: string;
}

// ---------------------------------------------------------------------------
// Operator layer — companies, users, assignments, alerts.
// Mirrors the operator models in src/backend/app/models/schemas.py.
// ---------------------------------------------------------------------------

export type UserRole = "admin" | "field";
export type AlertStatus = "open" | "acknowledged" | "resolved";
export type AlertTier = "High" | "Critical";

/** POST /auth/login — identity plus the bearer token. */
export interface AuthSession {
  access_token: string;
  token_type: string;
  user_id: number;
  email: string;
  full_name: string;
  role: UserRole;
  company_id: number;
  company_name: string;
}

/** One raised alert: an asset crossed up into High or Critical. */
export interface Alert {
  id: number;
  asset_id: string;
  asset_name: string;
  region: string;
  tier: AlertTier;
  previous_tier: string | null;
  risk_score: number;
  headline: string;
  status: AlertStatus;
  raised_at: string;
  acknowledged_by_name: string | null;
  acknowledged_at: string | null;
}

export interface AlertInbox {
  count: number;
  /** e.g. "assets assigned to you" or "all company alerts (admin)". */
  scope: string;
  alerts: Alert[];
}

export interface OperatorUser {
  id: number;
  email: string;
  full_name: string;
  role: UserRole;
  is_active: boolean;
}

/** One asset an alert to a given user could actually land on. */
export interface AssignableAsset {
  asset_id: string;
  name: string;
  region: string;
  risk_score: number;
  risk_tier: RiskTier;
}

/** Result of an admin raising an alert for a named person. */
export interface SentAlert {
  alert: Alert;
  notified: string;
}

export interface Assignment {
  id: number;
  user_id: number;
  user_name: string;
  /** "region" | "asset" */
  scope_type: string;
  scope_value: string;
}
