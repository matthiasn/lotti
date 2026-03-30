import {
  PieChart,
  Pie,
  Cell,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";
import type { UserUsageSummary } from "../types";

interface Props {
  summary: UserUsageSummary | null;
}

const FILL_COLORS = ["#E5FF4D", "#667eea", "#34C191", "#f97066", "#3b82f6"];

export default function ModelBreakdownChart({ summary }: Props) {
  if (!summary || Object.keys(summary.by_model).length === 0) {
    return (
      <div className="card">
        <div className="state-box">
          <div className="state-box__icon">&#x1f4c8;</div>
          <div className="state-box__title">No model data yet</div>
          <div className="state-box__desc">
            Model breakdown will appear after AI requests are processed.
          </div>
        </div>
      </div>
    );
  }

  const data = Object.entries(summary.by_model).map(([model, usage]) => ({
    name: model,
    value: usage.total_tokens,
    cost: usage.total_cost_usd,
  }));

  return (
    <div className="card" style={{ padding: "24px" }}>
      <ResponsiveContainer width="100%" height={300}>
        <PieChart>
          <Pie
            data={data}
            dataKey="value"
            nameKey="name"
            cx="50%"
            cy="50%"
            innerRadius={65}
            outerRadius={105}
            paddingAngle={3}
            label={({ name, percent }) =>
              `${name} (${(percent * 100).toFixed(0)}%)`
            }
            labelLine={{ stroke: "#475569", strokeWidth: 1 }}
          >
            {data.map((_, i) => (
              <Cell key={i} fill={FILL_COLORS[i % FILL_COLORS.length]} />
            ))}
          </Pie>
          <Tooltip
            contentStyle={{
              background: "#1a1a1a",
              border: "1px solid rgba(255,255,255,0.1)",
              borderRadius: 12,
              boxShadow: "0 10px 25px rgba(0,0,0,0.5)",
              fontSize: 12,
              color: "#f8fafc",
            }}
            formatter={(value: number) => [
              value.toLocaleString() + " tokens",
              "Usage",
            ]}
          />
          <Legend
            iconType="circle"
            iconSize={8}
            wrapperStyle={{ fontSize: 12, color: "#94a3b8" }}
          />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );
}
