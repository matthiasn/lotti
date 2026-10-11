# ADR 0135: Ordering and Restores Hold

- Status: Accepted
- Date: 2026-10-11

## Context

A sweep of the sync code after #4760 found several places where the order
of versions, or the uniqueness of counters, was weaker than the rest of the
protocol assumes. It also found two specs that no longer describe the code.

- **A bundle claimed versions it did not carry.** A single send refuses a
  journal payload whose stored row does not cover the queued version
  (ADR 0086). Inside a bundle, the same case adopted the row's clock, so
  the manifest named counters the payload did not hold.
- **A definition's receipt was written before its commit.** The queue
  adapter wrapped entity definitions in an outer journal transaction, and
  the handler wrote the sequence receipt inside it. Links and journal
  entities had already moved off that pattern.
- **Notification content was ordered by wall clock only.** A peer with a
  fast clock, or a late copy of the template, beat the agent's re-wording
  made after it, on every device.
- **Restores broke counter uniqueness.**
  - The next counter lives in `SettingsDb`. Settings restored from an older
    backup handed out counters a payload already carried.
  - A sync database restored from an older backup lacks the rows written
    after its snapshot, and an own counter with no row is answered as
    burned. Peers then gave up on payloads this device still held.
- **Media self-repair forgot its cap.** The per-entry attempt count lived in
  memory, so every launch asked again for blobs no peer holds.
- **Specs drifted.**
  - `DefinitionClocks.tla` modelled a manual migration on one host, while
    every device repairs clockless rows at startup (ADR 0130).
  - `Outbox.tla` does not model size limits, yet its README did not say so.

## Decision

- **A bundle child must be carried.** If neither the row nor an open
  conflict covers the queued version and every covered clock, the bundle
  fails into the outbox retry. A single send serves an open conflict under
  the same rule.
- **A definition owns its commit.** The adapter no longer wraps definitions.
  The upsert has its own transaction, so the receipt follows the commit.
- **Notification content follows its own clock.** Every create and
  re-wording stamps `contentVectorClock` with the write's clock, and state
  patches leave it alone. The row clock cannot order content: it also absorbs
  lifecycle patches, so a mark-seen that reached a peer before the re-wording
  would make the stale words look newer. Content is the maximum of one total
  order: the content rank (each counter of the content clock plus one,
  summed, which grows along every causal step), then `updatedAt`, then
  canonical content. Content that follows the other therefore wins, and
  every device settles on the same words whatever order three or more
  versions arrive in. "Causal first, timestamp for concurrent versions" is
  not associative: merging A with a concurrent B first could keep A against
  a C that follows it. The merged row keeps the winner's own content clock,
  and a row written before the field existed ranks below any with one.
- **Counters survive restores.**
  - At startup `VectorClockService` raises the next counter above the
    highest counter of this host that the sequence log records.
  - After a sync database restore, which leaves a `sync.sqlite.restored`
    marker, the sequence log population runs once more. It records every
    counter the stored payloads carry, notifications, consumption events
    and entity definitions included.
  - Reservations wait for that population pass, and the catch-up runs again
    after it. Settings and sync database restored from the same old backup
    would otherwise let a reservation reuse a counter that only a stored
    payload records.
- **The media repair cap is persisted** in `SettingsDb`, once the request
  is queued, so a failed enqueue costs no attempt.
- **Specs.**
  - `DefinitionClocks.tla` models the repair as `Repair(h)`, weakly fair on
    every host under `RepairAtStartup`. It is re-enabled whenever a host
    stores another clockless row. `ConvergesWithoutUser` states that hosts
    converge without any user action.
  - The `Outbox` README now lists size limits among what the model leaves
    out.

## Consequences

- A bundle with an uncovered child is retried like any failed send, and its
  rows can reach the retry cap, after which the drained queue retries them
  (ADR 0132).
- Every holder of a blob still answers a media request. Duplicates cost
  bandwidth, not data. Choosing one responder would need an origin host,
  which journal entries do not carry.
- A sync database restored from a backup runs one full population pass at
  the next start.
