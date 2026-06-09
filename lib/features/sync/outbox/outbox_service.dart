import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/client_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/sync/vector_clock_logging.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

part 'outbox_enqueue_dispatch.dart';
part 'outbox_enqueue_dispatch_links.dart';
part 'outbox_enqueue_dispatch_agents.dart';

part 'outbox_service_send.dart';

/// Field-access contract for the [OutboxService] send/runner pipeline,
/// implemented by the concrete fields and consumed by [_OutboxSend].
abstract class _OutboxServiceBase {
  UserActivityGate get _activityGate;
  DomainLogger get _loggingService;
  bool get _isDisposed;
  OutboxRepository get _repository;
  MatrixService? get _matrixService;
  OutboxProcessor get _processor;
  JournalDb get _journalDb;
  DateTime get _createdAt;
  StreamController<void> get _loginGateEventsController;
  Duration get _postDrainSettle;
  ClientRunner<int> get _clientRunner;
  set _clientRunner(ClientRunner<int> value);
  Timer? get _pruneTimer;
  set _pruneTimer(Timer? value);
  Timer? get _startupPruneTimer;
  set _startupPruneTimer(Timer? value);
  Timer? get _watchdogTimer;
  set _watchdogTimer(Timer? value);
}

class OutboxService extends _OutboxServiceBase with _OutboxSend {
  OutboxService({
    required SyncDatabase syncDatabase,
    required this._loggingService,
    required this._vectorClockService,
    required this._journalDb,
    required this._documentsDirectory,
    required UserActivityService userActivityService,
    UserActivityGate? activityGate,
    OutboxRepository? repository,
    OutboxMessageSender? messageSender,
    OutboxProcessor? processor,
    int maxRetries = 10,
    MatrixService? matrixService,
    bool? ownsActivityGate,
    Future<void> Function(String path, String json)? saveJsonHandler,
    this._connectivityStream,
    this._sequenceLogService,
    this._postDrainSettle = SyncTuning.outboxPostDrainSettle,
    this._domainLogger,
    this._activitySignaler,
  }) : _syncDatabase = syncDatabase,
       _saveJson = saveJsonHandler ?? saveJson,
       _activityGate =
           activityGate ??
           UserActivityGate(
             activityService: userActivityService,
             idleThreshold: SyncTuning.outboxIdleThreshold,
           ),
       _ownsActivityGate = ownsActivityGate ?? activityGate == null,
       _matrixService = matrixService {
    // Runtime validation that works in release builds
    if (messageSender == null && matrixService == null) {
      throw ArgumentError(
        'Either messageSender or matrixService must be provided.',
      );
    }

    _repository =
        repository ??
        DatabaseOutboxRepository(
          syncDatabase,
          maxRetries: maxRetries,
          activitySignaler: _activitySignaler,
        );
    _messageSender = messageSender ?? MatrixOutboxMessageSender(matrixService!);
    _processor =
        processor ??
        OutboxProcessor(
          repository: _repository,
          messageSender: _messageSender,
          loggingService: _loggingService,
          maxRetriesOverride: maxRetries,
          domainLogger: _domainLogger,
        );

    _startRunner();

    // Connectivity regain: nudge the outbox to attempt sending. If the client
    // is not yet logged in, schedule a couple of bounded follow-up nudges and
    // rely on the login-state subscription to trigger a send once login
    // completes.
    _connectivitySubscription =
        (_connectivityStream ?? Connectivity().onConnectivityChanged).listen((
          List<ConnectivityResult> result,
        ) {
          final regained = {
            ConnectivityResult.wifi,
            ConnectivityResult.mobile,
            ConnectivityResult.ethernet,
          }.intersection(result.toSet()).isNotEmpty;
          if (regained) {
            _loggingService.log(
              LogDomain.sync,
              'connectivity.regained → enqueue',
              subDomain: 'connectivity',
            );
            if (!_isDisposed) {
              unawaited(enqueueNextSendRequest(delay: Duration.zero));
            }
            // If not logged in yet, add bounded extra nudges.
            final notLoggedIn =
                _matrixService != null && !_matrixService.isLoggedIn();
            if (notLoggedIn) {
              unawaited(
                enqueueNextSendRequest(delay: const Duration(seconds: 1)),
              );
              unawaited(
                enqueueNextSendRequest(delay: const Duration(seconds: 5)),
              );
            }
          }
        });

    // Post-login nudge: if connectivity regain fired too early, ensure a
    // deterministic enqueue once the Matrix client reports logged in.
    final client = _matrixService?.client;
    if (client != null) {
      _loginSubscription = client.onLoginStateChanged.stream.listen((state) {
        if (state == LoginState.loggedIn) {
          _loggingService.log(
            LogDomain.sync,
            'login.loggedIn → enqueue',
            subDomain: 'login',
          );
          unawaited(enqueueNextSendRequest(delay: Duration.zero));
        }
      });
    }

    // DB-driven nudge: ensure new pending items kick the runner while online.
    _outboxCountSubscription = _syncDatabase.watchOutboxCount().listen((count) {
      if (_isDisposed || count <= 0) return;
      // Light debounce via a short delay
      unawaited(
        enqueueNextSendRequest(delay: SyncTuning.outboxDbNudgeDebounce),
      );
      // Coalesce: log only when the count crosses to a new magnitude bucket
      // or a quiet period has elapsed. The enqueue behavior is unchanged;
      // only the log cardinality drops from ~one-per-enqueue to a handful
      // per minute on busy periods.
      final now = DateTime.now();
      final lastAt = _lastLoggedDbNudgeAt;
      final last = _lastLoggedDbNudgeCount;
      final elapsedOk =
          lastAt == null || now.difference(lastAt) >= _coalescedLogMinInterval;
      final crossedThreshold =
          last == null ||
          (count == 1 && last != 1) ||
          (count >= 10 && last < 10) ||
          (count >= 100 && last < 100);
      if (elapsedOk || crossedThreshold) {
        _lastLoggedDbNudgeCount = count;
        _lastLoggedDbNudgeAt = now;
        _loggingService.log(
          LogDomain.sync,
          'dbNudge count=$count → enqueue',
          subDomain: 'dbNudge',
        );
      }
    });
  }

  @override
  final DomainLogger _loggingService;
  final DomainLogger? _domainLogger;
  final SyncActivitySignaler? _activitySignaler;
  final SyncDatabase _syncDatabase;
  final VectorClockService _vectorClockService;
  @override
  final JournalDb _journalDb;
  final Directory _documentsDirectory;
  final Future<void> Function(String path, String json) _saveJson;
  @override
  final UserActivityGate _activityGate;
  final bool _ownsActivityGate;
  @override
  late final OutboxRepository _repository;
  late final OutboxMessageSender _messageSender;
  @override
  late final OutboxProcessor _processor;
  @override
  final MatrixService? _matrixService;
  final Stream<List<ConnectivityResult>>? _connectivityStream;
  final SyncSequenceLogService? _sequenceLogService;
  @override
  final StreamController<void> _loginGateEventsController =
      StreamController<void>.broadcast();

  /// Emits an event whenever `sendNext` is invoked while sync is enabled but
  /// the Matrix service is not logged in. Consumers (UI) can use this to show
  /// a one-time toast informing the user.
  Stream<void> get notLoggedInGateStream => _loginGateEventsController.stream;

  @override
  late ClientRunner<int> _clientRunner;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<LoginState>? _loginSubscription;
  StreamSubscription<int>? _outboxCountSubscription;
  // clock.now() (package:clock) so tests can drive the startup grace
  // window with withClock instead of waiting out real seconds.
  @override
  final DateTime _createdAt = clock.now();
  @override
  bool _isDisposed = false;
  @override
  Timer? _watchdogTimer;
  @override
  Timer? _startupPruneTimer;
  @override
  Timer? _pruneTimer;

  // Coalesce repetitive observability logs. Both `sendNext.state` and
  // `dbNudge` are invoked on every event-loop tick of the outbox, and their
  // diagnostic value is in detecting transitions, not individual firings.
  // Without coalescing, together they contribute roughly 17k lines/day on a
  // quiet desktop — pure noise that drowns out real signal.
  int? _lastLoggedDbNudgeCount;
  DateTime? _lastLoggedDbNudgeAt;

  void _syncLog(String message, {String? subDomain}) {
    _domainLogger?.log(LogDomain.sync, message, subDomain: subDomain);
  }

  Future<void> enqueueNotification(
    NotificationEntity entity, {
    String? originatingHostId,
  }) async {
    final relativePath = relativeNotificationPath(entity.id);
    final fullPath = _safePayloadFullPath(relativePath);
    if (fullPath == null) {
      _loggingService.log(
        LogDomain.sync,
        'enqueue.skip invalid notification payload path: $relativePath',
        subDomain: 'enqueueMessage',
      );
      return;
    }

    await _saveJson(fullPath, jsonEncode(entity.toJson()));
    await enqueueMessage(
      SyncMessage.notification(
        id: entity.id,
        jsonPath: relativePath,
        vectorClock: entity.meta.vectorClock,
        originatingHostId: originatingHostId ?? entity.meta.originatingHostId,
      ),
    );
  }

  Future<void> enqueueNotificationStateUpdate({
    required String id,
    required VectorClock vectorClock,
    required String originatingHostId,
    DateTime? seenAt,
    DateTime? actedOnAt,
    DateTime? deletedAt,
  }) {
    return enqueueMessage(
      SyncMessage.notificationStateUpdate(
        id: id,
        seenAt: seenAt,
        actedOnAt: actedOnAt,
        deletedAt: deletedAt,
        vectorClock: vectorClock,
        originatingHostId: originatingHostId,
      ),
    );
  }

  String? _safePayloadFullPath(String relativePath) {
    final relativeJoined = p.joinAll(
      relativePath.split('/').where((part) => part.isNotEmpty),
    );
    final docsRoot = p.normalize(_documentsDirectory.path);
    final fullPath = p.normalize(p.join(docsRoot, relativeJoined));
    if (!p.isWithin(docsRoot, fullPath) && docsRoot != fullPath) {
      return null;
    }
    return fullPath;
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    // Hoisted out of the outer try so the invariant breach surfaces to the
    // caller as a real exception instead of being swallowed and logged as a
    // routine enqueue failure.
    if (syncMessage is SyncOutboxBundle) {
      throw StateError(
        'SyncOutboxBundle is built at dequeue time and must never be '
        'enqueued via OutboxService.enqueueMessage.',
      );
    }
    try {
      final hostHash = await _vectorClockService.getHostHash();
      final host = await _vectorClockService.getHost();

      // Prepare message (attach links, add originating host ID, merge covered clocks)
      final messageToEnqueue = await _prepareMessage(syncMessage, host);

      final jsonString = json.encode(messageToEnqueue);
      final jsonByteLength = utf8.encode(jsonString).length;
      final priority = _priorityForMessage(messageToEnqueue);
      final commonFields = OutboxCompanion(
        status: Value(OutboxStatus.pending.index),
        message: Value(jsonString),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        payloadSize: Value(jsonByteLength),
        priority: Value(priority),
      );

      // Dispatch by message type using pattern matching
      final merged = await switch (messageToEnqueue) {
        final SyncJournalEntity msg => _enqueueJournalEntity(
          msg: msg,
          commonFields: commonFields,
          host: host,
          hostHash: hostHash,
        ),
        final SyncEntryLink msg => _enqueueEntryLink(
          msg: msg,
          commonFields: commonFields,
          host: host,
          hostHash: hostHash,
        ),
        final SyncEntityDefinition msg => _enqueueEntityDefinition(
          msg: msg,
          commonFields: commonFields,
          host: host,
          hostHash: hostHash,
        ),
        final SyncAiConfig msg => _enqueueAiConfig(
          msg: msg,
          commonFields: commonFields,
        ),
        final SyncAiConfigDelete msg => _enqueueAiConfigDelete(
          msg: msg,
          commonFields: commonFields,
        ),
        final SyncConfigFlag msg => _enqueueConfigFlag(
          msg: msg,
          commonFields: commonFields,
        ),
        final SyncThemingSelection msg => _enqueueThemingSelection(
          msg: msg,
          commonFields: commonFields,
        ),
        final SyncNotification msg => _enqueueNotification(
          msg: msg,
          commonFields: commonFields,
        ),
        final SyncNotificationStateUpdate msg =>
          _enqueueNotificationStateUpdate(
            msg: msg,
            commonFields: commonFields,
          ),
        final SyncBackfillRequest msg => _enqueueBackfillRequest(
          msg: msg,
          commonFields: commonFields,
        ),
        final SyncBackfillResponse msg => _enqueueBackfillResponse(
          msg: msg,
          commonFields: commonFields,
        ),
        final SyncAgentEntity msg => _enqueueAgentEntity(
          msg: msg,
          commonFields: commonFields,
        ),
        final SyncAgentLink msg => _enqueueAgentLink(
          msg: msg,
          commonFields: commonFields,
        ),
        // SyncAgentBundle is a legacy wire variant retained only so peers
        // that still ship the type can be parsed on the receiver. It is
        // never produced locally — wake-cycle writes hit the outbox as
        // individual SyncAgentEntity / SyncAgentLink rows now and let the
        // generic dequeue-time bundler coalesce them.
        SyncAgentBundle() => throw StateError(
          'SyncAgentBundle enqueue is no longer supported; '
          'agent writes route through SyncAgentEntity / SyncAgentLink',
        ),
        // SyncOutboxBundle is rejected by the early guard at the top of
        // this method; this arm exists only so the freezed-sealed switch
        // stays exhaustive.
        SyncOutboxBundle() => throw StateError('unreachable'),
        final SyncSyncNodeProfile msg => _enqueueSyncNodeProfile(
          msg: msg,
          commonFields: commonFields,
        ),
      };

      _syncLog(
        'enqueue type=${messageToEnqueue.runtimeType} priority=$priority',
        subDomain: 'outbox.enqueue',
      );

      // Schedule next send unless merge already did (returns true)
      if (!merged) {
        unawaited(enqueueNextSendRequest(delay: const Duration(seconds: 1)));
      }
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        exception,
        stackTrace: stackTrace,
        subDomain: 'enqueueMessage',
      );
    }
  }

  static int _priorityForMessage(SyncMessage message) {
    return switch (message) {
      SyncJournalEntity() => OutboxPriority.high.index,
      SyncEntryLink() => OutboxPriority.high.index,
      SyncBackfillRequest() => OutboxPriority.normal.index,
      SyncBackfillResponse() => OutboxPriority.normal.index,
      SyncAgentEntity() => OutboxPriority.normal.index,
      SyncAgentLink() => OutboxPriority.normal.index,
      SyncNotification() => OutboxPriority.normal.index,
      SyncNotificationStateUpdate() => OutboxPriority.normal.index,
      // Legacy wire variant — never enqueued locally; see enqueueMessage.
      SyncAgentBundle() => OutboxPriority.normal.index,
      SyncThemingSelection() => OutboxPriority.normal.index,
      SyncEntityDefinition() => OutboxPriority.low.index,
      SyncAiConfig() => OutboxPriority.low.index,
      SyncAiConfigDelete() => OutboxPriority.low.index,
      SyncConfigFlag() => OutboxPriority.normal.index,
      // SyncOutboxBundle has no row-level priority — bundles are built at
      // dequeue time and never enqueued. The dispatch switch in
      // [enqueueMessage] is the single defensive guard for that invariant
      // (one source of truth instead of two coupled `throw` arms).
      SyncOutboxBundle() => OutboxPriority.normal.index,
      // SyncSyncNodeProfile is a presence-style broadcast — low priority so
      // it never queue-jumps journal writes.
      SyncSyncNodeProfile() => OutboxPriority.low.index,
    };
  }

  @visibleForTesting
  static int priorityForMessageForTesting(SyncMessage message) =>
      _priorityForMessage(message);

  /// Upper bound on how many items a single `sendNext` invocation will
  /// push through the processor in one runner pass. Raised from the
  /// original 20 because on a large backlog (thousands of pending
  /// rows) the cap forced the runner to exit, flip through the
  /// activity gate on re-entry, and resume for every 20 items —
  /// a stop-and-go crawl visible as "outbox processing very slow" to
  /// the user. A high cap is safe here: `_drainOutbox` stops
  /// immediately on retry/error backoff or activity-gate pause, so
  /// the bound only matters as a pathological safety net. A single
  /// runner pass now happily sends the whole backlog back-to-back as
  /// long as nothing is wrong.
  @override
  final Duration _postDrainSettle;

  // ---------------------------------------------------------------------------
  // Message preparation helpers
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    _isDisposed = true;
    _clientRunner.close();
    await _connectivitySubscription?.cancel();
    await _loginSubscription?.cancel();
    await _outboxCountSubscription?.cancel();
    _watchdogTimer?.cancel();
    _startupPruneTimer?.cancel();
    _pruneTimer?.cancel();
    if (_ownsActivityGate) {
      await _activityGate.dispose();
    }
    await _loginGateEventsController.close();
  }

  // Exposed for tests to validate tuning/wiring.
  @visibleForTesting
  UserActivityGate getActivityGateForTest() => _activityGate;
}

class MatrixOutboxMessageSender implements OutboxMessageSender {
  MatrixOutboxMessageSender(this._matrixService);

  final MatrixService _matrixService;

  @override
  Future<bool> send(SyncMessage message) {
    return _matrixService.sendMatrixMsg(message);
  }
}
