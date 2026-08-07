import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import UserStoragePanel, { formatBytes } from "../components/UserStoragePanel";
import type { ProvisionedUser } from "../types";

const getUsage = vi.hoisted(() => vi.fn());
const purgeRoom = vi.hoisted(() => vi.fn());
const updateBundle = vi.hoisted(() => vi.fn());
vi.mock("../api/provisioning", () => ({ getUsage, purgeRoom, updateBundle }));

function user(overrides: Partial<ProvisionedUser> = {}): ProvisionedUser {
  return {
    bundle_id: "b-1",
    username: "lotti_user",
    user_mxid: "@lotti_user:example.com",
    home_server: "https://matrix.example.com",
    server_name: "example.com",
    room_id: "!room:example.com",
    display_name: null,
    status: "rotated",
    payment_status: "paying",
    bundle_fingerprint: "a".repeat(64),
    created_at: "2026-08-01T10:00:00+00:00",
    first_login_at: "2026-08-02T10:00:00+00:00",
    rotated_at: "2026-08-02T10:00:00+00:00",
    revoked_at: null,
    last_seen_at: null,
    last_polled_at: null,
    notes: "",
    retention_days: null,
    retention_exempt: false,
    ...overrides,
  };
}

const USAGE = {
  bundle_id: "b-1",
  user_mxid: "@lotti_user:example.com",
  device_count: 2,
  last_seen_ts: 1700000000000,
  deactivated: false,
  media_count: 3,
  media_length_bytes: 550_000,
  active_days: 5,
};

describe("formatBytes", () => {
  it.each([
    [0, "0 B"],
    [999, "999 B"],
    [1024, "1.0 KiB"],
    [550_000, "537 KiB"],
    [5_242_880, "5.0 MiB"],
    [1_073_741_824, "1.0 GiB"],
  ])("formats %i as %s", (bytes, expected) => {
    expect(formatBytes(bytes)).toBe(expected);
  });
});

describe("UserStoragePanel", () => {
  beforeEach(() => {
    getUsage.mockReset().mockResolvedValue(USAGE);
    purgeRoom.mockReset();
    updateBundle.mockReset();
  });

  it("shows live media usage for the account", async () => {
    render(<UserStoragePanel user={user()} />);

    expect(await screen.findByText("537 KiB")).toBeInTheDocument();
    expect(screen.getByText("3")).toBeInTheDocument();
  });

  it("reports the bytes actually reclaimed after a purge", async () => {
    purgeRoom.mockResolvedValue({
      purge_id: "purge_1",
      room_id: "!room:example.com",
      bundle_id: "b-1",
      purge_up_to_ts: 1,
      retention_days: 30,
      media_deleted: 2,
      bytes_freed: 460_000,
      include_media: true,
    });
    getUsage.mockResolvedValueOnce(USAGE).mockResolvedValueOnce({
      ...USAGE,
      media_count: 1,
      media_length_bytes: 90_000,
    });
    const person = userEvent.setup();
    render(<UserStoragePanel user={user()} />);
    await screen.findByText("537 KiB");

    await person.click(screen.getByRole("button", { name: "Reclaim space" }));

    const status = await screen.findByRole("status");
    expect(status).toHaveTextContent("449 KiB");
    expect(status).toHaveTextContent("2 media file(s)");
  });

  it("refreshes the figures after reclaiming, so they are not stale", async () => {
    purgeRoom.mockResolvedValue({
      purge_id: "p",
      room_id: "!r",
      bundle_id: "b-1",
      purge_up_to_ts: 1,
      retention_days: 30,
      media_deleted: 2,
      bytes_freed: 460_000,
      include_media: true,
    });
    getUsage.mockResolvedValueOnce(USAGE).mockResolvedValueOnce({
      ...USAGE,
      media_count: 1,
      media_length_bytes: 90_000,
    });
    const person = userEvent.setup();
    render(<UserStoragePanel user={user()} />);
    await screen.findByText("537 KiB");

    await person.click(screen.getByRole("button", { name: "Reclaim space" }));

    expect(await screen.findByText("88 KiB")).toBeInTheDocument();
  });

  it("warns that history-only mode will not free the media", async () => {
    const person = userEvent.setup();
    render(<UserStoragePanel user={user()} />);
    await screen.findByText("537 KiB");

    await person.click(screen.getByRole("checkbox", { name: /Delete media too/ }));

    expect(screen.getByText(/leaves all/)).toHaveTextContent(
      /537 KiB of media in place/,
    );
  });

  it("sends include_media false when the media box is unticked", async () => {
    purgeRoom.mockResolvedValue({
      purge_id: "p",
      room_id: "!r",
      bundle_id: "b-1",
      purge_up_to_ts: 1,
      retention_days: 30,
      media_deleted: 0,
      bytes_freed: 0,
      include_media: false,
    });
    const person = userEvent.setup();
    render(<UserStoragePanel user={user()} />);
    await screen.findByText("537 KiB");

    await person.click(screen.getByRole("checkbox", { name: /Delete media too/ }));
    await person.click(screen.getByRole("button", { name: "Reclaim space" }));

    expect(purgeRoom).toHaveBeenCalledWith("b-1", 30, false);
    expect(await screen.findByRole("status")).toHaveTextContent("No media deleted");
  });

  it("pins a per-user retention window", async () => {
    updateBundle.mockResolvedValue(user({ retention_days: 365 }));
    const onUserChange = vi.fn();
    const person = userEvent.setup();
    render(<UserStoragePanel user={user()} onUserChange={onUserChange} />);
    await screen.findByText("537 KiB");

    const field = screen.getByLabelText("Retention window for lotti_user");
    await person.type(field, "365");
    await person.tab();

    await waitFor(() =>
      expect(updateBundle).toHaveBeenCalledWith("b-1", { retentionDays: 365 }),
    );
    expect(onUserChange).toHaveBeenCalled();
  });

  it("clears the override back to the service default when blanked", async () => {
    updateBundle.mockResolvedValue(user({ retention_days: null }));
    const person = userEvent.setup();
    render(<UserStoragePanel user={user({ retention_days: 365 })} />);
    await screen.findByText("537 KiB");

    const field = screen.getByLabelText("Retention window for lotti_user");
    await person.clear(field);
    await person.tab();

    await waitFor(() =>
      expect(updateBundle).toHaveBeenCalledWith("b-1", {
        clearRetentionOverride: true,
      }),
    );
  });

  it("exempts a user from the automatic sweep", async () => {
    updateBundle.mockResolvedValue(user({ retention_exempt: true }));
    const person = userEvent.setup();
    render(<UserStoragePanel user={user()} />);
    await screen.findByText("537 KiB");

    await person.click(screen.getByRole("checkbox", { name: "Never sweep" }));

    await waitFor(() =>
      expect(updateBundle).toHaveBeenCalledWith("b-1", { retentionExempt: true }),
    );
  });

  it("disables the window field for an exempt user", async () => {
    render(<UserStoragePanel user={user({ retention_exempt: true })} />);
    await screen.findByText("537 KiB");

    expect(screen.getByLabelText("Retention window for lotti_user")).toBeDisabled();
  });

  it("surfaces a usage load failure", async () => {
    getUsage.mockRejectedValue(new Error("homeserver unreachable"));

    render(<UserStoragePanel user={user()} />);

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "homeserver unreachable",
    );
  });

  it("surfaces a purge failure without claiming success", async () => {
    purgeRoom.mockRejectedValue(new Error("media deletion failed"));
    const person = userEvent.setup();
    render(<UserStoragePanel user={user()} />);
    await screen.findByText("537 KiB");

    await person.click(screen.getByRole("button", { name: "Reclaim space" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "media deletion failed",
    );
    expect(screen.queryByRole("status")).toBeNull();
  });
});
