import { useState, type FormEvent } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";

export function Login() {
  const { session, isAdmin, signIn, isSigningIn, error } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  if (session) return <Navigate to={isAdmin ? "/admin/users" : "/alerts"} replace />;

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    if (await signIn(email, password)) navigate("/alerts", { replace: true });
  }

  return (
    <div className="mx-auto max-w-md">
      <p className="kicker mb-2">Operator sign-in</p>
      <h1 className="font-serif text-4xl font-semibold tracking-tight text-carbon-gray-100">
        Sign in
      </h1>
      <p className="mt-3 font-serif text-base italic text-carbon-gray-70">
        Sign in to see the alerts raised on the assets you are responsible for.
      </p>

      <form onSubmit={handleSubmit} className="mt-10 space-y-6 border-t border-carbon-gray-20 pt-8">
        <label className="block">
          <span className="kicker">Email</span>
          <input
            type="email"
            required
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@utility.example"
            className="mt-2 w-full border border-carbon-gray-20 bg-carbon-white px-3 py-3 font-sans text-sm text-carbon-gray-100 focus:border-carbon-blue-60 focus:outline-none"
          />
        </label>

        <label className="block">
          <span className="kicker">Password</span>
          <input
            type="password"
            required
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-2 w-full border border-carbon-gray-20 bg-carbon-white px-3 py-3 font-sans text-sm text-carbon-gray-100 focus:border-carbon-blue-60 focus:outline-none"
          />
        </label>

        {error && (
          <p className="border-l-2 border-risk-critical bg-risk-critical/5 px-4 py-3 font-sans text-sm text-carbon-gray-90">
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={isSigningIn}
          className="w-full bg-carbon-gray-100 px-4 py-3 font-sans text-sm font-semibold tracking-wide text-carbon-white transition-colors hover:bg-carbon-blue-70 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isSigningIn ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </div>
  );
}
