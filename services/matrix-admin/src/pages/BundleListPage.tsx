import { useCallback, useEffect, useRef, useState } from "react";
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

const PAGE_SIZE = 50;

/** Roster of provisioned users with inline payment-status editing. */
export default function BundleListPage() {
  const [users, setUsers] = useState<ProvisionedUser[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState<BundleStatus | "">("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [expanded, setExpanded] = useState<string | null>(null);

  // Bumped for every fetch. Paging or filtering quickly leaves earlier requests
  // in flight, and without this the slower one lands last and overwrites the
  // roster with a page the admin already navigated away from.
  const requestId = useRef(0);

  const load = useCallback(async () => {
    const id = ++requestId.current;
    setError(null);
    try {
      const data = await listBundles({
        status: statusFilter,
        page,
        pageSize: PAGE_SIZE,
      });
      if (id !== requestId.current) return;
      setUsers(data.users);
      setTotal(data.total);
    } catch (caught) {
      if (id !== requestId.current) return;
      setError(errorMessage(caught));
    } finally {
      if (id === requestId.current) setLoading(false);
    }
  }, [statusFilter, page]);

  useEffect(() => {
    void load();
  }, [load]);

  // Changing the filter re-slices the whole set, so staying on page 4 would
  // land on an empty page for a filter with fewer matches.
  function changeFilter(next: BundleStatus | "") {
    setStatusFilter(next);
    setPage(1);
    setExpanded(null);
  }

  const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const firstOnPage = total === 0 ? 0 : (page - 1) * PAGE_SIZE + 1;
  const lastOnPage = (page - 1) * PAGE_SIZE + users.length;

  async function changePayment(user: ProvisionedUser, next: PaymentStatus) {
    // Optimistic: the roster is the admin's working surface and a round trip
    // per dropdown change makes bulk triage feel broken.
    const previous = user.payment_status;
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
      // Revert this row only, and only if it still shows what we set. Restoring
      // a whole snapshot of the roster would also undo any other change the
      // admin made while this request was in flight — bulk triage means several
      // are usually outstanding at once.
      setUsers((current) =>
        current.map((candidate) =>
          candidate.bundle_id === user.bundle_id &&
          candidate.payment_status === next
            ? { ...candidate, payment_status: previous }
            : candidate,
        ),
      );
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
            changeFilter(event.target.value as BundleStatus | "")
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

      {/* Without these the roster silently stops at the newest page, and older
          accounts become unreachable from the admin app entirely. */}
      <div className="pager">
        <p className="muted">
          {total === 0
            ? "0 total"
            : `${firstOnPage}–${lastOnPage} of ${total} total`}
        </p>
        {pageCount > 1 && (
          <div className="pager__controls">
            <button
              type="button"
              onClick={() => setPage((current) => current - 1)}
              disabled={page <= 1}
            >
              Previous
            </button>
            <span className="muted">
              Page {page} of {pageCount}
            </span>
            <button
              type="button"
              onClick={() => setPage((current) => current + 1)}
              disabled={page >= pageCount}
            >
              Next
            </button>
          </div>
        )}
      </div>
    </section>
  );
}
