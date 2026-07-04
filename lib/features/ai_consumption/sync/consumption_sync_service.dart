import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Sync-aware write wrapper around [ConsumptionRepository].
///
/// All **local** consumption writes go through [recordEvent] so each is stamped
/// with a vector clock, recorded in the sync sequence log, and enqueued for
/// cross-device sync via the outbox. Incoming sync writes (from
/// `SyncEventProcessor`) call the repository directly to avoid an echo loop —
/// they do not pass through this service.
///
/// This is deliberately far simpler than `AgentSyncService`: consumption events
/// are immutable and append-only, so there is no message/DAG/head routing, no
/// concurrent-merge, and no transaction buffering — one stamped write, one
/// enqueue.
class ConsumptionSyncService {
  ConsumptionSyncService({
    required this._repository,
    required this._outboxService,
    required this._vectorClockService,
    this._sequenceLogService,
    this._updateNotifications,
  });

  final ConsumptionRepository _repository;
  final OutboxService _outboxService;
  final VectorClockService _vectorClockService;
  final SyncSequenceLogService? _sequenceLogService;
  final UpdateNotifications? _updateNotifications;

  /// The underlying repository for read-only operations.
  ConsumptionRepository get repository => _repository;

  SyncSequenceLogService? get _sequenceLog =>
      _sequenceLogService ??
      (getIt.isRegistered<SyncSequenceLogService>()
          ? getIt<SyncSequenceLogService>()
          : null);

  UpdateNotifications? get _notifications =>
      _updateNotifications ??
      (getIt.isRegistered<UpdateNotifications>()
          ? getIt<UpdateNotifications>()
          : null);

  /// Fires the UI refresh for a committed consumption write. `notifyUiOnly`
  /// (never plain `notify`): per-turn events are recorded mid-wake, and a
  /// regular notification would feed back into the wake orchestrator.
  void _notifyWrite(AiConsumptionEvent event) {
    _notifications?.notifyUiOnly({
      if (event.taskId != null) event.taskId!,
      if (event.categoryId != null) event.categoryId!,
      aiConsumptionNotification,
    });
  }

  /// Records a consumption event locally and enqueues it for sync.
  ///
  /// Stamps the next vector clock, persists, records the send in the sequence
  /// log, and enqueues a [SyncMessage.consumptionEvent]. When [fromSync] is
  /// true, writes the repository directly without enqueuing (used only for test
  /// flexibility — the production inbound path calls the repository directly).
  Future<void> recordEvent(
    AiConsumptionEvent event, {
    bool fromSync = false,
  }) async {
    if (fromSync) {
      await _repository.upsertEvent(event);
      _notifyWrite(event);
      return;
    }
    await _vectorClockService.withVcScope<void>(() async {
      final stamped = event.copyWith(
        vectorClock: await _vectorClockService.getNextVectorClock(
          previous: event.vectorClock,
        ),
      );
      await _repository.upsertEvent(stamped);
      // The DB write committed the stamped VC, so it MUST commit. Record +
      // enqueue failures are swallowed so the VC scope's
      // default-commit-on-normal-return still fires.
      _notifyWrite(stamped);
      await _recordSequence(stamped);
      await _enqueuePostWrite(
        SyncMessage.consumptionEvent(
          event: stamped,
          status: SyncEntryStatus.update,
        ),
      );
    });
  }

  Future<void> _recordSequence(AiConsumptionEvent event) async {
    final service = _sequenceLog;
    final vectorClock = event.vectorClock;
    if (service == null || vectorClock == null) return;
    try {
      await service.recordSentEntry(
        entryId: event.id,
        vectorClock: vectorClock,
        payloadType: SyncSequencePayloadType.consumptionEvent,
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        exception,
        message:
            'sequence record failed after consumption write; VC already '
            'committed',
        stackTrace: stackTrace,
        subDomain: 'consumptionSync.record',
      );
    }
  }

  Future<void> _enqueuePostWrite(SyncMessage message) async {
    try {
      await _outboxService.enqueueMessage(message);
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        exception,
        message: 'outbox enqueue failed after DB write; VC already committed',
        stackTrace: stackTrace,
        subDomain: 'consumptionSync.enqueue',
      );
    }
  }
}
