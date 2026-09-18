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


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=2000)


class CopilotRequest(BaseModel):
    question: str = Field(min_length=1, max_length=500)
    history: list[ChatMessage] = Field(default_factory=list, max_length=20)


class CopilotResponse(BaseModel):
    answer: str
    tool_calls: list[ToolCall]
    data: dict


# ---------------------------------------------------------------------------
# Operator layer — companies, users, assignments, alerts.
#
# These describe the PEOPLE side of the system, which lives in Postgres. The
# asset/sensor/risk models above stay in memory; the two halves join on the
# asset_id string.
# ---------------------------------------------------------------------------

UserRole = Literal["admin", "field"]
ScopeType = Literal["region", "asset"]
AlertStatus = Literal["open", "acknowledged", "resolved"]
AlertTier = Literal["High", "Critical"]


class LoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=1, max_length=256)


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    email: str
    full_name: str
    role: UserRole
    company_id: int
    company_name: str


class UserOut(BaseModel):
    id: int
    email: str
    full_name: str
    role: UserRole
    is_active: bool


class CreateUserRequest(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    full_name: str = Field(min_length=1, max_length=120)
    # 10 is above the 8-character folklore minimum and costs nothing to ask for
    # on accounts an admin creates for a crew.
    password: str = Field(min_length=10, max_length=256)
    role: UserRole = "field"


class AssignmentOut(BaseModel):
    id: int
    user_id: int
    user_name: str
    scope_type: ScopeType
    scope_value: str


class CreateAssignmentRequest(BaseModel):
    user_id: int
    scope_type: ScopeType = "region"
    scope_value: str = Field(min_length=1, max_length=120)


class AlertOut(BaseModel):
    id: int
    asset_id: str
    asset_name: str
    region: str
    tier: AlertTier
    previous_tier: Optional[str] = None
    risk_score: float
    headline: str
    status: AlertStatus
    raised_at: str
    acknowledged_by_name: Optional[str] = None
    acknowledged_at: Optional[str] = None
