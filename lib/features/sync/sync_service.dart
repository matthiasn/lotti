import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/models/sync_login_state.dart';
import 'package:lotti/features/sync/models/sync_verification.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';

/// The homeserver refused the stored credential for an interactive operation
/// (`M_FORBIDDEN`): the password was rotated elsewhere while this device kept
/// syncing on its access token, and the user has to type the current one.
class SyncReauthRequiredException implements Exception {
  const SyncReauthRequiredException(this.message);

  final String message;

  @override
  String toString() => 'SyncReauthRequiredException: $message';
}

/// What the rest of the app asks of sync, in plain types (ADR 0142).
///
/// Everything above the sync feature — the settings pages, the device and
/// verification sheets, the outbox, the onboarding and provisioning flows —
/// talks to sync through this and never sees the Matrix SDK. In-process the
/// implementation is `MatrixService`, which owns the client; with
/// `use_isolate_sync` on it is answered from the sync isolate instead, which
/// is why nothing here is an SDK object: every value crosses a port.
abstract interface class SyncService {
  /// Connects the stored session and starts the receive pipeline. Called once
  /// at startup, tracked as a startup task.
  Future<void> init();

  Future<void> dispose();

  // ------------------------------------------------------------- session

  bool isLoggedIn();

  /// The session's login-state transitions.
  Stream<SyncLoginState> get loginStateChanges;

  /// The Matrix user this device is logged in as, or null when logged out.
  String? get ownUserId;

  /// The device/session id this app is running as, or null when logged out.
  String? get ownDeviceId;

  /// The host of the homeserver the session talks to, when resolved.
  String? get homeserverHost;

  /// Logs in with the stored config. Returns whether the session is up.
  Future<bool> login({bool waitForLifecycle = true});

  /// Connects a stored session without logging in afresh.
  Future<bool> connect();

  Future<void> logout();

  Future<MatrixConfig?> loadConfig();

  Future<void> setConfig(MatrixConfig config);

  Future<void> deleteConfig();

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  // ---------------------------------------------------------------- room

  /// The sync room in use, or null.
  String? get syncRoomId;

  /// Sync-room transitions, clears included.
  Stream<String?> get syncRoomIdChanges;

  /// The persisted sync room id, or null.
  Future<String?> getRoom();

  Future<String?> joinRoom(String roomId);

  Future<String> createRoom();

  Future<String?> findSyncRoom();

  Future<void> saveRoom(String roomId);

  Future<void> clearPersistedRoom();

  /// Publishes the subscription's rotation proof as room state.
  Future<void> publishRotationProof({
    required String roomId,
    required String bundleId,
    required String challenge,
  });

  // ----------------------------------------------------- devices & trust

  /// The devices this session has not verified, from the key cache.
  List<SyncDeviceInfo> getUnverifiedDevices();

  /// Every session on the account, merged from the homeserver's inventory
  /// and the key cache, ordered for display.
  Future<List<SyncDeviceInfo>> getSyncDevices();

  /// Deletes the session from the homeserver. Throws
  /// [SyncReauthRequiredException] when the credential is refused; the UI then
  /// asks for the current password and retries with [reauthPassword].
  Future<void> deleteDeviceById(String deviceId, {String? reauthPassword});

  /// Starts an outgoing verification of the device; its progress arrives on
  /// [outgoingVerifications].
  Future<void> verifyDevice({required String userId, required String deviceId});

  /// The ceremony this device started, as it changes; the latest is
  /// [outgoingVerification].
  Stream<SyncVerificationState> get outgoingVerifications;

  SyncVerificationState? get outgoingVerification;

  /// The ceremony a peer started with this device, as it changes; the latest
  /// is [incomingVerification].
  Stream<SyncVerificationState> get incomingVerifications;

  SyncVerificationState? get incomingVerification;

  /// Each peer request as it arrives, before this device has answered it.
  Stream<SyncVerificationState> get incomingVerificationRequests;

  /// Answers the peer's request: the ceremony [id] proceeds to the emoji.
  Future<void> acceptVerification(String id);

  /// Confirms the emoji match for ceremony [id].
  Future<void> acceptEmojiVerification(String id);

  /// Cancels ceremony [id] if it is still live; a finished one is left alone,
  /// and a cancel that fails is logged, never thrown.
  Future<void> cancelVerification(String id);

  /// Withdraws this device's outgoing ceremony in favour of the incoming
  /// request [incomingId], which then continues on [outgoingVerifications] —
  /// the stream the open sheet renders — and is accepted.
  Future<void> handOffOutgoingVerificationTo(String incomingId);

  // ------------------------------------------------------- send & stats

  /// Sends a sync payload. Returns false on a retryable failure.
  Future<bool> sendMatrixMsg(SyncMessage syncMessage, {String? myRoomId});

  /// Protocol state that must advance only once a message was accepted.
  Future<void> Function(SyncMessage message)? get onSyncMessageSent;
  set onSyncMessageSent(Future<void> Function(SyncMessage message)? hook);

  Stream<MatrixStats> get stats;

  int get sentCount;

  Map<String, int> get messageCounts;

  Future<SyncMetrics?> getSyncMetrics();

  Future<String> getSyncDiagnosticsText();

  Future<Map<String, dynamic>> getDiagnosticInfo();

  Future<void> forceRescan({bool includeCatchUp = true});

  Future<void> retryNow();

  /// The inbound queue, for the depth the pages show and the drain the agent
  /// runtime waits for. Reads only; it is the UI isolate's own connection.
  InboundQueue get inboundQueue;
}
