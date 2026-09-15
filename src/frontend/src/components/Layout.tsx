import { NavLink, Outlet } from "react-router-dom";
import { CopilotPanel } from "./CopilotPanel";

const NAV_ITEMS = [
  { to: "/", label: "Dashboard", end: true },
  { to: "/maintenance-plan", label: "Maintenance Plan", end: false },
];

/** IBM-style 3×4 dot-grid logo mark */
function LogoMark() {
  return (
    <svg
      width="20"
      height="16"
      viewBox="0 0 20 16"
      fill="none"
      aria-hidden="true"
      className="shrink-0"
    >
      {[0, 1, 2].map((col) =>
        [0, 1, 2, 3].map((row) => (
          <rect
            key={`${col}-${row}`}
            x={col * 8}
            y={row * 4}
            width={5}
            height={2}
            rx={0.5}
            fill={col === 0 ? "#0f62fe" : "rgba(255,255,255,0.7)"}
          />
        )),
      )}
    </svg>
  );
}

export function Layout() {
  return (
    <div
      className="min-h-screen"
      style={{ backgroundColor: "var(--color-surface-base)" }}
    >
      {/* ── Header ─────────────────────────────────────────── */}
      <header
        className="sticky top-0 z-30"
        style={{
          backgroundColor: "hsl(220 15% 8%)",
          borderBottom: "1px solid var(--color-border-subtle)",
        }}
      >
        <div className="mx-auto flex h-14 max-w-7xl items-center justify-between px-4 md:px-8">
          {/* Brand */}
          <div className="flex items-center gap-3">
            <LogoMark />
            <span
              className="font-sans text-sm font-semibold tracking-wide"
              style={{ color: "var(--color-text-primary)" }}
            >
              Grid Failure Advisor
            </span>
          </div>

          {/* Nav */}
          <nav className="flex h-full items-center" aria-label="Main navigation">
            {NAV_ITEMS.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className={({ isActive }) =>
                  `flex h-full items-center px-5 font-sans text-sm font-medium transition-colors duration-150 border-b-2 ${
                    isActive
                      ? "border-[#0f62fe] text-white"
                      : "border-transparent hover:border-white/20 hover:text-white"
                  }`
                }
                style={({ isActive }) => ({
                  color: isActive ? "#fff" : "var(--color-text-secondary)",
                  backgroundColor: "transparent",
                })}
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
        </div>
      </header>

      {/* ── Main content ───────────────────────────────────── */}
      <main className="mx-auto max-w-7xl px-4 py-8 md:px-8">
        <Outlet />
      </main>

      <CopilotPanel />
    </div>
  );
}
