import { useEffect, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { errorMessage } from "../api/client";
import { getStats } from "../api/provisioning";
import type { Stats } from "../types";

/**
 * Chart colours, kept in step with the tokens in styles.css.
 *
 * Recharts takes colours as props rather than CSS, so these cannot be CSS
 * custom properties — they are the same values, declared once here.
 */
const CHART = {
  bar: "#e5ff4d",
  grid: "rgba(255, 255, 255, 0.08)",
  axis: "#64748b",
  cursor: "rgba(229, 255, 77, 0.08)",
  tooltipBg: "#161616",
  text: "#f8fafc",
} as const;

/** Sign-up and contribution overview for the community server. */
export default function OverviewPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getStats().then(setStats).catch((caught) => setError(errorMessage(caught)));
  }, []);

  if (error)
    return (
      <p role="alert" className="error-text">
        {error}
      </p>
    );
  if (!stats) return <p>Loading…</p>;

  const signups = Object.entries(stats.signups_by_day).map(([day, count]) => ({
    day,
    count,
  }));

  return (
    <section className="card">
      <h1>Overview</h1>

      <div className="stat-grid">
        <Stat label="Provisioned" value={stats.total_provisioned} />
        <Stat label="Outstanding" value={stats.unused} />
        <Stat label="Redeemed" value={stats.redeemed + stats.rotated} />
        <Stat label="Paying" value={stats.paying} />
      </div>

      <h2>Sign-ups over time</h2>
      {signups.length === 0 ? (
        <p className="muted">No sign-ups in the selected window.</p>
      ) : (
        <div style={{ width: "100%", height: 260 }}>
          <ResponsiveContainer>
            <BarChart data={signups}>
              <CartesianGrid strokeDasharray="3 3" stroke={CHART.grid} />
              <XAxis dataKey="day" stroke={CHART.axis} fontSize={12} />
              <YAxis allowDecimals={false} stroke={CHART.axis} fontSize={12} />
              <Tooltip
                cursor={{ fill: CHART.cursor }}
                contentStyle={{
                  background: CHART.tooltipBg,
                  border: `1px solid ${CHART.grid}`,
                  borderRadius: 6,
                  color: CHART.text,
                }}
              />
              <Bar dataKey="count" fill={CHART.bar} radius={[3, 3, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </section>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="stat">
      <div className="stat__value">{value}</div>
      <div className="stat__label">{label}</div>
    </div>
  );
}
