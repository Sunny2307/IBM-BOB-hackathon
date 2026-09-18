import { useState, type FormEvent } from "react";
import { ApiError, createUser, getUsers } from "../api/client";
import { useAsyncData } from "../hooks/useAsyncData";
import { EmptyBlock, ErrorBlock, LoadingBlock } from "../components/StatusStates";
import type { OperatorUser, UserRole } from "../api/types";

const NO_USERS: OperatorUser[] = [];

export function AdminUsers() {
  const { data, loading, error, refetch } = useAsyncData(getUsers, () => NO_USERS, []);
  const users = data ?? NO_USERS;

  return (
    <div className="space-y-10">
      <div className="border-b border-carbon-gray-20 pb-6">
        <p className="kicker mb-2">Administration</p>
        <h1 className="font-serif text-4xl font-semibold tracking-tight text-carbon-gray-100">
          Team
        </h1>
        <p className="mt-3 font-serif text-base italic text-carbon-gray-70">
          Everyone who can sign in to this company, and what they are allowed to do.
        </p>
      </div>

      {loading && users.length === 0 && <LoadingBlock label="Loading team" />}
      {error && users.length === 0 && <ErrorBlock message={error} onRetry={refetch} />}
      {!loading && users.length === 0 && !error && (
        <EmptyBlock message="No users yet. Add the first crew member below." />
      )}

      {users.length > 0 && (
        <div className="border border-carbon-gray-20 bg-carbon-white">
          <table className="w-full border-collapse text-sm">
            <thead className="bg-carbon-gray-10/60">
              <tr className="text-left">
                <th className="kicker border-b border-carbon-gray-20 px-4 py-3">Name</th>
                <th className="kicker border-b border-carbon-gray-20 px-4 py-3">Email</th>
                <th className="kicker border-b border-carbon-gray-20 px-4 py-3">Role</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-carbon-gray-20">
              {users.map((user) => (
                <tr key={user.id}>
                  <td className="px-4 py-4 font-serif text-[15px] font-medium text-carbon-gray-100">
                    {user.full_name}
                  </td>
                  <td className="px-4 py-4 font-mono text-xs text-carbon-gray-70">{user.email}</td>
                  <td className="px-4 py-4">
                    <span
                      className={`border px-2 py-1 font-sans text-xs font-semibold ${
                        user.role === "admin"
                          ? "border-carbon-blue-60 text-carbon-blue-70"
                          : "border-carbon-gray-30 text-carbon-gray-70"
                      }`}
                    >
                      {user.role === "admin" ? "Administrator" : "Field crew"}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <CreateUserForm onCreated={refetch} />
    </div>
  );
}

function CreateUserForm({ onCreated }: { onCreated: () => void }) {
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<UserRole>("field");
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setFailure(null);
    try {
      await createUser({ email, full_name: fullName, password, role });
      setFullName("");
      setEmail("");
      setPassword("");
      onCreated();
    } catch (err) {
      setFailure(err instanceof ApiError ? err.message : "Could not create the user.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="border-t border-carbon-gray-20 pt-8">
      <p className="kicker mb-4">Add a team member</p>
      <form onSubmit={handleSubmit} className="grid gap-4 sm:grid-cols-2">
        <Field label="Full name" value={fullName} onChange={setFullName} required />
        <Field label="Work email" value={email} onChange={setEmail} type="email" required />
        {/* The backend enforces 10 characters too; stating it here avoids a
            pointless round trip. */}
        <Field
          label="Temporary password (10+ characters)"
          value={password}
          onChange={setPassword}
          type="password"
          minLength={10}
          required
        />
        <label className="block">
          <span className="kicker">Role</span>
          <select
            value={role}
            onChange={(e) => setRole(e.target.value as UserRole)}
            className="mt-2 w-full border border-carbon-gray-20 bg-carbon-white px-3 py-3 font-sans text-sm text-carbon-gray-100 focus:border-carbon-blue-60 focus:outline-none"
          >
            <option value="field">Field crew</option>
            <option value="admin">Administrator</option>
          </select>
        </label>

        {failure && (
          <p className="sm:col-span-2 font-sans text-sm text-risk-critical">{failure}</p>
        )}

        <div className="sm:col-span-2">
          <button
            type="submit"
            disabled={busy}
            className="bg-carbon-gray-100 px-6 py-3 font-sans text-sm font-semibold tracking-wide text-carbon-white transition-colors hover:bg-carbon-blue-70 disabled:opacity-50"
          >
            {busy ? "Creating…" : "Create account"}
          </button>
        </div>
      </form>
    </section>
  );
}

interface FieldProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
  required?: boolean;
  minLength?: number;
}

function Field({ label, value, onChange, type = "text", required, minLength }: FieldProps) {
  return (
    <label className="block">
      <span className="kicker">{label}</span>
      <input
        type={type}
        value={value}
        required={required}
        minLength={minLength}
        onChange={(e) => onChange(e.target.value)}
        className="mt-2 w-full border border-carbon-gray-20 bg-carbon-white px-3 py-3 font-sans text-sm text-carbon-gray-100 focus:border-carbon-blue-60 focus:outline-none"
      />
    </label>
  );
}
