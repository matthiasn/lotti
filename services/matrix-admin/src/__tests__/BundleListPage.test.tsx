import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import BundleListPage from "../pages/BundleListPage";
import type { ProvisionedUser } from "../types";

const listBundles = vi.hoisted(() => vi.fn());
const updateBundle = vi.hoisted(() => vi.fn());
vi.mock("../api/provisioning", () => ({ listBundles, updateBundle }));

function user(overrides: Partial<ProvisionedUser> = {}): ProvisionedUser {
  return {
    bundle_id: "b-1",
    username: "lotti_user",
    user_mxid: "@lotti_user:example.com",
    home_server: "https://matrix.example.com",
    server_name: "example.com",
    room_id: "!room:example.com",
    display_name: null,
    status: "unused",
    payment_status: "unknown",
    bundle_fingerprint: "a".repeat(64),
    created_at: "2026-08-01T10:00:00+00:00",
    first_login_at: null,
    rotated_at: null,
    revoked_at: null,
    last_seen_at: null,
    last_polled_at: null,
    notes: "",
    ...overrides,
  };
}

describe("BundleListPage", () => {
  beforeEach(() => {
    listBundles.mockReset();
    updateBundle.mockReset();
  });

  it("renders each user with their redemption status", async () => {
    listBundles.mockResolvedValue({
      users: [
        user(),
        user({
          bundle_id: "b-2",
          username: "other_user",
          user_mxid: "@other_user:example.com",
          status: "rotated",
        }),
      ],
      total: 2,
      page: 1,
      page_size: 50,
    });

    render(<BundleListPage />);

    await screen.findByText("lotti_user");
    // Scoped per row: the status filter's options carry the same labels.
    const first = screen.getByRole("row", { name: /lotti_user/ });
    const second = screen.getByRole("row", { name: /other_user/ });

    expect(within(first).getByText("Unused")).toBeInTheDocument();
    expect(within(first).getByText("@lotti_user:example.com")).toBeInTheDocument();
    expect(within(second).getByText("Rotated")).toBeInTheDocument();
    expect(screen.getByText("2 total")).toBeInTheDocument();
  });

  it("shows an empty state when nothing is provisioned", async () => {
    listBundles.mockResolvedValue({ users: [], total: 0, page: 1, page_size: 50 });

    render(<BundleListPage />);

    expect(
      await screen.findByText("No provisioned users yet."),
    ).toBeInTheDocument();
  });

  it("refetches with the selected status filter", async () => {
    listBundles.mockResolvedValue({ users: [], total: 0, page: 1, page_size: 50 });
    const person = userEvent.setup();
    render(<BundleListPage />);
    await screen.findByText("No provisioned users yet.");

    await person.selectOptions(
      screen.getByLabelText("Filter by status"),
      "rotated",
    );

    await waitFor(() =>
      expect(listBundles).toHaveBeenLastCalledWith({
        status: "rotated",
        pageSize: 50,
      }),
    );
  });

  it("persists a payment-status change", async () => {
    listBundles.mockResolvedValue({
      users: [user()],
      total: 1,
      page: 1,
      page_size: 50,
    });
    updateBundle.mockResolvedValue(user({ payment_status: "paying" }));
    const person = userEvent.setup();
    render(<BundleListPage />);
    await screen.findByText("lotti_user");

    await person.selectOptions(
      screen.getByLabelText("Payment status for lotti_user"),
      "paying",
    );

    expect(updateBundle).toHaveBeenCalledWith("b-1", { paymentStatus: "paying" });
    const row = screen.getByRole("row", { name: /lotti_user/ });
    expect(within(row).getByText("Paying")).toBeInTheDocument();
  });

  it("rolls the row back and reports the error when the update fails", async () => {
    listBundles.mockResolvedValue({
      users: [user()],
      total: 1,
      page: 1,
      page_size: 50,
    });
    updateBundle.mockRejectedValue(new Error("database is locked"));
    const person = userEvent.setup();
    render(<BundleListPage />);
    await screen.findByText("lotti_user");

    await person.selectOptions(
      screen.getByLabelText("Payment status for lotti_user"),
      "paying",
    );

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "database is locked",
    );
    const row = screen.getByRole("row", { name: /lotti_user/ });
    expect(within(row).getByText("Unknown")).toBeInTheDocument();
  });

  it("reports a load failure", async () => {
    listBundles.mockRejectedValue(new Error("service unavailable"));

    render(<BundleListPage />);

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "service unavailable",
    );
  });
});
