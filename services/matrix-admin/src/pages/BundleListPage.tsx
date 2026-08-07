import { useCallback, useEffect, useState } from "react";
import { errorMessage } from "../api/client";
import { listBundles, updateBundle } from "../api/provisioning";
import {
  BUNDLE_LABELS,
  BundleStatusBadge,
  PaymentStatusSelect,
} from "../components/StatusBadge";
import UserStoragePanel from "../components/UserStoragePanel";
import type { BundleStatus, PaymentStatus, ProvisionedUser } from "../types";

function formatDate(value: string | null): string {
  return value ? new Date(value).toLocaleDateString() : "—";
}

/** Roster of provisioned users with inline payment-status editing. */
export default function BundleListPage() {
  const [users, setUsers] = useState<ProvisionedUser[]>([]);
  const [total, setTotal] = useState(0);
  const [statusFilter, setStatusFilter] = useState<BundleStatus | "">("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [expanded, setExpanded] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const data = await listBundles({ status: statusFilter, pageSize: 50 });
      setUsers(data.users);
      setTotal(data.total);
    } catch (caught) {
      setError(errorMessage(caught));
    } finally {
      setLoading(false);
    }
  }, [statusFilter]);

  useEffect(() => {
    void load();
  }, [load]);

  async function changePayment(user: ProvisionedUser, next: PaymentStatus) {
    // Optimistic: the roster is the admin's working surface and a round trip
    // per dropdown change makes bulk triage feel broken.
    const previous = users;
    setUsers((current) =>
      current.map((candidate) =>
        candidate.bundle_id === user.bundle_id
          ? { ...candidate, payment_status: next }
          : candidate,
      ),
    );
    try {
      await updateBundle(user.bundle_id, { paymentStatus: next });
    } catch (caught) {
      setUsers(previous);
      setError(errorMessage(caught));
    }
  }

  if (loading) return <p>Loading…</p>;

  return (
    <section className="card">
      <div className="card__header">
        <h1>Provisioned users</h1>
        <label htmlFor="status-filter" className="visually-hidden">
          Filter by status
        </label>
        <select
          id="status-filter"
          value={statusFilter}
          onChange={(event) =>
            setStatusFilter(event.target.value as BundleStatus | "")
          }
        >
          <option value="">All statuses</option>
          {(Object.keys(BUNDLE_LABELS) as BundleStatus[]).map((option) => (
            <option key={option} value={option}>
              {BUNDLE_LABELS[option]}
            </option>
          ))}
        </select>
      </div>

      {error && (
        <p role="alert" className="error-text">
          {error}
        </p>
      )}

      {users.length === 0 ? (
        <p className="muted">No provisioned users yet.</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th scope="col">User</th>
              <th scope="col">Status</th>
              <th scope="col">Created</th>
              <th scope="col">First login</th>
              <th scope="col">Payment</th>
              <th scope="col">Storage</th>
            </tr>
          </thead>
          <tbody>
            {users.flatMap((user) => [
              <tr key={user.bundle_id}>
                <td>
                  <div>{user.username}</div>
                  <small className="muted">{user.user_mxid}</small>
                </td>
                <td>
                  <BundleStatusBadge status={user.status} />
                </td>
                <td>{formatDate(user.created_at)}</td>
                <td>{formatDate(user.first_login_at)}</td>
                <td>
                  <PaymentStatusSelect
                    status={user.payment_status}
                    label={`Payment status for ${user.username}`}
                    onChange={(next) => changePayment(user, next)}
                  />
                </td>
                <td>
                  <button
                    type="button"
                    className="link-button"
                    aria-expanded={expanded === user.bundle_id}
                    onClick={() =>
                      setExpanded(
                        expanded === user.bundle_id ? null : user.bundle_id,
                      )
                    }
                  >
                    {expanded === user.bundle_id ? "Hide" : "Storage"}
                  </button>
                </td>
              </tr>,
              expanded === user.bundle_id ? (
                <tr key={`${user.bundle_id}-detail`} className="detail-row">
                  <td colSpan={6}>
                    <UserStoragePanel
                      user={user}
                      onUserChange={(updated) =>
                        setUsers((current) =>
                          current.map((candidate) =>
                            candidate.bundle_id === updated.bundle_id
                              ? updated
                              : candidate,
                          ),
                        )
                      }
                    />
                  </td>
                </tr>
              ) : null,
            ])}
          </tbody>
        </table>
      )}

      <p className="muted">{total} total</p>
    </section>
  );
}
