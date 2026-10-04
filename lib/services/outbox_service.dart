import 'dart:async';

import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/vector_clock.dart';

/// App-facing write boundary for outbound sync.
///
/// Every feature write path resolves this abstract type. Real profiles get
/// the Matrix-backed `MatrixOutboxService`; guest/demo profiles get the
/// `InertOutboxService`, so a world without a sync stack produces zero
/// outbox rows by construction rather than by configuration.
abstract class OutboxService {
  /// Persists [entity]'s JSON payload under the documents directory and
  /// enqueues a `SyncMessage.notification` referencing it.
  ///
  /// With [rethrowFailure], preparation or persistence failures propagate
  /// after logging instead of being swallowed.
  Future<void> enqueueNotification(
    NotificationEntity entity, {
    String? originatingHostId,
    bool rethrowFailure = false,
  });

  /// Enqueues a `SyncMessage.notificationStateUpdate` carrying the changed
  /// seen/acted/deleted timestamps for notification [id].
  Future<void> enqueueNotificationStateUpdate({
    required String id,
    required VectorClock vectorClock,
    required String originatingHostId,
    DateTime? seenAt,
    DateTime? actedOnAt,
    DateTime? deletedAt,
    bool rethrowFailure = false,
  });

  /// Enqueues [syncMessage], logging and swallowing routine preparation or
  /// persistence failures so background sync callers remain best-effort.
  Future<void> enqueueMessage(SyncMessage syncMessage);

  /// Enqueues [syncMessage] and propagates preparation or persistence
  /// failures after logging them.
  Future<void> enqueueMessageOrThrow(SyncMessage syncMessage);

  /// Emits whenever a send is attempted while sync is enabled but the client
  /// is not logged in; the UI shows a one-time toast.
  Stream<void> get notLoggedInGateStream;

  Future<void> dispose();
}
