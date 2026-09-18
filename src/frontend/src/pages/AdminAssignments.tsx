import { useMemo, useState } from "react";
import {
  ApiError,
  createAssignment,
  deleteAssignment,
  getAssets,
  getAssignments,
  getUsers,
} from "../api/client";
import { useAsyncData } from "../hooks/useAsyncData";
import { EmptyBlock, ErrorBlock, LoadingBlock } from "../components/StatusStates";
import type { Assignment, OperatorUser } from "../api/types";

const NO_ASSIGNMENTS: Assignment[] = [];
const NO_USERS: OperatorUser[] = [];

/**
 * The screen that makes alerts mean anything. Until a region has an owner, an
 * alert raised in it reaches nobody — so unassigned regions lead the page
 * rather than being buried under the existing rows.
 */
export function AdminAssignments() {
  const assignments = useAsyncData(getAssignments, () => NO_ASSIGNMENTS, []);
  const users = useAsyncData(getUsers, () => NO_USERS, []);
  // Regions come from the live asset list, so this always offers exactly the
  // regions the risk engine reports on — no hardcoded list to drift.
  const regions = useAsyncData(
    async () => Array.from(new Set((await getAssets()).map((a) => a.region))).sort(),
    () => [] as string[],
    [],
  );

  const [failure, setFailure] = useState<string | null>(null);

  const rows = assignments.data ?? NO_ASSIGNMENTS;
  const covered = useMemo(() => new Set(rows.map((r) => r.scope_value)), [rows]);
  const uncovered = (regions.data ?? []).filter((r) => !covered.has(r));

  async function assign(region: string, userId: number) {
    setFailure(null);
    try {
      await createAssignment({ user_id: userId, scope_value: region });
      assignments.refetch();
    } catch (err) {
      setFailure(err instanceof ApiError ? err.message : "Could not assign.");
    }
  }

  async function remove(assignmentId: number) {
    setFailure(null);
    try {
      await deleteAssignment(assignmentId);
      assignments.refetch();
    } catch (err) {
      setFailure(err instanceof ApiError ? err.message : "Could not remove.");
    }
  }

  return (
    <div className="space-y-10">
      <div className="border-b border-carbon-gray-20 pb-6">
        <p className="kicker mb-2">Administration</p>
        <h1 className="font-serif text-4xl font-semibold tracking-tight text-carbon-gray-100">
          Coverage
        </h1>
        <p className="mt-3 font-serif text-base italic text-carbon-gray-70">
          An alert only reaches someone if their region is assigned. Unassigned regions
          raise alerts nobody receives.
        </p>
      </div>

      {failure && <ErrorBlock message={failure} />}

      {uncovered.length > 0 && (
        <section>
          <p className="kicker mb-4 text-risk-critical">Nobody assigned — {uncovered.length}</p>
          <ul className="space-y-3">
            {uncovered.map((region) => (
              <li
                key={region}
                className="flex flex-wrap items-center gap-4 border-l-2 border-risk-critical bg-risk-critical/5 px-4 py-3"
              >
                <span className="font-serif text-base font-semibold text-carbon-gray-100">
                  {region}
                </span>
                <select
                  defaultValue=""
                  onChange={(e) => e.target.value && assign(region, Number(e.target.value))}
                  className="ml-auto border border-carbon-gray-30 bg-carbon-white px-2 py-2 font-sans text-sm"
                >
                  <option value="" disabled>
                    Assign to…
                  </option>
                  {(users.data ?? NO_USERS).map((user) => (
                    <option key={user.id} value={user.id}>
                      {user.full_name}
                    </option>
                  ))}
                </select>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section>
        <p className="kicker mb-4">Assigned — {rows.length}</p>
        {assignments.loading && rows.length === 0 && <LoadingBlock label="Loading coverage" />}
        {assignments.error && rows.length === 0 && (
          <ErrorBlock message={assignments.error} onRetry={assignments.refetch} />
        )}
        {!assignments.loading && rows.length === 0 && !assignments.error && (
          <EmptyBlock message="No regions assigned yet." />
        )}

        {rows.length > 0 && (
          <ul className="divide-y divide-carbon-gray-20 border border-carbon-gray-20 bg-carbon-white">
            {rows.map((assignment) => (
              <li key={assignment.id} className="flex items-center gap-4 px-4 py-4">
                <div>
                  <p className="font-serif text-base font-semibold text-carbon-gray-100">
                    {assignment.scope_value}
                  </p>
                  <p className="mt-1 text-sm text-carbon-gray-70">
                    {assignment.scope_type} · {assignment.user_name}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => remove(assignment.id)}
                  className="ml-auto font-sans text-sm text-carbon-gray-60 transition-colors hover:text-risk-critical"
                >
                  Remove
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
