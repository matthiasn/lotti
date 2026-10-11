# ADR 0137: A Media Request Names Its Likely Holder, and a Short Copy Is Fetched Again

- Status: Accepted
- Date: 2026-10-11

## Context

A device that loads an image or audio entry whose file is missing asks the
room for it with one `SyncMediaRequest` (ADR 0130). Every device that holds
the blob answers, so a request in a room of five devices could upload the same
file four times. ADR 0135 accepted that: choosing one responder seemed to need
an origin host, which journal entries do not carry.

The sequence log has one. Each version of an entry received or backfilled is
recorded with the host that sent it (`originating_host_id`). The device that
most recently sent a version of an entry held its file then, or the file
would not have been sent with it.

Separately, the same loader treated any non-empty file as present. A copy cut
short by an interrupted write, or kept by a build that never replaced an
existing file, stayed short. Only a manual deep-backfill round compared sizes
and fetched it again (ADR 0131).

## Decision

- **A first request names a holder per entry.** `MediaRepairService` looks up
  the latest sender of each entry other than itself
  (`SyncDatabase.latestSenderOfEntry`) and sends the mapping in
  `SyncMediaRequest.holders`. An entry with no known sender is not named.
- **A named entry is answered only by its holder.** `MediaRequestHandler`
  skips an entry that the request addresses to another host. An entry that
  names nobody is answered by every holder, as before.
- **A retry asks everyone.** The guess can be wrong, or its device away: a
  second attempt for an entry carries no holder. A lookup that fails is
  logged and treated as no guess.
- **A copy shorter than its attachment declares is fetched again.**
  `SmartJournalEntityLoader` compares the file's length with the size the
  attachment event declares (`declaredMediaSize`, the plaintext length) and
  downloads it again when it is shorter, as `AttachmentIngestor` already does
  for an incoming file.

## Consequences

- A blob is usually uploaded once per request instead of once per holder. A
  wrong guess costs one debounce window and a broadcast retry.
- Builds before this change ignore `holders` and answer every entry they hold;
  in a room with such a device, duplicates fall but do not disappear.
- A short copy is healed on load whenever the attachment event is still
  indexed, without waiting for a deep-backfill round. Same-size corruption
  stays out of scope.
- A truncated copy held by a build before 1.1.34 heals only when that device
  updates: an old build keeps a file it already holds, whatever arrives
  (ADR 0131). Current devices no longer depend on such a copy, since they
  detect a short file of their own and ask for it again.
- This supersedes the consequence in ADR 0135 that every holder answers a
  media request.
