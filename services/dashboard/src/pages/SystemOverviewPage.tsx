import { useEffect, useState } from "react";
import UsageSummaryCards from "../components/UsageSummaryCards";
import ModelBreakdownChart from "../components/ModelBreakdownChart";
import { fetchSystemUsageSummary } from "../api/proxy";
import { fetchUsers } from "../api/credits";
import type { UserUsageSummary } from "../types";

export default function SystemOverviewPage() {
  const [summary, setSummary] = useState<UserUsageSummary | null>(null);
  const [totalUsers, setTotalUsers] = useState<number>(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    setError(null);
    Promise.allSettled([fetchSystemUsageSummary(), fetchUsers(1, 1)])
      .then(([summaryRes, usersRes]) => {
        if (summaryRes.status === "fulfilled") {
          setSummary(summaryRes.value);
        } else {
          setSummary(null);
          setError("Failed to load usage summary");
        }

        if (usersRes.status === "fulfilled") {
          setTotalUsers(usersRes.value.total ?? 0);
        } else {
          setTotalUsers(0);
          setError((prev) => prev ?? "Failed to load user count");
        }
      })
      .finally(() => setLoading(false));
  }, []);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>System Overview</h1>
          <div className="page-subtitle">
            Aggregate usage and billing across all users
          </div>
        </div>
      </div>

      {error && <div className="error-banner">{error}</div>}

      {/* Top-level stats */}
      <div className="stat-grid" style={{ marginBottom: 32 }}>
        <div className="stat-card">
          <div className="stat-card__label">Total Users</div>
          <div className="stat-card__value stat-card__value--brand">
            {loading ? (
              <div className="skeleton" style={{ height: 28, width: 40 }} />
            ) : (
              totalUsers
            )}
          </div>
        </div>
        {summary && (
          <>
            <div className="stat-card">
              <div className="stat-card__label">Total Requests</div>
              <div className="stat-card__value">
                {summary.total_requests.toLocaleString()}
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-card__label">Total Tokens</div>
              <div className="stat-card__value">
                {summary.total_tokens.toLocaleString()}
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-card__label">Total Spend</div>
              <div className="stat-card__value stat-card__value--success">
                ${Number(summary.total_cost_usd).toFixed(4)}
              </div>
            </div>
          </>
        )}
      </div>

      {/* Usage breakdown */}
      <div className="section">
        <div className="section__title">Usage Summary</div>
        <UsageSummaryCards summary={summary} loading={loading} />
      </div>

      <div className="section">
        <div className="section__title">Usage by Model</div>
        <ModelBreakdownChart summary={summary} />
      </div>
    </div>
  );
}
