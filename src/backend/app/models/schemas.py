"""Pydantic request/response models — the API contract shared by REST routes,
the MCP server tools, and (indirectly) the frontend TypeScript types."""

from typing import Optional, Literal
from pydantic import BaseModel, Field

RiskTier = Literal["Critical", "High", "Medium", "Low"]
AssetType = Literal["transformer", "substation"]


class Asset(BaseModel):
    asset_id: str
    name: str
    type: AssetType
    lat: float
    lon: float
    region: str
    install_year: int
    capacity_mva: float
    customers_served: int
    grid_impact_severity: int
    has_hospital_critical_load: bool
    has_water_treatment_load: bool
    has_redundancy: bool
    risk_score: float
    risk_tier: RiskTier


class SensorPoint(BaseModel):
    date: str
    temperature: float
    vibration: float
    partial_discharge: float
    oil_quality: float


class SensorSeries(BaseModel):
    temperature: list[dict]
    vibration: list[dict]
    partial_discharge: list[dict]
    oil_quality: list[dict]


class WeatherDay(BaseModel):
    date: str
    temp_high_f: float
    wind_speed_mph: float
    precip_probability: float
    storm_warning: bool


class WeatherContext(BaseModel):
    region: str
    forecast: list[WeatherDay]


class RiskComponent(BaseModel):
    factor: str
    contribution: float
    explanation: str


class RiskBreakdown(BaseModel):
    asset_id: str
    risk_score: float
    risk_tier: RiskTier
    components: list[RiskComponent]
    sensor_series: SensorSeries
    weather_context: WeatherContext


class MaintenancePlanItem(BaseModel):
    asset_id: str
    asset_name: str
    risk_score: float
    risk_tier: RiskTier
    priority_score: float
    recommended_action: str
    recommended_by_date: str
    rationale: str


class MaintenancePlanRegion(BaseModel):
    region: str
    weather_summary: str
    items: list[MaintenancePlanItem]


class MaintenancePlanResponse(BaseModel):
    generated_at: str
    regions: list[MaintenancePlanRegion]


class ToolCall(BaseModel):
    tool: str
    args: dict


class CopilotRequest(BaseModel):
    question: str = Field(min_length=1, max_length=500)


class CopilotResponse(BaseModel):
    answer: str
    tool_calls: list[ToolCall]
    data: dict
