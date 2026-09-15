import { lazy, Suspense } from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import { Layout } from "./components/Layout";
import { Dashboard } from "./pages/Dashboard";
import { MaintenancePlan } from "./pages/MaintenancePlan";
import { LoadingBlock } from "./components/StatusStates";

// Recharts is heavy — split it out of the main bundle so the dashboard
// (the first thing judges see) loads fast.
const AssetDetail = lazy(() =>
  import("./pages/AssetDetail").then((m) => ({ default: m.AssetDetail })),
);

export function App() {
  return (
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
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
