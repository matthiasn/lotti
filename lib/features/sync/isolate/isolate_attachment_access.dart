import 'dart:typed_data';

import 'package:lotti/features/sync/isolate/isolate_sync_service.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_descriptor.dart';
import 'package:lotti/features/sync/matrix/sync_attachment_fetcher.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_recovery.dart';

/// The apply step's two client lookups, answered by the sync isolate (ADR
/// 0142, step 4b): the worker's recovery vets the descriptor with its trust
/// gate and the worker's fetcher downloads through its client.
class IsolateDescriptorRecovery implements SyncDescriptorRecovery {
  const IsolateDescriptorRecovery(this._service);

  final IsolateSyncService _service;

  @override
  Future<AttachmentDescriptor?> recover({
    required String roomId,
    required String eventId,
  }) async =>
      await _service.command(
            SyncIsolateRecoverDescriptor(roomId: roomId, eventId: eventId),
          )
          as AttachmentDescriptor?;
}

/// Downloads and purges through the sync isolate's client. The bytes cross
/// the port by value, once.
class IsolateAttachmentFetcher implements SyncAttachmentFetcher {
  const IsolateAttachmentFetcher(this._service);

  final IsolateSyncService _service;

  @override
  Future<Uint8List> download(
    AttachmentDescriptor descriptor, {
    String? pathForError,
  }) async =>
      (await _service.command(
            SyncIsolateDownloadAttachment(
              descriptor,
              pathForError: pathForError,
            ),
          ))!
          as Uint8List;

  @override
  Future<Uri?> purgeCached(AttachmentDescriptor descriptor) async =>
      await _service.command(SyncIsolatePurgeAttachment(descriptor)) as Uri?;
}
