import type {
  Alert,
  AlertInbox,
  AssignableAsset,
  Assignment,
  Asset,
  AuthSession,
  Health,
  OperatorUser,
  UserRole,
  CopilotHistoryTurn,
  CopilotResponse,
  MaintenancePlan,
  RiskBreakdown,
  SentAlert,
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

/**
 * Bearer token for the operator endpoints. Held here rather than threaded
 * through every call so a caller cannot forget it, and so there is exactly one
 * place that knows a session exists. Set by AuthProvider on sign-in.
 */
let authToken: string | null = null;

/** Invoked on a 401 so the app can drop to the login screen rather than
 * silently showing an empty inbox. */
let onUnauthorized: (() => void) | null = null;

export function setAuthToken(token: string | null) {
  authToken = token;
}

export function setUnauthorizedHandler(handler: (() => void) | null) {
  onUnauthorized = handler;
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let response: Response;

  const headers: Record<string, string> = { "Content-Type": "application/json" };
  // The copilot takes the token when one exists (it unlocks the operator
  // tools) but works fine without it, so this is unconditional rather than
  // opt-in per call.
  if (authToken) headers.Authorization = `Bearer ${authToken}`;

  try {
    response = await fetch(`${BASE_URL}${path}`, {
      ...init,
      headers: { ...headers, ...(init?.headers as Record<string, string>) },
    });
  } catch {
    throw new ApiError(`Could not reach API at ${BASE_URL}${path}`);
  }

  if (response.status === 401) {
    authToken = null;
    onUnauthorized?.();
    throw new ApiError("Your session has expired. Please sign in again.", 401);
  }

  if (!response.ok) {
    throw new ApiError(await errorMessage(response, path), response.status);
  }

  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

/** FastAPI puts the useful sentence in `detail`; showing "409" to someone who
 * typed a duplicate email is useless. */
async function errorMessage(response: Response, path: string): Promise<string> {
  try {
    const body = await response.json();
    if (body && typeof body.detail === "string") return body.detail;
  } catch {
    // fall through
  }
  return `${response.status} ${response.statusText} on ${path}`;
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

export function getHealth(): Promise<Health> {
  return request<Health>("/health");
}

export function getMaintenancePlan(): Promise<MaintenancePlan> {
  return request<MaintenancePlan>("/maintenance-plan");
}

// ------------------------------------------------------------------ operator

export function login(email: string, password: string): Promise<AuthSession> {
  return request<AuthSession>("/auth/login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
}

export function getMyAlerts(status = "active"): Promise<AlertInbox> {
  return request<AlertInbox>(`/alerts/mine?status=${status}`);
}

export function acknowledgeAlert(alertId: number): Promise<Alert> {
  return request<Alert>(`/alerts/${alertId}/ack`, { method: "POST" });
}

export function getUsers(): Promise<OperatorUser[]> {
  return request<OperatorUser[]>("/admin/users");
}

export function createUser(body: {
  email: string;
  full_name: string;
  password: string;
  role: UserRole;
}): Promise<OperatorUser> {
  return request<OperatorUser>("/admin/users", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

export function getAssignments(): Promise<Assignment[]> {
  return request<Assignment[]>("/admin/assignments");
}

export function createAssignment(body: {
  user_id: number;
  scope_value: string;
  scope_type?: string;
}): Promise<Assignment> {
  return request<Assignment>("/admin/assignments", {
    method: "POST",
    body: JSON.stringify({ scope_type: "region", ...body }),
  });
}

export function deleteAssignment(assignmentId: number): Promise<void> {
  return request<void>(`/admin/assignments/${assignmentId}`, { method: "DELETE" });
}

/** The assets an alert to this user could reach. Empty = no assignments yet. */
export function getAssignableAssets(userId: number): Promise<AssignableAsset[]> {
  return request<AssignableAsset[]>(`/admin/users/${userId}/assignable-assets`);
}

/**
 * Raises a real alert so a named person is notified now, rather than waiting
 * for an asset to cross tiers on its own. Omitting `asset_id` lets the server
 * pick the highest-risk asset inside that user's scope.
 */
export function sendAlert(body: {
  user_id: number;
  asset_id?: string;
}): Promise<SentAlert> {
  return request<SentAlert>("/admin/alerts/send", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

export function askCopilot(
  question: string,
  history: CopilotHistoryTurn[] = [],
): Promise<CopilotResponse> {
  return request<CopilotResponse>("/copilot/ask", {
    method: "POST",
    body: JSON.stringify({ question, history }),
  });
}
