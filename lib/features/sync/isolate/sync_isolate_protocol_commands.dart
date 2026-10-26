part of 'sync_isolate_protocol.dart';

// The `SyncService` surface as commands (ADR 0142, step 4b): what the UI
// isolate's proxy sends the worker that hosts the Matrix stack. One reply
// each; the result type is documented on every command.

/// Starts the stack: connects the configured session, with retries, and
/// starts admission and the bridge — `SyncService.init`. Answered with
/// `null`.
final class SyncIsolateInitStack extends SyncIsolateCommand {
  const SyncIsolateInitStack();
}

/// Hands the worker the stored credentials, or null once they were deleted
/// (which also logs the session out). The keychain stays on the UI isolate;
/// this is the copy the session works with. Answered with `null`.
final class SyncIsolateConfigure extends SyncIsolateCommand {
  const SyncIsolateConfigure(this.config);

  final MatrixConfig? config;
}

/// Logs in with the configured credentials. Answered with the `bool` the
/// session reports.
final class SyncIsolateLogin extends SyncIsolateCommand {
  const SyncIsolateLogin({required this.waitForLifecycle});

  final bool waitForLifecycle;
}

/// Connects the stored session without logging in afresh. Answered with
/// `bool`.
final class SyncIsolateConnect extends SyncIsolateCommand {
  const SyncIsolateConnect();
}

/// Logs the session out. Answered with `null`.
final class SyncIsolateLogout extends SyncIsolateCommand {
  const SyncIsolateLogout();
}

/// Changes the account password on the homeserver. The host persists the
/// new credential itself; the worker only talks to the server. Answered with
/// `null`.
final class SyncIsolateChangePassword extends SyncIsolateCommand {
  const SyncIsolateChangePassword({
    required this.oldPassword,
    required this.newPassword,
  });

  final String oldPassword;
  final String newPassword;
}

/// Tells the worker whether the device is online — `connectivity_plus` is a
/// plugin, so the host watches it. Answered with `null`.
final class SyncIsolateConnectivityChanged extends SyncIsolateCommand {
  const SyncIsolateConnectivityChanged({required this.online});

  final bool online;
}

/// The persisted sync room id. Answered with `String?`.
final class SyncIsolateGetRoom extends SyncIsolateCommand {
  const SyncIsolateGetRoom();
}

/// Joins [roomId] and persists it. Answered with the joined `String?`.
final class SyncIsolateJoinRoom extends SyncIsolateCommand {
  const SyncIsolateJoinRoom(this.roomId);

  final String roomId;
}

/// Creates the account's sync room. Answered with its `String` id.
final class SyncIsolateCreateRoom extends SyncIsolateCommand {
  const SyncIsolateCreateRoom();
}

/// The account's existing sync room, if any. Answered with `String?`.
final class SyncIsolateFindSyncRoom extends SyncIsolateCommand {
  const SyncIsolateFindSyncRoom();
}

/// Persists [roomId] as the sync room without joining. Answered with `null`.
final class SyncIsolateSaveRoom extends SyncIsolateCommand {
  const SyncIsolateSaveRoom(this.roomId);

  final String roomId;
}

/// Clears the persisted sync room pointer. Answered with `null`.
final class SyncIsolateClearPersistedRoom extends SyncIsolateCommand {
  const SyncIsolateClearPersistedRoom();
}

/// Publishes a subscription's rotation proof as room state. Answered with
/// `null`.
final class SyncIsolatePublishRotationProof extends SyncIsolateCommand {
  const SyncIsolatePublishRotationProof({
    required this.roomId,
    required this.bundleId,
    required this.challenge,
  });

  final String roomId;
  final String bundleId;
  final String challenge;
}

/// The devices this session has not verified. Answered with
/// `List<SyncDeviceInfo>`.
final class SyncIsolateGetUnverifiedDevices extends SyncIsolateCommand {
  const SyncIsolateGetUnverifiedDevices();
}

/// Every session on the account, ordered for display. Answered with
/// `List<SyncDeviceInfo>`.
final class SyncIsolateGetSyncDevices extends SyncIsolateCommand {
  const SyncIsolateGetSyncDevices();
}

/// Deletes a session from the homeserver. A refused credential answers with
/// a failure whose [SyncIsolateFailure.thrown] is
/// [SyncIsolateThrown.reauthRequired]. Answered with `null`.
final class SyncIsolateDeleteDevice extends SyncIsolateCommand {
  const SyncIsolateDeleteDevice({required this.deviceId, this.reauthPassword});

  final String deviceId;
  final String? reauthPassword;
}

/// Starts an outgoing verification of the device. Answered with `null`; the
/// ceremony's progress arrives as [SyncIsolateVerificationChanged] events.
final class SyncIsolateVerifyDevice extends SyncIsolateCommand {
  const SyncIsolateVerifyDevice({required this.userId, required this.deviceId});

  final String userId;
  final String deviceId;
}

/// What a [SyncIsolateVerificationAction] does to ceremony `id`.
enum SyncIsolateVerificationActionKind {
  /// `SyncService.acceptVerification`.
  accept,

  /// `SyncService.acceptEmojiVerification`.
  acceptEmoji,

  /// `SyncService.cancelVerification`.
  cancel,

  /// `SyncService.handOffOutgoingVerificationTo`.
  handOffOutgoingTo,
}

/// Drives the ceremony [id] by its id, as the sheets do. Answered with
/// `null`.
final class SyncIsolateVerificationAction extends SyncIsolateCommand {
  const SyncIsolateVerificationAction({required this.kind, required this.id});

  final SyncIsolateVerificationActionKind kind;
  final String id;
}

/// Sends a sync payload from the worker's client. Answered with the `bool`
/// the sender reports; a payload that can never fit answers with a failure
/// whose [SyncIsolateFailure.thrown] is [SyncIsolateThrown.messageTooLarge].
final class SyncIsolateSendMessage extends SyncIsolateCommand {
  const SyncIsolateSendMessage(this.message, {this.roomId});

  final SyncMessage message;

  /// A room other than the sync room, when the caller names one.
  final String? roomId;
}

/// Pipeline metrics. Answered with `SyncMetrics?`.
final class SyncIsolateGetSyncMetrics extends SyncIsolateCommand {
  const SyncIsolateGetSyncMetrics();
}

/// The diagnostics text the sync settings show. Answered with `String`.
final class SyncIsolateGetDiagnosticsText extends SyncIsolateCommand {
  const SyncIsolateGetDiagnosticsText();
}

/// The structured diagnostics. Answered with `Map<String, dynamic>`.
final class SyncIsolateGetDiagnosticInfo extends SyncIsolateCommand {
  const SyncIsolateGetDiagnosticInfo();
}

/// `SyncService.forceRescan`. Answered with `null`.
final class SyncIsolateForceRescan extends SyncIsolateCommand {
  const SyncIsolateForceRescan({required this.includeCatchUp});

  final bool includeCatchUp;
}

/// `SyncService.retryNow`. Answered with `null`.
final class SyncIsolateRetryNow extends SyncIsolateCommand {
  const SyncIsolateRetryNow();
}

/// Forces a catch-up bridge pass, as the "Catch up now" action does.
/// Answered with `null`.
final class SyncIsolateTriggerBridge extends SyncIsolateCommand {
  const SyncIsolateTriggerBridge();
}

/// Starts the barren-bridge gap recovery when one is recorded. Answered with
/// `null`.
final class SyncIsolateMaybeStartGapRecovery extends SyncIsolateCommand {
  const SyncIsolateMaybeStartGapRecovery();
}

/// Re-arms every abandoned queue row, the user's "retry skipped". Answered
/// with the `int` count resurrected.
final class SyncIsolateRetrySkipped extends SyncIsolateCommand {
  const SyncIsolateRetrySkipped();
}

/// The UI isolate wrote the journal: rows abandoned for a missing base may
/// apply now. The worker re-arms them (`resurrectByReason('missingBase')`).
/// Answered with `null`.
final class SyncIsolateJournalChanged extends SyncIsolateCommand {
  const SyncIsolateJournalChanged();
}

/// Recovers a descriptor the apply step's index lost, by event id, vetted by
/// the worker's trust gate. Answered with `AttachmentDescriptor?`.
final class SyncIsolateRecoverDescriptor extends SyncIsolateCommand {
  const SyncIsolateRecoverDescriptor({
    required this.roomId,
    required this.eventId,
  });

  final String roomId;
  final String eventId;
}

/// Downloads the bytes a descriptor points at. Answered with `Uint8List`; a
/// download that cannot find its event answers with a failure whose
/// [SyncIsolateFailure.thrown] is [SyncIsolateThrown.fileSystem].
final class SyncIsolateDownloadAttachment extends SyncIsolateCommand {
  const SyncIsolateDownloadAttachment(this.descriptor, {this.pathForError});

  final AttachmentDescriptor descriptor;
  final String? pathForError;
}

/// Drops the client's cached copy of an attachment. Answered with the purged
/// `Uri?`.
final class SyncIsolatePurgeAttachment extends SyncIsolateCommand {
  const SyncIsolatePurgeAttachment(this.descriptor);

  final AttachmentDescriptor descriptor;
}

/// The worker's view of the session and the ceremonies, for a proxy that
/// starts listening late. Answered with [SyncIsolateSnapshot].
final class SyncIsolateGetSnapshot extends SyncIsolateCommand {
  const SyncIsolateGetSnapshot();
}

/// What the proxy's plain readers answer from, refreshed by events.
final class SyncIsolateSnapshot {
  const SyncIsolateSnapshot({
    required this.isLoggedIn,
    required this.ownUserId,
    required this.ownDeviceId,
    required this.homeserverHost,
    required this.syncRoomId,
    required this.outgoingVerification,
    required this.incomingVerification,
    required this.stats,
    required this.isBridgeInFlight,
  });

  final bool isLoggedIn;
  final String? ownUserId;
  final String? ownDeviceId;
  final String? homeserverHost;
  final String? syncRoomId;
  final SyncVerificationState? outgoingVerification;
  final SyncVerificationState? incomingVerification;
  final MatrixStats stats;
  final bool isBridgeInFlight;
}
