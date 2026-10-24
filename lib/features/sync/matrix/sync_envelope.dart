/// What the apply path reads from an inbound Matrix event (ADR 0142, step 3).
///
/// `SyncEventProcessor` prepares and applies against this, never against the
/// SDK's `Event`: these five members are the whole of what it needs, and none
/// of them requires a live `Room` or `Client`. The inbound queue rebuilds one
/// from the decrypted JSON it stores, so applying no longer waits for the SDK
/// to hold the room, and the same values travel by value between isolates
/// once the receive side moves into the sync isolate.
///
/// The members are named as on `Event`, so an SDK event carries every one of
/// them.
abstract interface class SyncEnvelope {
  /// The Matrix event id.
  String get eventId;

  /// The room the event was received in.
  String get roomId;

  /// The Matrix user that sent it.
  String get senderId;

  /// The homeserver's timestamp.
  DateTime get originServerTs;

  /// The message body: the base64-encoded sync payload.
  String get text;
}

/// A [SyncEnvelope] held as plain values — immutable, and safe to send over
/// an isolate port.
final class StoredSyncEnvelope implements SyncEnvelope {
  const StoredSyncEnvelope({
    required this.eventId,
    required this.roomId,
    required this.senderId,
    required this.originServerTs,
    required this.text,
  });

  /// Rebuilds the envelope from the JSON `Event.toJson()` wrote — the shape
  /// the inbound queue stores — for the event received in [roomId].
  ///
  /// The body is read the way `Event.text` reads it: a missing or non-string
  /// `body` is the empty string, which the processor then rejects as
  /// undecodable rather than throwing here.
  factory StoredSyncEnvelope.fromStoredJson(
    Map<String, dynamic> json, {
    required String roomId,
  }) {
    final content = json['content'];
    final body = content is Map ? content['body'] : null;
    return StoredSyncEnvelope(
      eventId: json['event_id'] as String,
      roomId: roomId,
      senderId: json['sender'] as String,
      originServerTs: DateTime.fromMillisecondsSinceEpoch(
        json['origin_server_ts'] as int,
      ),
      text: body is String ? body : '',
    );
  }

  @override
  final String eventId;

  @override
  final String roomId;

  @override
  final String senderId;

  @override
  final DateTime originServerTs;

  @override
  final String text;
}
