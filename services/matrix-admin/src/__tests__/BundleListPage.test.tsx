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
    retention_days: null,
    retention_exempt: false,
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
    expect(screen.getByText("1–2 of 2 total")).toBeInTheDocument();
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
        page: 1,
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
    expect(screen.getByLabelText("Payment status for lotti_user")).toHaveValue(
      "paying",
    );
  });

  it("labels payment options in prose, not raw enum values", async () => {
    listBundles.mockResolvedValue({
      users: [user()],
      total: 1,
      page: 1,
      page_size: 50,
    });
    render(<BundleListPage />);
    await screen.findByText("lotti_user");

    const select = screen.getByLabelText("Payment status for lotti_user");
    const labels = within(select)
      .getAllByRole("option")
      .map((option) => option.textContent);

    expect(labels).toEqual(["Unknown", "Paying", "Not paying", "Complimentary"]);
    expect(labels).not.toContain("non_paying");
  });

  it("shows the current payment status as the selected value", async () => {
    listBundles.mockResolvedValue({
      users: [user({ payment_status: "complimentary" })],
      total: 1,
      page: 1,
      page_size: 50,
    });
    render(<BundleListPage />);
    await screen.findByText("lotti_user");

    // The pill *is* the control, so the status has to read off its value
    // rather than off a separate badge.
    expect(screen.getByLabelText("Payment status for lotti_user")).toHaveValue(
      "complimentary",
    );
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
    expect(screen.getByLabelText("Payment status for lotti_user")).toHaveValue(
      "unknown",
    );
  });

  it("pages to users beyond the first page", async () => {
    // Past 50 users the older accounts are simply not in the list, and without
    // controls there is no way to reach them at all.
    listBundles.mockResolvedValue({
      users: [user()],
      total: 73,
      page: 1,
      page_size: 50,
    });
    const person = userEvent.setup();
    render(<BundleListPage />);
    await screen.findByText("lotti_user");

    await person.click(screen.getByRole("button", { name: "Next" }));

    await waitFor(() =>
      expect(listBundles).toHaveBeenLastCalledWith({
        status: "",
        page: 2,
        pageSize: 50,
      }),
    );
  });

  it("cannot page back past the first page", async () => {
    listBundles.mockResolvedValue({
      users: [user()],
      total: 73,
      page: 1,
      page_size: 50,
    });
    render(<BundleListPage />);
    await screen.findByText("lotti_user");

    expect(screen.getByRole("button", { name: "Previous" })).toBeDisabled();
  });

  it("hides the controls when everything fits on one page", async () => {
    listBundles.mockResolvedValue({
      users: [user()],
      total: 1,
      page: 1,
      page_size: 50,
    });
    render(<BundleListPage />);
    await screen.findByText("lotti_user");

    expect(screen.queryByRole("button", { name: "Next" })).toBeNull();
    expect(screen.getByText("1–1 of 1 total")).toBeInTheDocument();
  });

  it("returns to the first page when the filter changes", async () => {
    // A narrower filter can have fewer pages, so keeping the old page number
    // would land the admin on an empty list.
    listBundles.mockResolvedValue({
      users: [user()],
      total: 200,
      page: 1,
      page_size: 50,
    });
    const person = userEvent.setup();
    render(<BundleListPage />);
    await screen.findByText("lotti_user");
    await person.click(screen.getByRole("button", { name: "Next" }));
    await waitFor(() =>
      expect(listBundles).toHaveBeenLastCalledWith({
        status: "",
        page: 2,
        pageSize: 50,
      }),
    );

    await person.selectOptions(
      screen.getByLabelText("Filter by status"),
      "rotated",
    );

    await waitFor(() =>
      expect(listBundles).toHaveBeenLastCalledWith({
        status: "rotated",
        page: 1,
        pageSize: 50,
      }),
    );
  });

  it("reverts only the row whose update failed", async () => {
    // The failing request must be *in flight* while the second change is made:
    // a snapshot taken before it captures the roster without that change, so
    // restoring it wholesale silently undoes work the admin already did.
    listBundles.mockResolvedValue({
      users: [
        user(),
        user({
          bundle_id: "b-2",
          username: "other_user",
          user_mxid: "@other_user:example.com",
        }),
      ],
      total: 2,
      page: 1,
      page_size: 50,
    });
    let failFirst: () => void = () => {};
    updateBundle.mockImplementation(
      (id: string) =>
        id === "b-1"
          ? new Promise((_resolve, reject) => {
              failFirst = () => reject(new Error("database is locked"));
            })
          : Promise.resolve(user({ bundle_id: "b-2", payment_status: "paying" })),
    );
    const person = userEvent.setup();
    render(<BundleListPage />);
    await screen.findByText("lotti_user");

    await person.selectOptions(
      screen.getByLabelText("Payment status for lotti_user"),
      "paying",
    );
    await person.selectOptions(
      screen.getByLabelText("Payment status for other_user"),
      "paying",
    );
    failFirst();

    await screen.findByRole("alert");
    // The failed row rolls back...
    expect(screen.getByLabelText("Payment status for lotti_user")).toHaveValue(
      "unknown",
    );
    // ...and the change made while it was in flight survives.
    expect(screen.getByLabelText("Payment status for other_user")).toHaveValue(
      "paying",
    );
  });

  it("ignores a slow response for a page the admin has left", async () => {
    // Paging then filtering leaves the page-2 request outstanding. Without a
    // guard it resolves last and replaces a roster already moved on from.
    const page = (username: string, bundleId: string) => ({
      users: [user({ bundle_id: bundleId, username })],
      total: 73,
      page: 1,
      page_size: 50,
    });
    let releaseStale: () => void = () => {};

    listBundles
      .mockResolvedValueOnce(page("first_user", "b-1"))
      .mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            releaseStale = () => resolve(page("stale_user", "b-old"));
          }),
      )
      .mockResolvedValue(page("fresh_user", "b-new"));

    const person = userEvent.setup();
    render(<BundleListPage />);
    await screen.findByText("first_user");

    // Request 2 (page 2) is left pending...
    await person.click(screen.getByRole("button", { name: "Next" }));
    // ...while request 3 (filter change) resolves.
    await person.selectOptions(
      screen.getByLabelText("Filter by status"),
      "rotated",
    );
    await screen.findByText("fresh_user");

    releaseStale();
    await waitFor(() => expect(listBundles).toHaveBeenCalledTimes(3));

    expect(screen.getByText("fresh_user")).toBeInTheDocument();
    expect(screen.queryByText("stale_user")).toBeNull();
  });

  it("reports a load failure", async () => {
    listBundles.mockRejectedValue(new Error("service unavailable"));

    render(<BundleListPage />);

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "service unavailable",
    );
  });
});
