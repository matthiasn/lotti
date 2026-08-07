import type { BundleStatus, PaymentStatus } from "../types";

const BUNDLE_LABELS: Record<BundleStatus, string> = {
  unused: "Unused",
  redeemed: "Redeemed",
  rotated: "Rotated",
  revoked: "Revoked",
};

const PAYMENT_LABELS: Record<PaymentStatus, string> = {
  unknown: "Unknown",
  paying: "Paying",
  non_paying: "Not paying",
  complimentary: "Complimentary",
};

/** Coloured pill for a bundle's redemption status. */
export function BundleStatusBadge({ status }: { status: BundleStatus }) {
  return (
    <span className={`badge badge--${status}`} title={describe(status)}>
      {BUNDLE_LABELS[status]}
    </span>
  );
}

/** Coloured pill for a user's contribution status. */
export function PaymentStatusBadge({ status }: { status: PaymentStatus }) {
  return (
    <span className={`badge badge--payment-${status}`}>
      {PAYMENT_LABELS[status]}
    </span>
  );
}

function describe(status: BundleStatus): string {
  switch (status) {
    case "unused":
      return "No sign-in observed yet — the bundle is still live";
    case "redeemed":
      return "Signed in, but rotation not yet confirmed";
    case "rotated":
      return "The client confirmed it replaced the temporary password";
    case "revoked":
      return "Retired by an admin";
  }
}
