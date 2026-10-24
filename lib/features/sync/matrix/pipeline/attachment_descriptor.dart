import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:matrix/matrix.dart';

/// An attachment event as the apply path sees it (ADR 0142, step 3): the
/// values it reads, held without the SDK's `Event` or `Room`, so they can be
/// kept in `AttachmentIndex` on any isolate and sent over a port.
///
/// Fetching the bytes the descriptor points at is `SyncAttachmentFetcher`'s
/// job; this type only identifies and describes them.
final class AttachmentDescriptor {
  const AttachmentDescriptor({
    required this.eventId,
    required this.roomId,
    required this.relativePath,
    required this.mimetype,
    this.declaredSize,
    this.encoding,
  });

  /// Reads the descriptor out of a live SDK [event], or returns null when the
  /// event declares no `relativePath` and so describes no attachment.
  static AttachmentDescriptor? fromEvent(Event event) {
    final relativePath = event.content['relativePath'];
    if (relativePath is! String || relativePath.isEmpty) return null;
    final encoding = event.content[attachmentEncodingKey];
    return AttachmentDescriptor(
      eventId: _safeEventId(event),
      roomId: event.roomId ?? event.room.id,
      relativePath: relativePath,
      mimetype: event.attachmentMimetype,
      declaredSize: _declaredSize(event, relativePath),
      encoding: encoding is String ? encoding : null,
    );
  }

  // Safe access to `Event.eventId`: the empty string when it is missing, so
  // an attachment is still found by its path when its id is not known.
  static String _safeEventId(Event event) {
    try {
      return event.eventId;
    } catch (_) {
      return '';
    }
  }

  /// The size the sender declared for a media file (`info.size`, the
  /// plaintext length), or null for JSON payloads — uploaded gzipped, so
  /// their declared size is not the local file's — and for events without
  /// one.
  static int? _declaredSize(Event event, String relativePath) {
    if (relativePath.toLowerCase().endsWith('.json')) return null;
    final info = event.content['info'];
    if (info is! Map) return null;
    final size = info['size'];
    return size is int ? size : null;
  }

  /// The Matrix event id: the exact generation an envelope names.
  final String eventId;

  /// The room the event was received in; where its bytes are fetched from.
  final String roomId;

  /// The path below the documents directory, as the sender declared it.
  final String relativePath;

  /// The attachment's MIME type as the SDK reports it; empty when unknown.
  final String mimetype;

  /// What the sender declared for a media file's plaintext size, when it did.
  final int? declaredSize;

  /// The `com.lotti.encoding` the bytes were uploaded with, when any.
  final String? encoding;
}
