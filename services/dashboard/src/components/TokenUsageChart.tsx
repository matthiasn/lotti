import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";
import type { UsageLogEntry } from "../types";

interface Props {
  entries: UsageLogEntry[];
}

interface DailyData {
  date: string;
  prompt_tokens: number;
  completion_tokens: number;
}

function aggregateByDay(entries: UsageLogEntry[]): DailyData[] {
  const map = new Map<string, DailyData>();
  for (const entry of entries) {
    const date = entry.created_at.slice(0, 10);
    const existing = map.get(date) || {
      date,
      prompt_tokens: 0,
      completion_tokens: 0,
    };
    existing.prompt_tokens += entry.prompt_tokens;
    existing.completion_tokens += entry.completion_tokens;
    map.set(date, existing);
  }
  return Array.from(map.values()).sort((a, b) => a.date.localeCompare(b.date));
}

export default function TokenUsageChart({ entries }: Props) {
  const data = aggregateByDay(entries);

  if (data.length === 0) {
    return (
      <div className="card">
        <div className="state-box">
          <div className="state-box__icon">&#x1f4ca;</div>
          <div className="state-box__title">No usage data yet</div>
          <div className="state-box__desc">
            Token usage will appear here after AI requests are made through the proxy.
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="card" style={{ padding: "24px 24px 16px" }}>
      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={data} barCategoryGap="20%">
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" vertical={false} />
          <XAxis
            dataKey="date"
            fontSize={11}
            tickLine={false}
            axisLine={{ stroke: "rgba(255,255,255,0.08)" }}
            tick={{ fill: "#64748b" }}
          />
          <YAxis
            fontSize={11}
            tickLine={false}
            axisLine={false}
            tick={{ fill: "#64748b" }}
            tickFormatter={(v: number) =>
              v >= 1000 ? `${(v / 1000).toFixed(0)}k` : String(v)
            }
          />
          <Tooltip
            contentStyle={{
              background: "#1a1a1a",
              border: "1px solid rgba(255,255,255,0.1)",
              borderRadius: 12,
              boxShadow: "0 10px 25px rgba(0,0,0,0.5)",
              fontSize: 12,
              color: "#f8fafc",
            }}
            formatter={(value: number, name: string) => [
              value.toLocaleString(),
              name === "prompt_tokens" ? "Input Tokens" : "Output Tokens",
            ]}
          />
          <Legend
            iconType="circle"
            iconSize={8}
            wrapperStyle={{ fontSize: 12, paddingTop: 8, color: "#94a3b8" }}
            formatter={(value: string) =>
              value === "prompt_tokens" ? "Input Tokens" : "Output Tokens"
            }
          />
          <Bar
            dataKey="prompt_tokens"
            fill="#E5FF4D"
            radius={[4, 4, 0, 0]}
            stackId="tokens"
          />
          <Bar
            dataKey="completion_tokens"
            fill="#667eea"
            radius={[4, 4, 0, 0]}
            stackId="tokens"
          />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
