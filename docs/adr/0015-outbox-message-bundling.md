# ADR 0015 — Outbox message bundling

Status: Accepted
Date: 2026-04-30
Related: ADR 0013 (outbox priority queue); PR #3009 (agent wake sync
bundling); closed PR #2957 (media-attachment bundling, retired).

## Context

Bursty workloads — agent suggestion fan-out, checklist-item creation, sync
backfill replay — push tens to hundreds of small text-only sync messages
through the outbox in a short window. Pre-bundling, every row produced one
Matrix event, so the wire-event count tracked the row count linearly. Each
event paid the same per-message overhead (Matrix encryption, transmit, ack,
receiver inbox scan), which dominated end-to-end latency on slow networks.

PR #3009 introduced wake-cycle bundling for agent writes (`SyncAgentBundle`),
reducing one specific source. We extend the same pattern to the outbox as a
whole so any bursty source benefits.

## Decision

Bundle on the **dequeue side** of the outbox.

`OutboxProcessor.processQueue()` reads a cached bundle-size cap each pass.
When the cap is `1` (legacy default) the legacy single-row claim path runs
unchanged. When the cap is `> 1`, `OutboxRepository.claimNextBatch(maxSize)`
returns either:

- a single-element list `[head]` when the head row carries a media attachment
  (`filePath != null`), so attachments still travel alone, or
- the maximal prefix of consecutive text-only rows in
  `(priority, createdAt)` order, capped at `maxSize`, stopping before the
  next attachment.

The processor wraps a multi-row batch in `SyncMessage.outboxBundle(children)`
and calls `markSentBatch` / `markRetryBatch` (single-transaction batch
updates) after the send. Single-row batches keep the legacy
`markSent` / `markRetry` path.

`MatrixMessageSender` always delivers `SyncOutboxBundle` as **file-backed**:
the children are serialized to `/outbox_bundles/<uuid>.json`, uploaded, and
the inline children list is stripped from the text event in favour of a
`jsonPath` reference. Receivers download the sidecar via the existing
`AttachmentIngestor`.

On the receiver, `OutboxBundleUnpacker.prepare` recursively prepares each
child through the existing per-type pipeline (`_prepareForMessage`), and
`OutboxBundleUnpacker.apply` dispatches each prepared child through the
existing per-type apply path. The sequence log records each child's
vector clock individually — there is no bundle-level VC.

Gated by a per-user feature flag, `useOutboxBundlingFlag`, defaulting to
**off**.

## Why dequeue-side and not enqueue-side

Enqueue paths already do per-type merge/dedup/sequence-log work. Touching
them risks vector-clock and ordering bugs. Dequeue-side bundling
- mirrors the proven shape of PR #3009 (buffer → emit one envelope →
  child-iterate on receiver), and
- naturally batches a backfill flood without needing to teach every
  enqueue site about bundling.

## Why a 50-row cap (constant `SyncTuning.outboxBundleMaxSize`)

A 50-message envelope keeps the sidecar JSON well below realistic Matrix
event-size limits even with chatty children, and 50 is comfortably above
the typical agent-suggestion burst (≈10–20). The cap lives in
`SyncTuning` so it can be tuned (validated up to 100 in tests) without a
code change to consumers.

## Why media attachments stay individual

The downstream `AttachmentIngestor` machinery is built around per-event
re-download semantics with VC-dominance gating. Bundling attachments
would require redesigning that flow (see closed PR #2957). Out of scope
here. "Attachment" in this ADR means **media attachment**; the JSON
sidecar that carries bundle children is technically also a Matrix
attachment, but it is bundle-internal infrastructure, not a user file.

## Why a flag, default off

A receiver running an older build that does not understand
`SyncOutboxBundle` will log-and-skip the unknown variant — fail-soft, but
the user-visible result is silent data loss for the bundled children
until the receiver upgrades. Default-off lets us ship the receiver
unpacker first in one release, leave it baking, and flip the default
later. An emergency kill-switch is preserved either way.

## Backfilling `originatingHostId` on bundle children

Children inside a `SyncOutboxBundle` skip the top-level
`MatrixMessageSender._ensureOriginatingHostId` call. We backfill each
child individually before the file is written, so a bundle-delivered
journal entity or entry link carries the same metadata as the same
message delivered standalone — receiver-side sequence tracking does not
regress.

## Path-traversal hardening

`SyncOutboxBundle.jsonPath` arriving from outside this process (e.g. an
echoed Matrix message during a retry, or a tampered payload) is gated:
only paths that start with `/outbox_bundles/` and contain no `.` or `..`
segments are honoured for the disk write. Any other value falls back to
a freshly minted UUID-based path and the rejection is logged.

## Per-child fault isolation on the receiver

`OutboxBundleUnpacker` rethrows any `IOException`
(`FileSystemException`, `SocketException`, `HttpException`,
`TlsException`, `WebSocketException`) from a child's prepare call so the
parent pipeline can retry the whole bundle later — partial application
would leave gaps in the sequence log. All other exceptions on a single
child are logged and skipped; the remaining children still apply.

## Consequences

- One Matrix event per up-to-50 small text-only outbox rows, with a
  single sidecar attachment carrying the children. Wire volume drops
  ~10× on bursty workloads.
- Bundling never crosses the boundary defined by a media-attachment
  row, so attachment delivery is byte-for-byte unchanged.
- Receiver running with bundling enabled by the sender must include
  `OutboxBundleUnpacker` (Step 6 of the implementation plan) — guaranteed
  by the rollout sequencing above.
- Sequence-log semantics are unchanged: each child gets its own VC entry,
  so backfill, gap detection, and retire flows continue to operate at
  child granularity.

## Alternatives considered

- **Enqueue-side bundling** — rejected for risk, see "Why dequeue-side"
  above.
- **Inline-only delivery** for small bundles — rejected for uniformity;
  receivers would need two delivery shapes. Followup if profiling shows
  the sidecar round-trip dominates for tiny bundles.
- **Bundle-level vector clock** — rejected: backfill, retire, gap
  detection, and the existing supersession check all operate on child
  payload identity. A bundle-level VC would need a parallel set of
  resolution paths.
