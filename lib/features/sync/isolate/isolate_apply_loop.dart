import 'dart:async';

import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/instrumentation/sync_cost_meter.dart';
import 'package:lotti/features/sync/isolate/isolate_inbound_queue_gateway.dart';
import 'package:lotti/features/sync/isolate/isolate_sync_service.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/queue_apply_adapter.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

/// The UI isolate's half of the inbound pipeline when the sync isolate hosts
/// the stack (ADR 0142, step 4b): the apply loop — `InboundWorker` leasing
/// and settling through the host, applying with `SyncEventProcessor` behind
/// the activity gate — and the one producer-side nudge this isolate still
/// owns, telling the worker the journal changed so rows abandoned for a
/// missing base are re-armed.
///
/// In-process the coordinator owns both; here the coordinator runs in the
/// worker without an apply loop, and this is what it left behind.
class IsolateApplyLoop {
  IsolateApplyLoop({
    required SyncIsolateHost host,
    required InboundQueue queue,
    required SyncEventProcessor processor,
    required JournalDb journalDb,
    required SyncSequenceLogService sequenceLogService,
    required DomainLogger logging,
    required this._service,
    required this._updateNotifications,
    UserActivityGate? activityGate,
    SyncCostMeter? costMeter,
    InboundWorker? workerOverride,
  }) : _worker =
           workerOverride ??
           _buildWorker(
             host: host,
             queue: queue,
             processor: processor,
             journalDb: journalDb,
             sequenceLogService: sequenceLogService,
             logging: logging,
             activityGate: activityGate,
             costMeter: costMeter,
           );

  static InboundWorker _buildWorker({
    required SyncIsolateHost host,
    required InboundQueue queue,
    required SyncEventProcessor processor,
    required JournalDb journalDb,
    required SyncSequenceLogService sequenceLogService,
    required DomainLogger logging,
    required UserActivityGate? activityGate,
    required SyncCostMeter? costMeter,
  }) {
    final applyAdapter = QueueApplyAdapter(
      processor: processor,
      journalDb: journalDb,
      logging: logging,
      hasOlderActiveEntry: queue.hasOlderActiveEntry,
    );
    return InboundWorker(
      queue: queue,
      gateway: IsolateInboundQueueGateway(host: host, localQueue: queue),
      sequenceLogService: sequenceLogService,
      apply: applyAdapter.bind(),
      prepareBatch: applyAdapter.bindPrepareBatch(),
      logging: logging,
      activityGate: activityGate,
      costMeter: costMeter,
    );
  }

  /// How long journal writes are batched before the worker is nudged once:
  /// a save fans out several notifications, and the re-arm is idempotent.
  static const journalChangedDebounce = Duration(milliseconds: 500);

  final InboundWorker _worker;
  final IsolateSyncService _service;
  final UpdateNotifications _updateNotifications;
  StreamSubscription<Set<String>>? _journalSubscription;
  Timer? _journalDebounce;

  /// Starts the apply loop and the journal-changed relay. Idempotent.
  Future<void> start() async {
    _journalSubscription ??= _updateNotifications.updateStream.listen((_) {
      _journalDebounce?.cancel();
      _journalDebounce = Timer(journalChangedDebounce, () {
        _journalDebounce = null;
        // Nobody waits for the nudge, and the proxy logs its own failures.
        _service.journalChanged();
      });
    });
    await _worker.start();
  }

  /// Stops both; the queue connection is the caller's to close.
  Future<void> dispose() async {
    _journalDebounce?.cancel();
    _journalDebounce = null;
    await _journalSubscription?.cancel();
    _journalSubscription = null;
    await _worker.stop();
  }
}
