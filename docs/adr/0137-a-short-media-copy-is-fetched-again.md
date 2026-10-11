# ADR 0137: A Short Media Copy Is Fetched Again, and Media Requests Stay Broadcast

- Status: Accepted
- Date: 2026-10-11

## Context

`SmartJournalEntityLoader` treated any non-empty media file as present. A
copy cut short by an interrupted write, or kept by a build that never
replaced an existing file, stayed short. Only a manual deep-backfill round
compared sizes and fetched it again (ADR 0131).

A device that loads an image or audio entry whose file is missing asks the
room for it with one `SyncMediaRequest` (ADR 0130). Every device that holds
the blob answers, so a request in a room of five devices can upload the same
file four times. ADR 0135 accepted that.

## Decision

- **A copy shorter than its attachment declares is fetched again.** The
  loader compares the file's length with the size the attachment event
  declares (`declaredMediaSize`, the plaintext length) and downloads it again
  when it is shorter, as `AttachmentIngestor` already does for an incoming
  file.
- **Media requests stay broadcast, and every holder answers.** Addressing a
  first request to one likely holder — the host that last sent a version of
  the entry, from the sequence log — was built and withdrawn in review. The
  broadcast does two jobs that addressing gives up:
  - it reaches every holder, so a request does not stall when the one named
    device is offline: the service sends no follow-up of its own and only
    asks again when the entry is loaded again;
  - it lets the largest answer win, because `AttachmentIngestor` writes only
    a larger file. That is what replaces a short copy held by a build before
    1.1.34, which an old holder keeps and sends as it is.
  Making addressing safe would take follow-up timers, a presence check on
  the requester and a size the requester can trust for the named holder's
  copy, which it does not have.

## Consequences

- A short copy is healed on load whenever the attachment event is still
  indexed, without waiting for a deep-backfill round. Same-size corruption
  stays out of scope.
- Duplicate uploads in answer to one media request remain. They cost
  bandwidth, not data, and they are the redundancy the two points above rely
  on.
- A truncated copy held by a build before 1.1.34 heals only when that device
  updates: an old build keeps a file it already holds, whatever arrives
  (ADR 0131). Current devices no longer depend on such a copy, since they
  detect a short file of their own and ask for it again, and a complete
  answer from another holder replaces a short one.
