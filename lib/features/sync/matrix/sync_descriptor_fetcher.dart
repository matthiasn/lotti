import 'package:lotti/features/sync/tuning.dart';
import 'package:matrix/matrix.dart';

/// What a descriptor lookup found, and where.
final class SyncDescriptorLookup {
  const SyncDescriptorLookup({required this.descriptor, required this.source});

  /// Nothing found: the room is unknown here, or neither cache nor server
  /// holds the event.
  static const none = SyncDescriptorLookup(
    descriptor: null,
    source: 'none',
  );

  /// The decrypted descriptor event, or null.
  final Event? descriptor;

  /// `cacheOrServer` when the SDK's own lookup answered, `server` when the
  /// homeserver had to be asked directly, `none` otherwise. For the log.
  final String source;
}

/// Finds the attachment descriptor an inbound payload names, by event id
/// (ADR 0142, step 3).
///
/// The apply path needs this exactly once: when a payload's descriptor is
/// missing from the in-memory index after a restart or a missed file event.
/// Behind this interface the lookup can be answered by whichever isolate
/// holds the Matrix client — today the UI isolate's own, through
/// [MatrixDescriptorFetcher]; later the sync isolate, over a request.
abstract interface class SyncDescriptorFetcher {
  /// The decrypted descriptor event [eventId] of [roomId], from the SDK's
  /// cache or the server. Throws what the lookup throws — a timeout, a
  /// network error, a server error — so the caller classifies it.
  Future<SyncDescriptorLookup> fetch({
    required String roomId,
    required String eventId,
  });
}

/// Answers descriptor lookups from the Matrix client this isolate holds.
class MatrixDescriptorFetcher implements SyncDescriptorFetcher {
  MatrixDescriptorFetcher({required this._resolveRoom});

  /// Builds the fetcher on a [client], answering from the rooms it holds.
  MatrixDescriptorFetcher.forClient(Client client)
    : this(resolveRoom: client.getRoomById);

  final Room? Function(String roomId) _resolveRoom;

  @override
  Future<SyncDescriptorLookup> fetch({
    required String roomId,
    required String eventId,
  }) async {
    final room = _resolveRoom(roomId);
    if (room == null) return SyncDescriptorLookup.none;
    var descriptor = await room
        .getEventById(eventId)
        .timeout(SyncTuning.attachmentDownloadTimeout);
    descriptor = await _decrypt(descriptor, room);
    var source = 'cacheOrServer';
    // The SDK returns a cached event without consulting the server. An
    // incomplete cached plaintext event otherwise makes every retry return
    // the same unusable descriptor, even when the server has the file event.
    final relativePath = descriptor?.content['relativePath'];
    if (descriptor?.type == EventTypes.Message &&
        (relativePath is! String || relativePath.isEmpty)) {
      final remote = await room.client
          .getOneRoomEvent(room.id, eventId)
          .timeout(SyncTuning.attachmentDownloadTimeout);
      // Event.fromMatrixEvent assigns the supplied room, so validate the
      // wire room before conversion. The room-scoped API may omit room_id.
      descriptor =
          remote.eventId == eventId &&
              (remote.roomId == null || remote.roomId == roomId)
          ? Event.fromMatrixEvent(remote, room)
          : null;
      descriptor = await _decrypt(descriptor, room);
      source = 'server';
    }
    return SyncDescriptorLookup(descriptor: descriptor, source: source);
  }

  /// The SDK decrypts server results, but cached events may still be
  /// ciphertext when their key arrives later. Apply the same decryption to
  /// either source.
  Future<Event?> _decrypt(Event? descriptor, Room room) async {
    if (descriptor?.type != EventTypes.Encrypted) return descriptor;
    final encryption = room.client.encryption;
    return encryption == null
        ? descriptor
        : encryption
              .decryptRoomEvent(descriptor!)
              .timeout(SyncTuning.attachmentDownloadTimeout);
  }
}
