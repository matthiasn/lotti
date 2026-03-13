import { useNavigate } from "react-router-dom";
import type { UserInfo } from "../types";

interface Props {
  users: UserInfo[];
  loading: boolean;
}

export default function UserTable({ users, loading }: Props) {
  const navigate = useNavigate();

  if (loading) {
    return (
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>User ID</th>
              <th>Display Name</th>
              <th>Created</th>
              <th style={{ textAlign: "right" }}>Balance</th>
              <th style={{ width: 40 }} />
            </tr>
          </thead>
          <tbody>
            {[1, 2, 3].map((i) => (
              <tr key={i}>
                <td><div className="skeleton" style={{ height: 16, width: 220 }} /></td>
                <td><div className="skeleton" style={{ height: 16, width: 100 }} /></td>
                <td><div className="skeleton" style={{ height: 16, width: 80 }} /></td>
                <td><div className="skeleton" style={{ height: 16, width: 60, marginLeft: "auto" }} /></td>
                <td />
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  }

  if (users.length === 0) {
    return (
      <div className="card">
        <div className="state-box">
          <div className="state-box__icon">&#x1f465;</div>
          <div className="state-box__title">No users yet</div>
          <div className="state-box__desc">
            Users will appear here once accounts are created via the API.
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>User ID</th>
            <th>Display Name</th>
            <th>Created</th>
            <th style={{ textAlign: "right" }}>Balance</th>
            <th style={{ width: 40 }} />
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <tr
              key={user.user_id}
              className="clickable"
              onClick={() => navigate(`/users/${user.user_id}`)}
            >
              <td>
                <span className="mono" style={{ color: "var(--color-text-tertiary)" }}>
                  {user.user_id}
                </span>
              </td>
              <td style={{ fontWeight: 500 }}>
                {user.display_name || (
                  <span style={{ color: "var(--color-text-tertiary)" }}>—</span>
                )}
              </td>
              <td style={{ color: "var(--color-text-secondary)" }}>
                {new Date(user.created_at).toLocaleDateString("en-US", {
                  month: "short",
                  day: "numeric",
                  year: "numeric",
                })}
              </td>
              <td
                style={{
                  textAlign: "right",
                  fontWeight: 600,
                  fontVariantNumeric: "tabular-nums",
                  color: "var(--color-brand)",
                }}
              >
                {user.balance != null ? (
                  `$${Number(user.balance).toFixed(2)}`
                ) : (
                  <span style={{ color: "var(--color-text-tertiary)" }}>—</span>
                )}
              </td>
              <td style={{ color: "var(--color-text-tertiary)" }}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <polyline points="9 18 15 12 9 6" />
                </svg>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
