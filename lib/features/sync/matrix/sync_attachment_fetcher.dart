import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/features/sync/matrix/pipeline/attachment_descriptor.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_fetcher.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:matrix/matrix.dart';

/// Fetches the bytes an [AttachmentDescriptor] points at (ADR 0142, step 3).
///
/// The apply path knows attachments only by descriptor; behind this
/// interface the download is done by whichever isolate holds the Matrix
/// client — today the UI isolate's own, through [MatrixAttachmentFetcher];
/// later the sync isolate, over a request.
abstract interface class SyncAttachmentFetcher {
  /// The attachment's decrypted bytes as they were uploaded — still gzipped
  /// when [AttachmentDescriptor.encoding] says so. Throws a
  /// `FileSystemException` naming [pathForError] (the descriptor's path when
  /// null) when the download times out or the event cannot be found;
  /// network and server errors pass through for the caller to classify.
  Future<Uint8List> download(
    AttachmentDescriptor descriptor, {
    String? pathForError,
  });

  /// Drops the client's cached copy of the attachment, so the next
  /// [download] asks the server again. Returns the purged media URI, or null
  /// when the event names no media to purge.
  Future<Uri?> purgeCached(AttachmentDescriptor descriptor);
}

/// Downloads through the Matrix client this isolate holds.
///
/// The SDK downloads through an `Event`, so the fetcher finds the
/// descriptor's event through [SyncDescriptorFetcher] — the client's cache,
/// or the server — and downloads from that. Concurrent downloads of one
/// event share the SDK call (`downloadAttachmentWithTimeout`).
class MatrixAttachmentFetcher implements SyncAttachmentFetcher {
  MatrixAttachmentFetcher({required this._events});

  final SyncDescriptorFetcher _events;

  @override
  Future<Uint8List> download(
    AttachmentDescriptor descriptor, {
    String? pathForError,
  }) async {
    final path = pathForError ?? descriptor.relativePath;
    final event = await _event(descriptor, path);
    final file = await downloadAttachmentWithTimeout(event, pathForError: path);
    return file.bytes;
  }

  @override
  Future<Uri?> purgeCached(AttachmentDescriptor descriptor) async {
    final event = await _event(descriptor, descriptor.relativePath);
    final uri = event.attachmentOrThumbnailMxcUrl();
    if (uri == null) return null;
    await event.room.client.database.deleteFile(uri);
    return uri;
  }

  Future<Event> _event(AttachmentDescriptor descriptor, String path) async {
    final lookup = await _events.fetch(
      roomId: descriptor.roomId,
      eventId: descriptor.eventId,
    );
    final event = lookup.descriptor;
    if (event == null) {
      throw FileSystemException(
        'attachment event ${descriptor.eventId} not available',
        path,
      );
    }
    return event;
  }
}
