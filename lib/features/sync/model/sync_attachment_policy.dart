import 'package:lotti/features/sync/model/sync_message.dart';

/// Whether a [SyncJournalEntity] payload carries its media file (the image or
/// audio blob) alongside the JSON, rather than the JSON alone.
///
/// This is the single decision point for media on the send path. Both the
/// enqueue writer — which resolves the attachment file and stamps the outbox
/// row's `filePath` — and `MatrixPayloadSender` — which performs the upload —
/// call it, so the two can never disagree. That agreement matters beyond
/// tidiness: a row whose `filePath` is null is *bundle-eligible*, and the
/// dequeue-time bundler ships JSON manifests only. A row the sender wants to
/// attach media to but the writer left unmarked would be packed into a bundle
/// and its blob silently dropped.
///
/// Media rides along when any of:
///
/// - the entry is new to every peer ([SyncEntryStatus.initial]);
/// - the sender explicitly asked for it ([SyncJournalEntity.includeAttachments],
///   set by the flows that re-send history to a device that has none — the
///   sync-setup re-send in `maintenance.dart` and backfill responses);
/// - the `resend_attachments` config flag is on, which forces attachments onto
///   every journal send as an operator escape hatch.
///
/// An ordinary edit to an existing entry — a caption change, a new tag — sends
/// JSON only: the peer already holds the blob, which is immutable for the life
/// of the entry, and re-uploading it would multiply sync traffic by the size of
/// the media library.
bool shouldSendJournalAttachments({
  required SyncEntryStatus status,
  required bool? includeAttachments,
  required bool resendAttachmentsFlag,
}) =>
    status == SyncEntryStatus.initial ||
    (includeAttachments ?? false) ||
    resendAttachmentsFlag;
