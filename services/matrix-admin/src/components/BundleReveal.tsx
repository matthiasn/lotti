import { useState } from "react";
import type { CreateBundleResponse } from "../types";

/**
 * Shows a freshly created bundle.
 *
 * The bundle contains a live password and is never persisted server-side, so
 * this is the only time it can be read. The UI says so plainly and makes the
 * user acknowledge before it disappears — an accidental navigation here means
 * revoking the record and provisioning a new account.
 */
export default function BundleReveal({
  result,
  onDismiss,
}: {
  result: CreateBundleResponse;
  onDismiss: () => void;
}) {
  const [copied, setCopied] = useState(false);
  const [acknowledged, setAcknowledged] = useState(false);

  async function copy() {
    await navigator.clipboard.writeText(result.bundle);
    setCopied(true);
  }

  return (
    <section className="card card--warning" aria-labelledby="reveal-heading">
      <h2 id="reveal-heading">Bundle for {result.user.username}</h2>

      <p role="alert" className="warning-text">
        This is shown once. It is never stored on the server. Copy it now — if
        it is lost you must revoke this record and provision a new account.
      </p>

      <textarea
        className="bundle-text"
        readOnly
        rows={4}
        value={result.bundle}
        aria-label="Provisioning bundle"
        onFocus={(event) => event.currentTarget.select()}
      />

      <dl className="meta">
        <dt>Matrix ID</dt>
        <dd>{result.user.user_mxid}</dd>
        <dt>Sync room</dt>
        <dd>{result.user.room_id}</dd>
        <dt>Fingerprint</dt>
        <dd>
          <code>{result.user.bundle_fingerprint.slice(0, 16)}…</code>
        </dd>
      </dl>

      <div className="actions">
        <button type="button" onClick={copy}>
          {copied ? "Copied" : "Copy bundle"}
        </button>

        <label className="checkbox">
          <input
            type="checkbox"
            checked={acknowledged}
            onChange={(event) => setAcknowledged(event.target.checked)}
          />
          I have saved this bundle
        </label>

        <button type="button" disabled={!acknowledged} onClick={onDismiss}>
          Done
        </button>
      </div>
    </section>
  );
}
