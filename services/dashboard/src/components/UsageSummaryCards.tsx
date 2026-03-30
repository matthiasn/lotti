import type { UserUsageSummary } from "../types";

interface Props {
  summary: UserUsageSummary | null;
  loading: boolean;
}

function StatCard({
  label,
  value,
  className,
}: {
  label: string;
  value: string;
  className?: string;
}) {
  return (
    <div className="stat-card">
      <div className="stat-card__label">{label}</div>
      <div className={`stat-card__value ${className || ""}`}>{value}</div>
    </div>
  );
}

function SkeletonCard() {
  return (
    <div className="stat-card">
      <div className="skeleton" style={{ height: 12, width: 80, marginBottom: 10 }} />
      <div className="skeleton" style={{ height: 28, width: 100 }} />
    </div>
  );
}

export default function UsageSummaryCards({ summary, loading }: Props) {
  if (loading) {
    return (
      <div className="stat-grid">
        {[1, 2, 3, 4, 5].map((i) => (
          <SkeletonCard key={i} />
        ))}
      </div>
    );
  }

  if (!summary) return null;

  return (
    <div className="stat-grid">
      <StatCard
        label="Total Requests"
        value={summary.total_requests.toLocaleString()}
        className="stat-card__value--brand"
      />
      <StatCard
        label="Total Tokens"
        value={summary.total_tokens.toLocaleString()}
      />
      <StatCard
        label="Input Tokens"
        value={summary.total_prompt_tokens.toLocaleString()}
      />
      <StatCard
        label="Output Tokens"
        value={summary.total_completion_tokens.toLocaleString()}
      />
      <StatCard
        label="Total Cost"
        value={`$${Number(summary.total_cost_usd).toFixed(4)}`}
        className="stat-card__value--success"
      />
    </div>
  );
}
