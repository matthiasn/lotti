part of 'sync_isolate_protocol.dart';

// What the worker reports unprompted once it hosts the Matrix stack (ADR
// 0142, step 4b): everything the UI isolate used to read off the client.

/// The session's identity changed: a login, a logout, a homeserver resolved.
final class SyncIsolateSessionChanged extends SyncIsolateEvent {
  const SyncIsolateSessionChanged({
    required this.isLoggedIn,
    required this.ownUserId,
    required this.ownDeviceId,
    required this.homeserverHost,
  });

  final bool isLoggedIn;
  final String? ownUserId;
  final String? ownDeviceId;
  final String? homeserverHost;
}

/// A login-state transition, as `SyncService.loginStateChanges` reports it.
final class SyncIsolateLoginStateChanged extends SyncIsolateEvent {
  const SyncIsolateLoginStateChanged(this.state);

  final SyncLoginState state;
}

/// The sync room changed, null when cleared.
final class SyncIsolateRoomIdChanged extends SyncIsolateEvent {
  const SyncIsolateRoomIdChanged(this.roomId);

  final String? roomId;
}

/// Which `SyncService` stream a verification snapshot belongs to.
enum SyncIsolateVerificationStream {
  /// `outgoingVerifications`.
  outgoing,

  /// `incomingVerifications`.
  incoming,

  /// `incomingVerificationRequests`.
  request,
}

/// A ceremony snapshot on one of the three verification streams.
final class SyncIsolateVerificationChanged extends SyncIsolateEvent {
  const SyncIsolateVerificationChanged({
    required this.stream,
    required this.state,
  });

  final SyncIsolateVerificationStream stream;
  final SyncVerificationState state;
}

/// The devices this session has not verified, as the client knows them now.
/// Sent after a login, a session change, every verification snapshot and an
/// explicit roster read, so the proxy's synchronous reader stays current.
final class SyncIsolateUnverifiedDevicesChanged extends SyncIsolateEvent {
  const SyncIsolateUnverifiedDevicesChanged(this.devices);

  final List<SyncDeviceInfo> devices;
}

/// The send counters changed.
final class SyncIsolateStatsChanged extends SyncIsolateEvent {
  const SyncIsolateStatsChanged(this.stats);

  final MatrixStats stats;
}

/// Ingestion recorded an attachment descriptor: the UI isolate's index
/// mirror records it too, so the apply step's synchronous lookups and the
/// `pathRecorded` subscribers see what the worker saw.
final class SyncIsolateAttachmentRecorded extends SyncIsolateEvent {
  const SyncIsolateAttachmentRecorded(this.descriptor);

  final AttachmentDescriptor descriptor;
}

/// The catch-up bridge started or finished a walk.
final class SyncIsolateBridgeChanged extends SyncIsolateEvent {
  const SyncIsolateBridgeChanged({required this.inFlight});

  /// True while the bridge is walking; a false is also the "bridge
  /// completed" nudge the backfill service listens for.
  final bool inFlight;
}

/// Whether the worker's Matrix stack is up. Sent after the stack composed
/// (or failed to), so the proxy knows commands will be answered.
final class SyncIsolateStackChanged extends SyncIsolateEvent {
  const SyncIsolateStackChanged({required this.ready, this.error});

  final bool ready;
  final String? error;
}
