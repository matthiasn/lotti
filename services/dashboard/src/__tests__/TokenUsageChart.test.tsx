import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import TokenUsageChart from "../components/TokenUsageChart";
import type { UsageLogEntry } from "../types";

// recharts uses ResizeObserver internally
class ResizeObserverMock {
  observe() {}
  unobserve() {}
  disconnect() {}
}
globalThis.ResizeObserver = ResizeObserverMock as unknown as typeof ResizeObserver;

describe("TokenUsageChart", () => {
  it("renders empty message when no data", () => {
    render(<TokenUsageChart entries={[]} />);
    expect(screen.getByText("No usage data yet")).toBeInTheDocument();
  });

  it("renders chart when data is provided", () => {
    const entries: UsageLogEntry[] = [
      {
        id: 1,
        user_id: "u1",
        model: "gemini-2.5-pro",
        prompt_tokens: 100,
        completion_tokens: 50,
        total_tokens: 150,
        cost_usd: 0.005,
        request_id: "req-1",
        created_at: "2026-01-15T10:00:00Z",
      },
    ];
    const { container } = render(<TokenUsageChart entries={entries} />);
    expect(container.querySelector(".recharts-responsive-container")).toBeTruthy();
  });
});
