import { useCallback, useEffect, useState } from "react";
import { errorMessage } from "../api/client";
import { listBundles, updateBundle } from "../api/provisioning";
import { BundleStatusBadge, PaymentStatusBadge } from "../components/StatusBadge";
import type {
  BundleStatus,
  PaymentStatus,
  ProvisionedUser,
} from "../types";

const PAYMENT_OPTIONS: PaymentStatus[] = [
  "unknown",
  "paying",
  "non_paying",
  "complimentary",
];

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
          <option value="unused">Unused</option>
          <option value="redeemed">Redeemed</option>
          <option value="rotated">Rotated</option>
          <option value="revoked">Revoked</option>
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
            </tr>
          </thead>
          <tbody>
            {users.map((user) => (
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
                  <PaymentStatusBadge status={user.payment_status} />
                  <label
                    htmlFor={`payment-${user.bundle_id}`}
                    className="visually-hidden"
                  >
                    Payment status for {user.username}
                  </label>
                  <select
                    id={`payment-${user.bundle_id}`}
                    value={user.payment_status}
                    onChange={(event) =>
                      changePayment(user, event.target.value as PaymentStatus)
                    }
                  >
                    {PAYMENT_OPTIONS.map((option) => (
                      <option key={option} value={option}>
                        {option}
                      </option>
                    ))}
                  </select>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <p className="muted">{total} total</p>
    </section>
  );
}
