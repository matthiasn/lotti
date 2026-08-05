import 'dart:async';

import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:meta/meta.dart';

/// [OutboxService] for worlds that must never sync (guest/demo profiles).
///
/// Every enqueue is a no-op: no outbox row, no sequence-log claim, no payload
/// file. This is the isolation guarantee — a guest world produces zero sync
/// traffic by construction, not because a flag happens to be off. The gate
/// stream never emits, so no "not logged in" toasts appear in demo mode.
class InertOutboxService implements OutboxService {
  final StreamController<void> _gateController =
      StreamController<void>.broadcast();

  /// Counts swallowed enqueue calls so isolation tests can assert that write
  /// paths routed here rather than silently reaching a real outbox.
  @visibleForTesting
  int enqueueAttempts = 0;

  @override
  Future<void> enqueueNotification(
    NotificationEntity entity, {
    String? originatingHostId,
  }) async {
    enqueueAttempts++;
  }

  @override
  Future<void> enqueueNotificationStateUpdate({
    required String id,
    required VectorClock vectorClock,
    required String originatingHostId,
    DateTime? seenAt,
    DateTime? actedOnAt,
    DateTime? deletedAt,
  }) async {
    enqueueAttempts++;
  }

  @override
  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    enqueueAttempts++;
  }

  @override
  Future<void> enqueueMessageOrThrow(SyncMessage syncMessage) async {
    enqueueAttempts++;
  }

  @override
  Stream<void> get notLoggedInGateStream => _gateController.stream;

  @override
  Future<void> dispose() async {
    await _gateController.close();
  }
}
