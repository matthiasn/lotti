# Deep backfill for media — the files behind image and audio entries

Status: **model checked, implemented.** The runtime behaviour is documented in
[sequence log and backfill](../../knowledge/features/sync/sequence-and-backfill.md#files-behind-image-and-audio-entries);
this plan records the gap, the model and how it maps onto the code. It builds
on [the record round](2026-09-27_deep_backfill.md).

## The gap

The record round already sends a record's file when the peer holds no row for
it. It cannot see the other cases, because it compares clocks, and a file is
not part of a record's version:

- **Both devices hold the record at the same version, one lacks the file.** A
  download failed, or the file was lost locally. The clocks are equal, so
  nothing is requested and nothing is pushed.
- **One device holds the file truncated.** An interrupted transfer left a
  non-empty but short file. Worse, the receiver kept any existing non-empty
  file (`AttachmentIngestor`'s fast path), so even a whole copy arriving
  later never replaced it.

The existing self-heal (`MediaRepairService` / `MediaRequestHandler`) fires
only when a loader notices a *missing* file for an entry it opens. It never
notices a truncated file or an entry nobody opens.

## The protocol

1. **Inventory.** Each record of a batch carries `mediaSize`: the length of
   the advertiser's file, 0 when it has none, for live image and audio entries
   only. A deletion makes no claim on its file. A clockless legacy row, named
   only in `unclocked`, has its size in `unclockedMediaSizes`. The field is left out of the
   JSON when null, since most records have no media.
2. **Diff.** The recipient reads its own sizes for the batch's range and
   compares them with the advertised ones, whatever the clocks say.
   - A smaller copy leads to a **request** with `media: true`. It asks for no
     version when the clocks are equal, and it joins the record's request when
     a version is asked for too.
   - A larger copy leads to a **push** with the file.
   - Sizes are the only comparison. Same-size corruption is out of scope,
     because hashing every file on every round is not worth it.
3. **Answer.** A request record flagged `media` is answered with
   `includeAttachments`, which the attachment policy honours without reading
   the resend-attachments flag.
4. **Receive.** A media file replaces the local copy only when the local copy
   is smaller than the size the event declares (`info.size`), and only with a
   larger file.
5. **Settle.** The request row records the size asked for (`media_size`, sync
   DB v32). The request stays outstanding until the local copy is at least that
   large, until the record is no longer a live media row, or until it expires.

Peers on 1.1.33 or older list no sizes and ignore `media`, so files are
compared only between devices that both carry them.

## The model

[`specs/tla/DeepBackfillMedia.tla`](../../specs/tla/DeepBackfillMedia.tla)
checks the file layer with TLC. It assumes the record layer of
`DeepBackfill.tla` is already done. Its properties:

- `NoShrink`: only a fault ever makes a copy smaller.
- `EventuallyComplete`: every device ends with the largest copy.
- `EventuallyQuiet`.
- `NoDuplicateRequest`: one request per file in flight, plus one per fault.
- `RoundTerminates`.

The model covers truncation, loss, crashes, three devices, and resending
switched on. The configurations and the counterexample for each of its five
design switches are in
[`specs/tla/README.md`](../../specs/tla/README.md#deepbackfillmedia--the-files-behind-image-and-audio-entries).

TLC found one thing the first draft got wrong. A push can deliver a file and
settle its request while the answer is still on the way. If the copy is then
truncated again, the next round rightly asks for it again. The invariant
therefore allows one extra in-flight request per fault.

## Model action → code

| Model action | Code |
|---|---|
| `EmitBatch` | `DeepBackfillService.runRound` sets `DeepBackfillRecord.mediaSize` from `DeepBackfillStore.mediaSizes`. `JournalDeepBackfillStore` reads every live `JournalImage` / `JournalAudio` in the range and stats its file through `entryMedia`. |
| `Diff` | `diffDeepBackfillBatch(advertisedMedia:, localMedia:)` produces `mediaRequests` (id → size asked) and `mediaPushes`. |
| `Answer` | `DeepBackfillService.handleRequest`: a record flagged `absent` or `media` joins `withMedia`, enqueued with `includeAttachments` |
| `Receive` (`ReplaceShorter`, `NeverShrink`) | `AttachmentIngestor._saveAttachment`: `_declaredMediaSize`, and the `skip.notLarger` guard before the atomic write |
| `Settles` | `deepBackfillRequestSettled(askedMediaSize:, localMediaSize:)` over `deep_backfill_requests.media_size` |

`entryMedia` (`lib/features/sync/media/entry_media.dart`) is now the one place
that resolves an entry's media file. The outbox enqueue, the payload sender (a
single send and a bundle's children), the media request answer and the
inventory all use it. Before, each of those paths carried its own copy, and
the media request answer's copy ignored the legacy image path the sender
honours.
