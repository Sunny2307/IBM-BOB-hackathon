import { NavLink, Outlet } from "react-router-dom";
import { CopilotPanel } from "./CopilotPanel";

const NAV_ITEMS = [
  { to: "/", label: "Dashboard", end: true },
  { to: "/maintenance-plan", label: "Maintenance Plan", end: false },
];

export function Layout() {
  return (
    <div className="min-h-screen bg-carbon-gray-10">
      {/* Carbon UI Shell Header (always dark) */}
      <header className="sticky top-0 z-30 bg-carbon-gray-100 border-b border-carbon-gray-90">
        <div className="flex h-12 items-center justify-between px-4">
          <div className="flex items-center gap-3">
            {/* Minimalist IBM-style logo mark */}
            <span className="h-3 w-3 shrink-0 bg-carbon-blue-60" aria-hidden />
            <span className="font-sans text-sm font-semibold tracking-wide text-carbon-white">
              Grid Failure Advisor
            </span>
          </div>

          <nav className="flex h-full items-center">
            {NAV_ITEMS.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className={({ isActive }) =>
                  `flex h-full items-center px-4 font-sans text-sm transition-colors ${
                    isActive
                      ? "border-b-2 border-carbon-blue-60 text-carbon-white bg-carbon-gray-90"
                      : "border-b-2 border-transparent text-carbon-gray-30 hover:text-carbon-white hover:bg-carbon-gray-90"
                  }`
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-8 md:px-8">
        <Outlet />
      </main>

      <CopilotPanel />
    </div>
  );
}
