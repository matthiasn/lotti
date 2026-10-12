# ADR 0137: A Short Media Copy Is Fetched Again, and Other Holders Wait for the Likely One

- Status: Accepted
- Date: 2026-10-11

## Context

`SmartJournalEntityLoader` treated any non-empty media file as present. A
copy cut short by an interrupted write, or kept by a build that never
replaced an existing file, stayed short. Only a manual deep-backfill round
compared sizes and fetched it again (ADR 0131).

A device that loads an image or audio entry whose file is missing asks the
room for it with one `SyncMediaRequest` (ADR 0130). Every device that holds
the blob answered at once, so a request in a room of five devices could
upload the same file four times. ADR 0135 accepted that.

Addressing the request to a single holder alone is not safe. The broadcast
did two jobs:

- it reaches every holder, so one offline device cannot stall a repair;
- it lets the largest answer win, because `AttachmentIngestor` writes only a
  larger file. That is what replaces a short copy held by a build before
  1.1.34, which an old holder keeps and sends as it is.

## Decision

- **A copy shorter than its attachment declares is fetched again.** The
  loader compares the file's length with the size the attachment event
  declares (`declaredMediaSize`, the plaintext length) and downloads it again
  when it is shorter, as `AttachmentIngestor` already does for an incoming
  file.
- **A first request names a likely holder per entry.** `MediaRepairService`
  looks up the host that most recently sent this device a version of the
  entry (`SyncDatabase.latestSenderOfEntry`, from the sequence log's
  `originating_host_id`) and sends it in `SyncMediaRequest.holders`. An entry
  with no known sender names nobody, and a retry names nobody.
- **The named holder answers at once; the others wait, and answer unless
  they see a complete answer.** `MediaRequestHandler` holds back its answer
  for an entry addressed to another host for `SyncTuning.mediaAnswerGrace`.
  It drops that answer only when an attachment for the same file arrives in
  the room declaring a size at least as large as its own copy
  (`AttachmentIndex.attachmentsObserved`). A smaller or unsized answer does
  not count, so a complete copy still follows a short one.

## Consequences

- A blob is usually uploaded once per request. When the named holder is
  offline or lacks the file, the others answer after the grace, as they did
  before, two minutes later.
- A short copy is healed on load whenever the attachment event is still
  indexed, without waiting for a deep-backfill round. Same-size corruption
  stays out of scope.
- Builds before this change ignore `holders` and answer at once. A current
  holder still answers after them when their copy is the shorter one.
- An attachment event for the same file first seen during a catch-up, from
  long before the request, can count as the answer and cancel a held-back
  one. The requester's next attempt names nobody, so every holder answers it.
- A truncated copy held by a build before 1.1.34 heals only when that device
  updates: an old build keeps a file it already holds, whatever arrives
  (ADR 0131). Current devices no longer depend on such a copy.
- This supersedes the consequence in ADR 0135 that every holder answers a
  media request at once.
