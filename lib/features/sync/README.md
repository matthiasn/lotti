# Sync

## What This Feature Is

Sync is the feature that keeps one user's data in step across that user's
devices.

At a high level:

1. Each device writes local changes to an outbox.
2. The outbox publishes sync messages into an encrypted Matrix room.
3. Other devices read those messages, apply them locally, and advance their
   local view.
4. If a device notices that some counters are missing, it asks for backfill.

The core idea is simple:

- journal entries, entry links, agent entities, and agent links are sent as
  sync messages
- each change carries causal information through vector clocks
- newer state should dominate older state
- if a device missed something, another device should be able to fill the gap

## Main Parts

| Part | What it does |
| --- | --- |
| `outbox/` | Queues local work that still needs to be sent |
| `matrix/` | Sends messages to Matrix and reads them back in order |
| `sequence/` | Tracks `(hostId, counter)` pairs to detect gaps |
| `backfill/` | Requests and answers "I am missing counter X" |
| `ui/` | Settings, outbox monitor, conflicts, stats |

## What Travels Through Sync

The room is not only carrying one kind of message.

It currently carries:

- `SyncJournalEntity`
- `SyncEntryLink`
- `SyncAgentEntity`
- `SyncAgentLink`
- `SyncBackfillRequest`
- `SyncBackfillResponse`
- setup and settings messages such as theme and AI config sync

For journal entities, the sync message itself carries the vector clock.

For agent entities, the sync message can be file-backed:

- the text event points at `jsonPath`
- the actual JSON is uploaded as an attachment
- the receiver resolves the payload from that attachment or local disk

That distinction matters a lot for the current investigation.

## What The Sequence Log Is For

The sequence log is the self-healing layer.

It records which `(hostId, counter)` pairs are known locally so the device can:

- detect gaps
- ask for missing counters
- mark counters as covered by newer payloads
- mark counters as backfilled, deleted, or unresolvable

The intended result is eventual convergence even when messages arrive late or
out of order.

## What Backfill Is For

Backfill exists for the case where a device sees:

- "I received counter 10"
- "I then received counter 12"
- "I never saw counter 11"

In that case the device records counter `11` as missing and broadcasts a
`SyncBackfillRequest`.

Any device that can still explain that counter can answer with:

- the actual payload via normal sync
- a hint mapping the missing counter to a newer covering payload
- a deleted response
- an unresolvable response

## Why There Is A Separate Architecture Document

This README is intentionally the plain-language version.

The detailed engineering map is here:

- [current_architecture.md](./current_architecture.md)

That document covers:

- the actual send and receive pipeline
- how sequence logging and backfill interact
- recent sync-related PRs
- code-backed failure modes
- the current investigation into false gap storms and sync overhead

## Current State Of The Investigation

The sync system does eventually converge in many cases, but the current logs
show much more work than the user action volume should create.

The most recent stabilization pass addressed two concrete failures:

- exact backfill hits are now validated against the payload's current vector
  clock before resend
- missing-marker catch-up now falls back to a bounded tail instead of replaying
  an entire large snapshot
- receive-side signal diagnostics now summarize scheduler pokes per catch-up
  burst and per live-scan pass instead of writing one log line for every raw
  callback
- backfill request paging now walks past already queued oldest rows instead of
  stopping at the first filtered page, and zombie-file cleanup only deletes
  paths that resolve inside the local docs directory

The largest remaining concerns are:

- inbox-side attachment replay: repeated processing for the exact same
  attachment `eventId` is now suppressed unless the local file is missing or
  empty (repair path). The remaining edge case is different attachment events
  that share the same agent payload path, which can still overwrite each other
- agent payload handling that can plausibly combine an older text event with a
  newer attachment version for the same `jsonPath`

The receive-side recovery model is now stricter than before:

- if catch-up cannot re-anchor on the stored Matrix marker but it can page
  back past the stored last-sync timestamp, it now replays that
  timestamp-anchored slice instead of declaring failure and falling straight
  into backfill-driven recovery
- if catch-up can reach neither the stored marker nor the stored timestamp
  boundary, it reports incomplete recovery instead of replaying a fallback
  room tail as if it were exact backlog
- sequence progress is derived from the highest contiguous resolved counter for
  each host, not from the maximum sparse counter present anywhere in the log
- large counter gaps are fully materialized in the sequence log and immediately
  nudged into automatic backfill instead of being truncated to the newest `100`
  rows

Those are documented in detail in
[current_architecture.md](./current_architecture.md) and
[../../docs/implementation_plans/2026-03-13_sender_offline_convergence.md](../../docs/implementation_plans/2026-03-13_sender_offline_convergence.md).
