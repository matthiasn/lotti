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
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="day" />
              <YAxis allowDecimals={false} />
              <Tooltip />
              <Bar dataKey="count" fill="#5b8def" />
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
