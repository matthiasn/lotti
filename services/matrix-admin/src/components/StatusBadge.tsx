import type { BundleStatus, PaymentStatus } from "../types";

/**
 * Human labels for each status.
 *
 * Exported so option lists can be derived from them rather than restated —
 * otherwise adding a status means editing the union, the labels and every
 * dropdown, which is how a select ends up showing `non_paying` beside a pill
 * reading "Not paying".
 */
export const BUNDLE_LABELS: Record<BundleStatus, string> = {
  unused: "Unused",
  redeemed: "Redeemed",
  rotated: "Rotated",
  revoked: "Revoked",
};

export const PAYMENT_LABELS: Record<PaymentStatus, string> = {
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

/**
 * Contribution status as an editable pill.
 *
 * A single control rather than a pill beside a dropdown: the two showed the
 * same value twice, and only one of them was readable.
 */
export function PaymentStatusSelect({
  status,
  label,
  onChange,
}: {
  status: PaymentStatus;
  /** Accessible name, since the visible pill carries no label text. */
  label: string;
  onChange: (next: PaymentStatus) => void;
}) {
  const id = `payment-${label.replace(/\s+/g, "-")}`;
  return (
    <>
      <label htmlFor={id} className="visually-hidden">
        {label}
      </label>
      {/* The wrapper carries the status colour so the caret, drawn with
          currentColor, tints to match instead of staying a fixed grey. */}
      <span className={`pill-select badge--payment-${status}`}>
        {/* Invisible sizer: a select with appearance:none sizes itself to its
            widest option and ignores the caret padding, which both clipped
            "Complimentary" and left a gap after short labels. This mirrors the
            selected label so the pill hugs exactly the text it shows. */}
        <span className="pill-select__sizer" aria-hidden="true">
          {PAYMENT_LABELS[status]}
        </span>
        <select
          id={id}
          value={status}
          onChange={(event) => onChange(event.target.value as PaymentStatus)}
        >
          {(Object.keys(PAYMENT_LABELS) as PaymentStatus[]).map((option) => (
            <option key={option} value={option}>
              {PAYMENT_LABELS[option]}
            </option>
          ))}
        </select>
      </span>
    </>
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
