import { NavLink, Outlet } from "react-router-dom";
import { CopilotPanel } from "./CopilotPanel";

const NAV_ITEMS = [
  { to: "/", label: "Dashboard", end: true },
  { to: "/maintenance-plan", label: "Maintenance Plan", end: false },
];

export function Layout() {
  return (
    <div className="min-h-screen bg-console-950">
      <header className="sticky top-0 z-30 border-b border-console-700 bg-console-900">
        <div className="flex h-14 items-center justify-between px-4 md:px-8">
          <div className="flex items-center gap-3">
            <span className="h-2.5 w-2.5 shrink-0 bg-signal" aria-hidden />
            <span className="font-mono text-sm font-bold tracking-[0.15em] text-slate-100 uppercase">
              Grid Failure Advisor
            </span>
            <span className="hidden font-mono text-xs text-slate-500 sm:inline">
              / control console
            </span>
          </div>

          <nav className="flex items-center gap-1">
            {NAV_ITEMS.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className={({ isActive }) =>
                  `border px-3 py-1.5 font-mono text-xs tracking-wide uppercase transition-colors ${
                    isActive
                      ? "border-signal/60 bg-signal/10 text-signal"
                      : "border-transparent text-slate-400 hover:border-console-600 hover:text-slate-100"
                  }`
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-6 md:px-8 md:py-8">
        <Outlet />
      </main>

      <CopilotPanel />
    </div>
  );
}
