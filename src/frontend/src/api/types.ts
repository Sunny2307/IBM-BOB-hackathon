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
