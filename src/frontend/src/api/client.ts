import type {
  Asset,
  CopilotResponse,
  MaintenancePlan,
  RiskBreakdown,
} from "./types";

const BASE_URL: string =
  import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";

export class ApiError extends Error {
  status?: number;

  constructor(message: string, status?: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let response: Response;

  try {
    response = await fetch(`${BASE_URL}${path}`, {
      headers: { "Content-Type": "application/json" },
      ...init,
    });
  } catch {
    throw new ApiError(`Could not reach API at ${BASE_URL}${path}`);
  }

  if (!response.ok) {
    throw new ApiError(
      `${response.status} ${response.statusText} on ${path}`,
      response.status,
    );
  }

  return response.json() as Promise<T>;
}

export function getAssets(): Promise<Asset[]> {
  return request<Asset[]>("/assets");
}

export function getAsset(id: string): Promise<Asset> {
  return request<Asset>(`/assets/${id}`);
}

export function getRiskBreakdown(id: string): Promise<RiskBreakdown> {
  return request<RiskBreakdown>(`/assets/${id}/risk-breakdown`);
}

export function getMaintenancePlan(): Promise<MaintenancePlan> {
  return request<MaintenancePlan>("/maintenance-plan");
}

export function askCopilot(question: string): Promise<CopilotResponse> {
  return request<CopilotResponse>("/copilot/ask", {
    method: "POST",
    body: JSON.stringify({ question }),
  });
}
