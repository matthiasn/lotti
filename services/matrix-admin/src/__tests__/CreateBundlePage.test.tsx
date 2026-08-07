import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import CreateBundlePage from "../pages/CreateBundlePage";

const createBundle = vi.hoisted(() => vi.fn());
vi.mock("../api/provisioning", () => ({ createBundle }));

const RESPONSE = {
  bundle: "encoded-bundle-value",
  user: {
    bundle_id: "b-1",
    username: "lotti_user",
    user_mxid: "@lotti_user:example.com",
    room_id: "!room:example.com",
    bundle_fingerprint: "a".repeat(64),
    status: "unused",
    payment_status: "unknown",
    created_at: "2026-08-07T10:00:00+00:00",
    first_login_at: null,
    rotated_at: null,
    revoked_at: null,
    last_seen_at: null,
    last_polled_at: null,
    notes: "",
    home_server: "https://matrix.example.com",
    server_name: "example.com",
    display_name: null,
  },
};

describe("CreateBundlePage", () => {
  beforeEach(() => {
    createBundle.mockReset();
  });

  it("submits the username and reveals the returned bundle", async () => {
    createBundle.mockResolvedValue(RESPONSE);
    const user = userEvent.setup();
    render(<CreateBundlePage />);

    await user.type(screen.getByLabelText("Username"), "lotti_user");
    await user.click(screen.getByRole("button", { name: "Provision account" }));

    await waitFor(() =>
      expect(screen.getByLabelText("Provisioning bundle")).toHaveValue(
        "encoded-bundle-value",
      ),
    );
    expect(createBundle).toHaveBeenCalledWith({
      username: "lotti_user",
      displayName: "",
      notes: "",
    });
  });

  it("passes the optional display name and notes through", async () => {
    createBundle.mockResolvedValue(RESPONSE);
    const user = userEvent.setup();
    render(<CreateBundlePage />);

    await user.type(screen.getByLabelText("Username"), "lotti_user");
    await user.type(screen.getByLabelText("Display name (optional)"), "Ada");
    await user.type(screen.getByLabelText("Notes (optional)"), "referred");
    await user.click(screen.getByRole("button", { name: "Provision account" }));

    await waitFor(() =>
      expect(createBundle).toHaveBeenCalledWith({
        username: "lotti_user",
        displayName: "Ada",
        notes: "referred",
      }),
    );
  });

  it("keeps submit disabled until a username is entered", () => {
    render(<CreateBundlePage />);

    expect(
      screen.getByRole("button", { name: "Provision account" }),
    ).toBeDisabled();
  });

  it("surfaces a server error and does not reveal a bundle", async () => {
    createBundle.mockRejectedValue(new Error("username already provisioned"));
    const user = userEvent.setup();
    render(<CreateBundlePage />);

    await user.type(screen.getByLabelText("Username"), "taken");
    await user.click(screen.getByRole("button", { name: "Provision account" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "username already provisioned",
    );
    expect(screen.queryByLabelText("Provisioning bundle")).toBeNull();
  });

  it("returns to the form after the bundle is acknowledged", async () => {
    createBundle.mockResolvedValue(RESPONSE);
    const user = userEvent.setup();
    render(<CreateBundlePage />);

    await user.type(screen.getByLabelText("Username"), "lotti_user");
    await user.click(screen.getByRole("button", { name: "Provision account" }));
    await screen.findByLabelText("Provisioning bundle");
    await user.click(screen.getByRole("checkbox"));
    await user.click(screen.getByRole("button", { name: "Done" }));

    expect(screen.getByLabelText("Username")).toHaveValue("");
  });
});
