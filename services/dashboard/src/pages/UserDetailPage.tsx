import { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import BalanceCard from "../components/BalanceCard";
import TransactionList from "../components/TransactionList";
import TokenUsageChart from "../components/TokenUsageChart";
import ModelBreakdownChart from "../components/ModelBreakdownChart";
import UsageSummaryCards from "../components/UsageSummaryCards";
import { fetchUser, fetchTransactions } from "../api/credits";
import { fetchUserUsage, fetchUserUsageSummary } from "../api/proxy";
import type {
  UserInfo,
  TransactionRecord,
  UsageLogEntry,
  UserUsageSummary,
} from "../types";

type Tab = "transactions" | "usage" | "models";

export default function UserDetailPage() {
  const { userId } = useParams<{ userId: string }>();
  const [user, setUser] = useState<UserInfo | null>(null);
  const [transactions, setTransactions] = useState<TransactionRecord[]>([]);
  const [txTotal, setTxTotal] = useState(0);
  const [txPage, setTxPage] = useState(1);
  const [usageEntries, setUsageEntries] = useState<UsageLogEntry[]>([]);
  const [usageSummary, setUsageSummary] = useState<UserUsageSummary | null>(
    null,
  );
  const [activeTab, setActiveTab] = useState<Tab>("transactions");
  const [loading, setLoading] = useState(true);
  const [txLoading, setTxLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!userId) return;
    setLoading(true);
    setError(null);

    Promise.all([
      fetchUser(userId),
      fetchTransactions(userId, 1, 20),
      fetchUserUsage(userId, 1, 100).catch(() => ({
        entries: [],
        total: 0,
        page: 1,
        page_size: 100,
      })),
      fetchUserUsageSummary(userId).catch(() => null),
    ])
      .then(([userRes, txRes, usageRes, summaryRes]) => {
        setUser(userRes);
        setTransactions(txRes.transactions);
        setTxTotal(txRes.total);
        setUsageEntries(usageRes.entries);
        setUsageSummary(summaryRes);
      })
      .catch((err) => setError(err.message || "Failed to load user"))
      .finally(() => setLoading(false));
  }, [userId]);

  useEffect(() => {
    if (!userId || txPage === 1) return;
    setTxLoading(true);
    fetchTransactions(userId, txPage, 20)
      .then((res) => {
        setTransactions(res.transactions);
        setTxTotal(res.total);
      })
      .finally(() => setTxLoading(false));
  }, [userId, txPage]);

  if (loading) {
    return (
      <div>
        <div className="skeleton" style={{ height: 20, width: 120, marginBottom: 16 }} />
        <div className="skeleton" style={{ height: 140, borderRadius: 24, marginBottom: 28 }} />
        <div className="skeleton" style={{ height: 200, borderRadius: 16 }} />
      </div>
    );
  }

  if (error) {
    return (
      <div>
        <Link to="/users" className="btn btn--ghost btn--sm" style={{ marginBottom: 16 }}>
          &larr; Back to users
        </Link>
        <div className="error-banner">{error}</div>
      </div>
    );
  }

  if (!user) return <p>User not found.</p>;

  return (
    <div>
      <Link
        to="/users"
        className="btn btn--ghost btn--sm"
        style={{ textDecoration: "none", marginBottom: 16, display: "inline-flex" }}
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <polyline points="15 18 9 12 15 6" />
        </svg>
        Back to users
      </Link>

      <BalanceCard
        balance={user.balance}
        userName={user.display_name}
        userId={user.user_id}
      />

      {/* Tabs */}
      <div className="tabs">
        {(
          [
            { key: "transactions", label: "Transactions" },
            { key: "usage", label: "Token Usage" },
            { key: "models", label: "Model Breakdown" },
          ] as const
        ).map(({ key, label }) => (
          <button
            key={key}
            className={`tab ${activeTab === key ? "tab--active" : ""}`}
            onClick={() => setActiveTab(key)}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      {activeTab === "transactions" && (
        <TransactionList
          transactions={transactions}
          loading={txLoading}
          total={txTotal}
          page={txPage}
          pageSize={20}
          onPageChange={setTxPage}
        />
      )}

      {activeTab === "usage" && (
        <div>
          <UsageSummaryCards summary={usageSummary} loading={false} />
          <div className="section">
            <div className="section__title">Daily Token Usage</div>
            <TokenUsageChart entries={usageEntries} />
          </div>
        </div>
      )}

      {activeTab === "models" && (
        <div className="section">
          <div className="section__title">Token Usage by Model</div>
          <ModelBreakdownChart summary={usageSummary} />
        </div>
      )}
    </div>
  );
}
