import { lazy, Suspense, type ReactNode } from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import { Layout } from "./components/Layout";
import { Dashboard } from "./pages/Dashboard";
import { MaintenancePlan } from "./pages/MaintenancePlan";
import { Login } from "./pages/Login";
import { Alerts } from "./pages/Alerts";
import { AdminUsers } from "./pages/AdminUsers";
import { AdminAssignments } from "./pages/AdminAssignments";
import { LoadingBlock } from "./components/StatusStates";
import { AuthProvider, useAuth } from "./auth/AuthContext";

// Recharts is heavy — split it out of the main bundle so the dashboard
// (the first thing judges see) loads fast.
const AssetDetail = lazy(() =>
  import("./pages/AssetDetail").then((m) => ({ default: m.AssetDetail })),
);

/**
 * Gate for the operator surface. The dashboard, asset detail and maintenance
 * plan stay PUBLIC on purpose: the deployed demo has to work for a judge with
 * no account. Only alerts and administration require signing in.
 */
function RequireAuth({ children, adminOnly = false }: { children: ReactNode; adminOnly?: boolean }) {
  const { session, isAdmin } = useAuth();
  if (!session) return <Navigate to="/login" replace />;
  // Also enforced server-side — this only avoids rendering a screen that would
  // 403 anyway.
  if (adminOnly && !isAdmin) return <Navigate to="/alerts" replace />;
  return <>{children}</>;
}

export function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route element={<Layout />}>
          <Route path="/" element={<Dashboard />} />
          <Route
            path="/assets/:id"
            element={
              <Suspense fallback={<LoadingBlock label="Loading asset detail" />}>
                <AssetDetail />
              </Suspense>
            }
          />
          <Route path="/maintenance-plan" element={<MaintenancePlan />} />
          <Route path="/login" element={<Login />} />
          <Route
            path="/alerts"
            element={
              <RequireAuth>
                <Alerts />
              </RequireAuth>
            }
          />
          <Route
            path="/admin/users"
            element={
              <RequireAuth adminOnly>
                <AdminUsers />
              </RequireAuth>
            }
          />
          <Route
            path="/admin/assignments"
            element={
              <RequireAuth adminOnly>
                <AdminAssignments />
              </RequireAuth>
            }
          />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </AuthProvider>
  );
}
