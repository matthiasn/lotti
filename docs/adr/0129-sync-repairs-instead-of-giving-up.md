# ADR 0129: Sync Repairs Instead of Giving Up

- Status: Accepted
- Date: 2026-10-10

## Context

Four sync paths ended in a state nothing would leave on its own:

- **Catch-up gave up.** `BridgeCoordinator` retried an incomplete walk
  three times, ten seconds apart, then logged
  `queue.bridge.incomplete.giveUp` and waited for the next limited sync. On
  a quiet room that might not come, and the gap stayed until it did.
- **Preferences had no repair.** The theme, the Daily OS greeting name and
  config flags are sent once per change and kept under last-writer-wins on
  a stamp. A lost message stayed lost until the setting changed again:
  neither backfill nor "Send settings" carried them.
- **An undecodable event was skipped for good.** An event that did not
  decode as a sync message, such as a saved filter carrying a value from a
  newer sender, was skipped as `permanentSkip`. Nothing resurrected it, so
  the build that later learned the message never saw it.
- **A single message over the inline limit stayed in error.** The SDK
  refuses an event body over 60 KB, and the outbox marked such a row
  failed. Backfill requests queued before #4593 split them hit the same
  wall.

## Decision

- **Catch-up backs off instead of stopping.** The first three retries keep
  their ten-second wait; each later one waits twice as long as the last, up
  to five minutes, until a walk completes. Once the quick retries are spent
  the backfill completion hook runs after each pass, so a catch-up that
  keeps failing does not also hold backfill back.
- **"Send settings" re-sends preferences.** A `preferences` step sends the
  theme, the greeting name and every versioned config flag with the stamp
  its stored value holds. Receivers keep the newer value, so a resend never
  overwrites a newer setting. A value without a stamp is left out, since a
  stamp of 0 would rank it by content rather than time.
- **Undecodable events have their own skip reason.** The apply adapter
  returns `ApplyOutcome.undecodable`, the worker records the reason
  `undecodable`, and the queue resurrects those rows each time it starts,
  bounded by the existing resurrection cap.
- **An inline body too large travels as a one-child bundle.** The size
  error says when the inline body was the limit; the outbox then sends the
  message once more as the only child of an outbox bundle, whose gzipped
  manifest upload admits up to 8 MiB. A bundle, file or manifest over its
  own limit is still dropped.

## Consequences

- A device whose catch-up cannot complete keeps a request in flight at most
  every five minutes, for as long as the failure lasts.
- "Send settings" sends a few more messages: one theme, one greeting, one
  per changed flag.
- An event no build can decode is retried at each start until the
  resurrection cap retires it.
- A message larger than 8 MiB compressed, or one owing a file over the
  attachment limit, still cannot travel; that needs a chunked payload.
