import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import BundleReveal from "../components/BundleReveal";
import type { CreateBundleResponse } from "../types";

const RESULT: CreateBundleResponse = {
  bundle: "eyJ2IjoyLCJraW5kIjoicHJvdmlzaW9uZWQifQ",
  user: {
    bundle_id: "b-1",
    username: "lotti_user",
    user_mxid: "@lotti_user:example.com",
    home_server: "https://matrix.example.com",
    server_name: "example.com",
    room_id: "!room:example.com",
    display_name: "Lotti Sync (lotti_user)",
    status: "unused",
    payment_status: "unknown",
    bundle_fingerprint: "a".repeat(64),
    created_at: "2026-08-07T10:00:00+00:00",
    first_login_at: null,
    rotated_at: null,
    revoked_at: null,
    last_seen_at: null,
    last_polled_at: null,
    notes: "",
    retention_days: null,
    retention_exempt: false,
  },
};

describe("BundleReveal", () => {
  it("warns that the bundle is shown only once", () => {
    render(<BundleReveal result={RESULT} onDismiss={vi.fn()} />);

    expect(screen.getByRole("alert")).toHaveTextContent(/shown once/i);
    expect(screen.getByRole("alert")).toHaveTextContent(/never stored/i);
  });

  it("shows the bundle string for copying", () => {
    render(<BundleReveal result={RESULT} onDismiss={vi.fn()} />);

    expect(screen.getByLabelText("Provisioning bundle")).toHaveValue(
      RESULT.bundle,
    );
  });

  it("keeps Done disabled until the admin acknowledges saving it", async () => {
    const user = userEvent.setup();
    render(<BundleReveal result={RESULT} onDismiss={vi.fn()} />);
    const done = screen.getByRole("button", { name: "Done" });

    expect(done).toBeDisabled();
    await user.click(screen.getByRole("checkbox"));

    expect(done).toBeEnabled();
  });

  it("dismisses only after acknowledgement", async () => {
    const user = userEvent.setup();
    const onDismiss = vi.fn();
    render(<BundleReveal result={RESULT} onDismiss={onDismiss} />);

    await user.click(screen.getByRole("checkbox"));
    await user.click(screen.getByRole("button", { name: "Done" }));

    expect(onDismiss).toHaveBeenCalledOnce();
  });

  it("copies the bundle to the clipboard and confirms", async () => {
    const user = userEvent.setup();
    // Must come after setup(): userEvent installs its own clipboard stub, and
    // jsdom exposes navigator.clipboard as a getter-only property.
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "clipboard", {
      value: { writeText },
      configurable: true,
    });
    render(<BundleReveal result={RESULT} onDismiss={vi.fn()} />);

    await user.click(screen.getByRole("button", { name: "Copy bundle" }));

    expect(writeText).toHaveBeenCalledWith(RESULT.bundle);
    expect(screen.getByRole("button", { name: "Copied" })).toBeInTheDocument();
  });

  it("says so plainly when the clipboard is unavailable", async () => {
    const user = userEvent.setup();
    // What the deployed app actually sees: served over plain HTTP, so the
    // clipboard API is absent. Silently doing nothing here loses a bundle that
    // exists nowhere else the moment the admin acknowledges and dismisses.
    Object.defineProperty(navigator, "clipboard", {
      value: undefined,
      configurable: true,
    });
    render(<BundleReveal result={RESULT} onDismiss={vi.fn()} />);

    await user.click(screen.getByRole("button", { name: "Copy bundle" }));

    expect(screen.getByText(/copy it manually/i)).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Copied" }),
    ).not.toBeInTheDocument();
  });

  it("reports a rejected clipboard write instead of claiming success", async () => {
    const user = userEvent.setup();
    Object.defineProperty(navigator, "clipboard", {
      value: { writeText: vi.fn().mockRejectedValue(new Error("denied")) },
      configurable: true,
    });
    render(<BundleReveal result={RESULT} onDismiss={vi.fn()} />);

    await user.click(screen.getByRole("button", { name: "Copy bundle" }));

    expect(screen.getByText(/denied/)).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Copied" }),
    ).not.toBeInTheDocument();
  });

  it("shows the account and room it provisioned", () => {
    render(<BundleReveal result={RESULT} onDismiss={vi.fn()} />);

    expect(screen.getByText("@lotti_user:example.com")).toBeInTheDocument();
    expect(screen.getByText("!room:example.com")).toBeInTheDocument();
  });
});
