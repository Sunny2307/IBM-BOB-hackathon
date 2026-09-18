import { Link, NavLink, Outlet, useLocation } from "react-router-dom";
import { CopilotPanel } from "./CopilotPanel";
import { useAuth } from "../auth/AuthContext";

const PUBLIC_NAV = [
  { to: "/", label: "Dashboard", end: true },
  { to: "/maintenance-plan", label: "Maintenance Plan", end: false },
];

const OPERATOR_NAV = [{ to: "/alerts", label: "Alerts", end: false }];

const ADMIN_NAV = [
  { to: "/admin/users", label: "Team", end: false },
  { to: "/admin/assignments", label: "Coverage", end: false },
];

export function Layout() {
  const location = useLocation();
  const { session, isAdmin, signOut } = useAuth();

  // Navigation follows the role. The server enforces the same boundary
  // independently — these links are convenience, not access control.
  const navItems = [
    ...PUBLIC_NAV,
    ...(session ? OPERATOR_NAV : []),
    ...(isAdmin ? ADMIN_NAV : []),
  ];

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

          <nav className="flex flex-wrap items-baseline gap-6">
            {navItems.map((item) => (
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

            {session ? (
              <span className="flex items-baseline gap-3 border-l border-carbon-gray-20 pl-6">
                <span className="font-mono text-xs text-carbon-gray-60">
                  {session.full_name} · {session.role === "admin" ? "Admin" : "Field"}
                </span>
                <button
                  type="button"
                  onClick={() => signOut()}
                  className="border-b border-transparent py-1 font-sans text-sm tracking-wide text-carbon-gray-60 transition-colors hover:border-carbon-gray-30 hover:text-carbon-gray-100"
                >
                  Sign out
                </button>
              </span>
            ) : (
              <Link
                to="/login"
                className="border-b border-transparent py-1 font-sans text-sm tracking-wide text-carbon-gray-60 transition-colors hover:border-carbon-gray-30 hover:text-carbon-gray-100"
              >
                Sign in
              </Link>
            )}
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
