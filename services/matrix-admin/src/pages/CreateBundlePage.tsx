import { useState, type FormEvent } from "react";
import { createBundle } from "../api/provisioning";
import { errorMessage } from "../api/client";
import BundleReveal from "../components/BundleReveal";
import type { CreateBundleResponse } from "../types";

/** Admin form that provisions an account and reveals its bundle once. */
export default function CreateBundlePage() {
  const [username, setUsername] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [notes, setNotes] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<CreateBundleResponse | null>(null);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      setResult(await createBundle({ username, displayName, notes }));
      setUsername("");
      setDisplayName("");
      setNotes("");
    } catch (caught) {
      setError(errorMessage(caught));
    } finally {
      setSubmitting(false);
    }
  }

  if (result) {
    return <BundleReveal result={result} onDismiss={() => setResult(null)} />;
  }

  return (
    <section className="card">
      <h1>Provision a sync account</h1>
      <p className="muted">
        Creates the Matrix account and its encrypted sync room, then returns a
        one-time bundle for the user to paste into Lotti.
      </p>

      <form onSubmit={handleSubmit}>
        <label htmlFor="username">Username</label>
        <input
          id="username"
          value={username}
          required
          onChange={(event) => setUsername(event.target.value)}
          placeholder="lotti_sync_user42"
          aria-describedby="username-help"
        />
        <small id="username-help" className="muted">
          Lowercase letters, digits, dot, underscore or hyphen. 3–64 characters.
        </small>

        <label htmlFor="displayName">Display name (optional)</label>
        <input
          id="displayName"
          value={displayName}
          onChange={(event) => setDisplayName(event.target.value)}
          placeholder="Lotti Sync (lotti_sync_user42)"
        />

        <label htmlFor="notes">Notes (optional)</label>
        <textarea
          id="notes"
          value={notes}
          rows={3}
          onChange={(event) => setNotes(event.target.value)}
          placeholder="Who this is for, how they were referred…"
        />

        {error && (
          <p role="alert" className="error-text">
            {error}
          </p>
        )}

        <button type="submit" disabled={submitting || !username}>
          {submitting ? "Provisioning…" : "Provision account"}
        </button>
      </form>
    </section>
  );
}
