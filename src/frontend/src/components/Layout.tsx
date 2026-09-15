import { NavLink, Outlet, useLocation } from "react-router-dom";
import { CopilotPanel } from "./CopilotPanel";

const NAV_ITEMS = [
  { to: "/", label: "Dashboard", end: true },
  { to: "/maintenance-plan", label: "Maintenance Plan", end: false },
];

export function Layout() {
  const location = useLocation();

  return (
    <div className="min-h-screen bg-carbon-gray-10">
      {/* Editorial masthead — paper background, serif wordmark, hairline rule */}
      <header className="sticky top-0 z-30 border-b border-carbon-gray-20 bg-carbon-white">
        <div className="mx-auto flex max-w-6xl flex-wrap items-baseline justify-between gap-x-8 gap-y-2 px-6 py-5 md:px-10">
          <div className="flex items-baseline gap-3">
            <h1 className="font-serif text-[22px] font-semibold tracking-tight text-carbon-gray-100">
              Grid Failure Advisor
            </h1>
            <span className="kicker hidden sm:inline">Outage Prediction &amp; Maintenance Planning</span>
          </div>

          <nav className="flex items-baseline gap-6">
            {NAV_ITEMS.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className={({ isActive }) =>
                  `border-b py-1 font-sans text-sm tracking-wide transition-colors ${
                    isActive
                      ? "border-carbon-gray-100 text-carbon-gray-100"
                      : "border-transparent text-carbon-gray-60 hover:border-carbon-gray-30 hover:text-carbon-gray-100"
                  }`
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-6 py-10 md:px-10 md:py-14">
        <div key={location.pathname} className="page-transition">
          <Outlet />
        </div>
      </main>

      <footer className="mx-auto max-w-6xl border-t border-carbon-gray-20 px-6 py-8 md:px-10">
        <p className="kicker">Grid Failure Advisor — IBM BoB AI Innovation Hackathon 2026</p>
      </footer>

      <CopilotPanel />
    </div>
  );
}
