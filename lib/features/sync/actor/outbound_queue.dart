import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/tuning.dart';

typedef OutboundQueueEventSink = void Function(Map<String, Object?> event);

const String _syncMessageType = 'com.lotti.sync.message';

/// Actor-side durable outbox queue processor.
///
/// It claims rows from `SyncDatabase`, sends them with
/// `MatrixSdkGateway.sendText`, and updates DB status directly. The actor uses
/// this to keep send retries, backoff, and lease ownership entirely outside the
/// UI isolate.
class OutboundQueue {
  OutboundQueue({
    required SyncDatabase syncDatabase,
    required MatrixSdkGateway gateway,
    required OutboundQueueEventSink emitEvent,
    Duration leaseDuration = const Duration(minutes: 1),
    Duration retryDelay = SyncTuning.outboxRetryDelay,
    Duration errorDelay = SyncTuning.outboxErrorDelay,
    int maxRetries = SyncTuning.outboxMaxRetriesDiagnostics,
    Duration sendTimeout = SyncTuning.outboxSendTimeout,
    bool connected = true,
    String? syncRoomId,
  })  : _syncDatabase = syncDatabase,
        _gateway = gateway,
        _emitEvent = emitEvent,
        _leaseDuration = leaseDuration,
        _retryDelay = retryDelay,
        _errorDelay = errorDelay,
        _maxRetries = maxRetries,
        _sendTimeout = sendTimeout,
        _connected = connected,
        _syncRoomId = syncRoomId;

  final SyncDatabase _syncDatabase;
  final MatrixSdkGateway _gateway;
  final OutboundQueueEventSink _emitEvent;
  final Duration _leaseDuration;
  final Duration _retryDelay;
  final Duration _errorDelay;
  final int _maxRetries;
  final Duration _sendTimeout;
  String? _syncRoomId;
  bool _connected;
  bool _disposed = false;

  /// Maximum in-flight lock duration for claimed rows.
  ///
  /// The DB uses status `sending` (value 3) plus a future `updatedAt` timestamp
  /// to make claims recoverable after process crashes.
  Duration get leaseDuration => _leaseDuration;

  /// Allows the host-side provider to update the active room when joins/creates
  /// change.
  // ignore: use_setters_to_change_properties
  void updateSyncRoomId(String? roomId) {
    _syncRoomId = roomId;
  }

  /// Updates connectivity status so backpressure can be paused while offline.
  // ignore: use_setters_to_change_properties
  void updateConnectivity({required bool isConnected}) {
    _connected = isConnected;
  }

  void dispose() {
    _disposed = true;
  }

  /// Processes a single outbound item.
  ///
  /// Returns a delay if another pass should be scheduled.
  Future<Duration?> drain() async {
    if (_disposed) return null;
    if (!_connected) return null;

    final roomId = _resolveSyncRoomId();
    if (roomId == null) {
      return null;
    }

    final claimedItem = await _syncDatabase.claimNextOutboxItem(
      leaseDuration: _leaseDuration,
    );
    if (claimedItem == null) {
      return null;
    }

    try {
      final payload = _decodeMessage(claimedItem);
      // Envelope is base64-encoded JSON for matrix transport compatibility.
      final encoded = base64.encode(utf8.encode(json.encode(payload.toJson())));

      final eventId = await _gateway
          .sendText(
            roomId: roomId,
            message: encoded,
            messageType: _syncMessageType,
            displayPendingEvent: false,
          )
          .timeout(_sendTimeout);

      await _syncDatabase.updateOutboxItem(
        OutboxCompanion(
          id: Value(claimedItem.id),
          status: Value(OutboxStatus.sent.index),
          updatedAt: Value(DateTime.now()),
        ),
      );

      _emitEvent({
        'event': 'sendAck',
        'itemId': claimedItem.id,
        'subject': claimedItem.subject,
        'roomId': roomId,
        'eventId': eventId,
      });

      final hasMore = await _hasMorePending();
      return hasMore ? Duration.zero : null;
    } catch (error) {
      final reason = _normalizeFailure(error);
      final nextDelay = await _markFailed(claimedItem);
      _emitEvent({
        'event': 'sendFailed',
        'itemId': claimedItem.id,
        'subject': claimedItem.subject,
        'reason': reason,
        'attempts': claimedItem.retries + 1,
        'roomId': roomId,
      });
      return nextDelay;
    }
  }

  Future<Duration> _markFailed(OutboxItem item) async {
    final nextRetries = item.retries + 1;
    final nextStatus = nextRetries >= _maxRetries
        ? OutboxStatus.error.index
        : OutboxStatus.pending.index;
    final nextDelay = nextRetries >= _maxRetries ? Duration.zero : _retryDelay;

    await _syncDatabase.updateOutboxItem(
      OutboxCompanion(
        id: Value(item.id),
        status: Value(nextStatus),
        retries: Value(nextRetries),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (_disposed || !_connected) return _errorDelay;
    return nextDelay;
  }

  SyncMessage _decodeMessage(OutboxItem item) {
    final raw = json.decode(item.message);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('outbox message is not a JSON map');
    }
    return SyncMessage.fromJson(raw);
  }

  String _normalizeFailure(Object error) {
    if (error is TimeoutException) {
      return 'send timeout';
    }
    return error.toString();
  }

  String? _resolveSyncRoomId() {
    final syncRoomId = _syncRoomId;
    if (syncRoomId != null && syncRoomId.isNotEmpty) {
      return syncRoomId;
    }

    final joinedRooms = _gateway.client.rooms;
    if (joinedRooms.isNotEmpty) {
      return joinedRooms.first.id;
    }

    return null;
  }

  Future<bool> _hasMorePending() async {
    final pending = await _syncDatabase.oldestOutboxItems(1);
    return pending.isNotEmpty;
  }
}
