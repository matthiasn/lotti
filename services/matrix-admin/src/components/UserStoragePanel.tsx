import { useEffect, useState } from "react";
import { errorMessage } from "../api/client";
import { getUsage, purgeRoom, updateBundle } from "../api/provisioning";
import type { ProvisionedUser, Usage } from "../types";

/** Format a byte count for display, in binary units. */
export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  const units = ["KiB", "MiB", "GiB", "TiB"];
  let value = bytes / 1024;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value.toFixed(value < 10 ? 1 : 0)} ${units[unit]}`;
}

/**
 * Live storage figures for one account, plus the history purge action.
 *
 * Usage is read on expand rather than with the roster: it hits the Synapse
 * admin API once per user, so loading it for every row would turn one page
 * render into an N+1 of remote calls.
 */
export default function UserStoragePanel({
  user,
  onUserChange,
}: {
  user: ProvisionedUser;
  onUserChange?: (updated: ProvisionedUser) => void;
}) {
  const [usage, setUsage] = useState<Usage | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [purging, setPurging] = useState(false);
  const [purgeNote, setPurgeNote] = useState<string | null>(null);
  // Blank means "whatever the service is configured to apply". A number here is
  // an explicit override for this one run. A hardcoded default would silently
  // disagree with RETENTION_DAYS and delete more history than policy allows.
  const [retentionOverride, setRetentionOverride] = useState("");
  const [includeMedia, setIncludeMedia] = useState(true);
  const [savingPolicy, setSavingPolicy] = useState(false);

  useEffect(() => {
    let cancelled = false;
    getUsage(user.bundle_id)
      .then((data) => {
        if (!cancelled) setUsage(data);
      })
      .catch((caught) => {
        if (!cancelled) setError(errorMessage(caught));
      });
    return () => {
      cancelled = true;
    };
  }, [user.bundle_id]);

  async function savePolicy(input: {
    retentionDays?: number;
    retentionExempt?: boolean;
    clearRetentionOverride?: boolean;
  }) {
    setSavingPolicy(true);
    setError(null);
    try {
      // Must not be written as `onUserChange?.(await updateBundle(...))`:
      // optional chaining short-circuits the whole call expression, so with no
      // callback passed the arguments are never evaluated and the save
      // silently does nothing.
      const updated = await updateBundle(user.bundle_id, input);
      onUserChange?.(updated);
    } catch (caught) {
      setError(errorMessage(caught));
    } finally {
      setSavingPolicy(false);
    }
  }

  async function handlePurge() {
    setPurging(true);
    setError(null);
    setPurgeNote(null);
    try {
      const trimmed = retentionOverride.trim();
      const result = await purgeRoom(
        user.bundle_id,
        trimmed === "" ? undefined : Number(trimmed),
        includeMedia,
      );
      setPurgeNote(
        result.include_media
          ? `Reclaimed ${formatBytes(result.bytes_freed)} — ${result.media_deleted} media file(s) deleted, history purged older than ${result.retention_days} days.`
          : `History purged older than ${result.retention_days} days. No media deleted.`,
      );
      // Usage is now stale; re-read so the figures reflect the reclamation.
      setUsage(await getUsage(user.bundle_id));
    } catch (caught) {
      setError(errorMessage(caught));
    } finally {
      setPurging(false);
    }
  }

  if (error && !usage) {
    return (
      <p role="alert" className="error-text">
        {error}
      </p>
    );
  }

  if (!usage) return <p className="muted">Loading usage…</p>;

  return (
    <div className="storage-panel">
      {/* "Media" is what the homeserver holds right now, which a sweep drives
          to near zero. "Lifetime" adds back what past purges reclaimed, so a
          long-standing heavy user does not read as lighter than a newcomer. */}
      <div className="stat-grid stat-grid--compact">
        <Figure label="Media now" value={formatBytes(usage.media_length_bytes)} />
        <Figure
          label="Lifetime"
          value={formatBytes(usage.lifetime_media_bytes)}
          hint={
            usage.purged_media_bytes > 0
              ? `${formatBytes(usage.purged_media_bytes)} purged in ${usage.purged_media_count} file(s)`
              : "nothing purged yet"
          }
        />
        <Figure label="Files" value={String(usage.media_count)} />
        <Figure label="Devices" value={String(usage.device_count)} />
        <Figure
          label="Active"
          value={usage.active_days === null ? "—" : `${usage.active_days}d`}
        />
      </div>

      {/* Scheduled policy: what the automatic sweep will do to this user,
          as distinct from the manual one-off purge below. */}
      <div className="policy-row">
        <span className="policy-row__title">Automatic sweep</span>
        <label htmlFor={`policy-${user.bundle_id}`} className="visually-hidden">
          Retention window for {user.username}
        </label>
        <input
          id={`policy-${user.bundle_id}`}
          type="number"
          min={7}
          max={3650}
          placeholder="default"
          disabled={user.retention_exempt || savingPolicy}
          defaultValue={user.retention_days ?? ""}
          onBlur={(event) => {
            const raw = event.target.value.trim();
            if (raw === "" && user.retention_days !== null) {
              void savePolicy({ clearRetentionOverride: true });
            } else if (raw !== "" && Number(raw) !== user.retention_days) {
              void savePolicy({ retentionDays: Number(raw) });
            }
          }}
        />
        <span className="muted">
          {user.retention_days === null
            ? `days — blank follows the service default (${usage.retention_days_default}d)`
            : "days — pinned for this user"}
        </span>
        <input
          id={`exempt-${user.bundle_id}`}
          className="checkbox__box"
          type="checkbox"
          checked={user.retention_exempt}
          disabled={savingPolicy}
          onChange={(event) =>
            void savePolicy({ retentionExempt: event.target.checked })
          }
        />
        <label htmlFor={`exempt-${user.bundle_id}`} className="checkbox">
          Never sweep
        </label>
      </div>

      <div className="purge-row">
        <span className="policy-row__title">Purge now</span>
        <label htmlFor={`retention-${user.bundle_id}`}>Keep</label>
        <input
          id={`retention-${user.bundle_id}`}
          type="number"
          min={7}
          max={3650}
          placeholder={String(usage.retention_days_effective)}
          value={retentionOverride}
          onChange={(event) => setRetentionOverride(event.target.value)}
        />
        <span className="muted">
          days{retentionOverride.trim() === "" ? " (this user's policy)" : ""}
        </span>
        <input
          id={`media-${user.bundle_id}`}
          className="checkbox__box"
          type="checkbox"
          checked={includeMedia}
          onChange={(event) => setIncludeMedia(event.target.checked)}
        />
        <label htmlFor={`media-${user.bundle_id}`} className="checkbox">
          Delete media too
        </label>
        <button type="button" onClick={handlePurge} disabled={purging}>
          {purging ? "Reclaiming…" : "Reclaim space"}
        </button>
      </div>

      {/* Events and media are separate stores in Synapse, and the files are
          the bulk. Saying so stops "purge" being read as "frees the number
          above" when the box is unticked. */}
      <p className="muted purge-caveat">
        {includeMedia ? (
          <>
            Deletes room events <strong>and</strong> the media files older than
            the window — media is what actually frees disk. Devices keep their
            local copies, and a peer still holding a file can restore it.
          </>
        ) : (
          <>
            History only: removes room events but leaves all{" "}
            {formatBytes(usage.media_length_bytes)} of media in place. Expect
            little disk to be freed.
          </>
        )}
      </p>

      {purgeNote && (
        <p role="status" className="purge-note">
          {purgeNote}
        </p>
      )}
      {error && (
        <p role="alert" className="error-text">
          {error}
        </p>
      )}
    </div>
  );
}

function Figure({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint?: string;
}) {
  return (
    <div className="stat">
      <div className="stat__value">{value}</div>
      <div className="stat__label">{label}</div>
      {hint && <div className="stat__hint">{hint}</div>}
    </div>
  );
}
