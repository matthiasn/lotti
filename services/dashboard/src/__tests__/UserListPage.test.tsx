import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import UserListPage from "../pages/UserListPage";

const mockFetchUsers = vi.fn();

vi.mock("../api/credits", () => ({
  fetchUsers: (...args: unknown[]) => mockFetchUsers(...args),
}));

function renderPage() {
  return render(
    <MemoryRouter>
      <UserListPage />
    </MemoryRouter>,
  );
}

describe("UserListPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders skeleton loading state initially", () => {
    mockFetchUsers.mockReturnValue(new Promise(() => {})); // never resolves
    const { container } = renderPage();
    expect(container.querySelectorAll(".skeleton").length).toBeGreaterThan(0);
  });

  it("renders users when loaded", async () => {
    mockFetchUsers.mockResolvedValue({
      users: [
        {
          user_id: "abc-123",
          display_name: "Alice",
          created_at: "2026-01-15T00:00:00Z",
          balance: 50.0,
        },
      ],
      total: 1,
      page: 1,
      page_size: 20,
    });

    renderPage();

    await waitFor(() => {
      expect(screen.getByText("abc-123")).toBeInTheDocument();
    });
    expect(screen.getByText("Alice")).toBeInTheDocument();
    expect(screen.getByText("$50.00")).toBeInTheDocument();
  });

  it("renders empty state when no users", async () => {
    mockFetchUsers.mockResolvedValue({
      users: [],
      total: 0,
      page: 1,
      page_size: 20,
    });

    renderPage();

    await waitFor(() => {
      expect(screen.getByText("No users yet")).toBeInTheDocument();
    });
  });

  it("renders error state on failure", async () => {
    mockFetchUsers.mockRejectedValue(new Error("Network error"));

    renderPage();

    await waitFor(() => {
      expect(screen.getByText("Network error")).toBeInTheDocument();
    });
  });

  it("shows pagination when there are multiple pages", async () => {
    mockFetchUsers.mockResolvedValue({
      users: Array.from({ length: 20 }, (_, i) => ({
        user_id: `user-${i}`,
        display_name: `User ${i}`,
        created_at: "2026-01-15T00:00:00Z",
        balance: 10.0,
      })),
      total: 45,
      page: 1,
      page_size: 20,
    });

    renderPage();

    await waitFor(() => {
      expect(screen.getByText(/Page 1 of 3/)).toBeInTheDocument();
    });
  });
});
