import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import UserDetailPage from "../pages/UserDetailPage";

const mockFetchUser = vi.fn();
const mockFetchTransactions = vi.fn();
const mockFetchUserUsage = vi.fn();
const mockFetchUserUsageSummary = vi.fn();

vi.mock("../api/credits", () => ({
  fetchUser: (...args: unknown[]) => mockFetchUser(...args),
  fetchTransactions: (...args: unknown[]) => mockFetchTransactions(...args),
}));

vi.mock("../api/proxy", () => ({
  fetchUserUsage: (...args: unknown[]) => mockFetchUserUsage(...args),
  fetchUserUsageSummary: (...args: unknown[]) =>
    mockFetchUserUsageSummary(...args),
}));

function renderPage(userId = "test-user-1") {
  return render(
    <MemoryRouter initialEntries={[`/users/${userId}`]}>
      <Routes>
        <Route path="/users/:userId" element={<UserDetailPage />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe("UserDetailPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();

    mockFetchUser.mockResolvedValue({
      user_id: "test-user-1",
      display_name: "Test User",
      created_at: "2026-01-01T00:00:00Z",
      balance: 75.5,
    });

    mockFetchTransactions.mockResolvedValue({
      transactions: [
        {
          id: 1,
          user_id: "test-user-1",
          type: "topup",
          amount: 100.0,
          description: null,
          balance_after: 100.0,
          created_at: "2026-01-01T10:00:00Z",
        },
        {
          id: 2,
          user_id: "test-user-1",
          type: "bill",
          amount: 24.5,
          description: "Gemini API call",
          balance_after: 75.5,
          created_at: "2026-01-02T10:00:00Z",
        },
      ],
      total: 2,
      page: 1,
      page_size: 20,
    });

    mockFetchUserUsage.mockResolvedValue({
      entries: [],
      total: 0,
      page: 1,
      page_size: 100,
    });

    mockFetchUserUsageSummary.mockResolvedValue({
      total_requests: 5,
      total_prompt_tokens: 1000,
      total_completion_tokens: 500,
      total_tokens: 1500,
      total_cost_usd: 0.05,
      by_model: {},
    });
  });

  it("renders user details", async () => {
    renderPage();

    await waitFor(() => {
      expect(screen.getByText(/Test User/)).toBeInTheDocument();
    });
    expect(screen.getByText("test-user-1")).toBeInTheDocument();
    expect(screen.getAllByText("$75.50").length).toBeGreaterThanOrEqual(1);
  });

  it("renders transactions tab by default", async () => {
    renderPage();

    await waitFor(() => {
      expect(screen.getByText("Top-up")).toBeInTheDocument();
    });
    expect(screen.getByText("Charge")).toBeInTheDocument();
    expect(screen.getByText("Gemini API call")).toBeInTheDocument();
  });

  it("switches to usage tab", async () => {
    renderPage();

    await waitFor(() => {
      expect(screen.getByText(/Test User/)).toBeInTheDocument();
    });

    fireEvent.click(screen.getByText("Token Usage"));

    await waitFor(() => {
      expect(screen.getByText("Daily Token Usage")).toBeInTheDocument();
    });
  });

  it("switches to models tab", async () => {
    renderPage();

    await waitFor(() => {
      expect(screen.getByText(/Test User/)).toBeInTheDocument();
    });

    fireEvent.click(screen.getByText("Model Breakdown"));

    await waitFor(() => {
      expect(screen.getByText("Token Usage by Model")).toBeInTheDocument();
    });
  });

  it("shows back link to users", async () => {
    renderPage();

    await waitFor(() => {
      expect(screen.getByText(/Test User/)).toBeInTheDocument();
    });

    expect(screen.getByText(/Back to users/)).toBeInTheDocument();
  });
});
