import { describe, it, expect, vi, beforeAll, afterAll, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import SystemOverviewPage from "../pages/SystemOverviewPage";

// recharts ResizeObserver mock
class ResizeObserverMock {
  observe() {}
  unobserve() {}
  disconnect() {}
}
const originalResizeObserver = globalThis.ResizeObserver;

beforeAll(() => {
  globalThis.ResizeObserver = ResizeObserverMock as unknown as typeof ResizeObserver;
});

afterAll(() => {
  globalThis.ResizeObserver = originalResizeObserver;
});

const mockFetchSystemSummary = vi.fn();
const mockFetchUsers = vi.fn();

vi.mock("../api/proxy", () => ({
  fetchSystemUsageSummary: (...args: unknown[]) =>
    mockFetchSystemSummary(...args),
}));

vi.mock("../api/credits", () => ({
  fetchUsers: (...args: unknown[]) => mockFetchUsers(...args),
}));

describe("SystemOverviewPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockFetchUsers.mockResolvedValue({ total: 12 });
    mockFetchSystemSummary.mockResolvedValue({
      total_requests: 150,
      total_prompt_tokens: 50000,
      total_completion_tokens: 25000,
      total_tokens: 75000,
      total_cost_usd: 3.5,
      by_model: {
        "gemini-2.5-pro": {
          requests: 100,
          prompt_tokens: 40000,
          completion_tokens: 20000,
          total_tokens: 60000,
          total_cost_usd: 3.0,
        },
      },
    });
  });

  it("renders system stats", async () => {
    render(
      <MemoryRouter>
        <SystemOverviewPage />
      </MemoryRouter>,
    );

    await waitFor(() => {
      expect(screen.getByText("12")).toBeInTheDocument();
    });
    // "150" appears in both the top stat grid and UsageSummaryCards
    expect(screen.getAllByText("150").length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText("75,000").length).toBeGreaterThanOrEqual(1);
  });

  it("renders headings", async () => {
    render(
      <MemoryRouter>
        <SystemOverviewPage />
      </MemoryRouter>,
    );

    await waitFor(() => {
      expect(screen.getByText("System Overview")).toBeInTheDocument();
    });
    expect(screen.getByText("Usage Summary")).toBeInTheDocument();
    expect(screen.getByText("Usage by Model")).toBeInTheDocument();
  });
});
