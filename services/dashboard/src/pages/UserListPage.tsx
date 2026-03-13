import { useEffect, useState } from "react";
import UserTable from "../components/UserTable";
import { fetchUsers } from "../api/credits";
import type { UserInfo } from "../types";

export default function UserListPage() {
  const [users, setUsers] = useState<UserInfo[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const pageSize = 20;

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    fetchUsers(page, pageSize)
      .then((res) => {
        if (cancelled) return;
        setUsers(res.users);
        setTotal(res.total);
      })
      .catch((err) => {
        if (cancelled) return;
        setError(err?.message || "Failed to load users");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [page]);

  const totalPages = Math.ceil(total / pageSize);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Users</h1>
          {!loading && (
            <div className="page-subtitle">
              {total} registered user{total !== 1 ? "s" : ""}
            </div>
          )}
        </div>
      </div>

      {error && <div className="error-banner">{error}</div>}

      <UserTable users={users} loading={loading} />

      {totalPages > 1 && (
        <div className="pagination">
          <button
            className="btn btn--sm"
            disabled={page <= 1}
            onClick={() => setPage((p) => p - 1)}
          >
            Previous
          </button>
          <span>
            Page {page} of {totalPages}
          </span>
          <button
            className="btn btn--sm"
            disabled={page >= totalPages}
            onClick={() => setPage((p) => p + 1)}
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}
