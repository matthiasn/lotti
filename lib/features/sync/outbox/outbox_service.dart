import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:lotti/classes/journal_entities.dart';
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
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/sync/vector_clock_logging.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

class OutboxService {
  OutboxService({
    required SyncDatabase syncDatabase,
    required LoggingService loggingService,
    required VectorClockService vectorClockService,
    required JournalDb journalDb,
    required Directory documentsDirectory,
    required UserActivityService userActivityService,
    UserActivityGate? activityGate,
    OutboxRepository? repository,
    OutboxMessageSender? messageSender,
    OutboxProcessor? processor,
    int maxRetries = 10,
    MatrixService? matrixService,
    bool? ownsActivityGate,
    Future<void> Function(String path, String json)? saveJsonHandler,
    // Optional seams for testing/injection
    Stream<List<ConnectivityResult>>? connectivityStream,
    SyncSequenceLogService? sequenceLogService,
    Duration postDrainSettle = _defaultPostDrainSettle,
    DomainLogger? domainLogger,
  }) : _postDrainSettle = postDrainSettle,
       _syncDatabase = syncDatabase,
       _loggingService = loggingService,
       _vectorClockService = vectorClockService,
       _journalDb = journalDb,
       _documentsDirectory = documentsDirectory,
       _saveJson = saveJsonHandler ?? saveJson,
       _activityGate =
           activityGate ??
           UserActivityGate(
             activityService: userActivityService,
             idleThreshold: SyncTuning.outboxIdleThreshold,
           ),
       _ownsActivityGate = ownsActivityGate ?? activityGate == null,
       _matrixService = matrixService,
       _connectivityStream = connectivityStream,
       _sequenceLogService = sequenceLogService,
       _domainLogger = domainLogger {
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
            _loggingService.captureEvent(
              'connectivity.regained → enqueue',
              domain: 'OUTBOX',
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
          _loggingService.captureEvent(
            'login.loggedIn → enqueue',
            domain: 'OUTBOX',
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
      _loggingService.captureEvent(
        'dbNudge count=$count → enqueue',
        domain: 'OUTBOX',
        subDomain: 'dbNudge',
      );
    });
  }

  final LoggingService _loggingService;
  final DomainLogger? _domainLogger;
  final SyncDatabase _syncDatabase;
  final VectorClockService _vectorClockService;
  final JournalDb _journalDb;
  final Directory _documentsDirectory;
  final Future<void> Function(String path, String json) _saveJson;
  final UserActivityGate _activityGate;
  final bool _ownsActivityGate;
  late final OutboxRepository _repository;
  late final OutboxMessageSender _messageSender;
  late final OutboxProcessor _processor;
  final MatrixService? _matrixService;
  final Stream<List<ConnectivityResult>>? _connectivityStream;
  final SyncSequenceLogService? _sequenceLogService;
  final StreamController<void> _loginGateEventsController =
      StreamController<void>.broadcast();

  /// Emits an event whenever `sendNext` is invoked while sync is enabled but
  /// the Matrix service is not logged in. Consumers (UI) can use this to show
  /// a one-time toast informing the user.
  Stream<void> get notLoggedInGateStream => _loginGateEventsController.stream;

  late ClientRunner<int> _clientRunner;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<LoginState>? _loginSubscription;
  StreamSubscription<int>? _outboxCountSubscription;
  final DateTime _createdAt = DateTime.now();
  static const Duration _loginGateStartupGrace = Duration(seconds: 5);
  bool _isDisposed = false;
  Timer? _watchdogTimer;
  DateTime? _nextSendAllowedAt;
  DateTime? _backoffScheduledAt;

  void _syncLog(String message, {String? subDomain}) {
    _domainLogger?.log(LogDomains.sync, message, subDomain: subDomain);
  }

  void _startRunner() {
    _clientRunner = ClientRunner<int>(
      callback: (event) async {
        final started = DateTime.now();
        await _activityGate.waitUntilIdle();
        final waitedMs = DateTime.now().difference(started).inMilliseconds;
        if (waitedMs > 50) {
          // Light instrumentation to correlate potential stalls.
          _loggingService.captureEvent(
            'activityGate.wait ms=$waitedMs',
            domain: 'OUTBOX',
            subDomain: 'activityGate',
          );
        }
        await sendNext();
      },
    );

    // Safety watchdog: if there are pending items and we appear idle (no
    // queued work), periodically nudge the runner. This recovers from missed
    // signals or platform-specific timer quirks after reconnects/resumes.
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(SyncTuning.outboxWatchdogInterval, (
      Timer _,
    ) async {
      if (_isDisposed) return;
      try {
        final loggedIn = _matrixService?.isLoggedIn() ?? true;
        if (!loggedIn) {
          _loggingService.captureEvent(
            'watchdog.skip notLoggedIn',
            domain: 'OUTBOX',
            subDomain: 'watchdog',
          );
          return;
        }
        final hasPending = (await _repository.fetchPending(
          limit: 1,
        )).isNotEmpty;
        final idleQueue = _clientRunner.queueSize == 0;
        if (hasPending && loggedIn && idleQueue) {
          _loggingService.captureEvent(
            'watchdog: pending+loggedIn idleQueue → enqueue',
            domain: 'OUTBOX',
            subDomain: 'watchdog',
          );
          unawaited(enqueueNextSendRequest(delay: Duration.zero));
        }
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'OUTBOX',
          subDomain: 'watchdog',
          stackTrace: st,
        );
      }
    });
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
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
        final SyncTagEntity msg => _enqueueTagEntity(
          msg: msg,
          commonFields: commonFields,
          hostHash: hostHash,
        ),
        final SyncThemingSelection msg => _enqueueThemingSelection(
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
      _loggingService.captureException(
        exception,
        domain: 'OUTBOX',
        subDomain: 'enqueueMessage',
        stackTrace: stackTrace,
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
      SyncThemingSelection() => OutboxPriority.normal.index,
      SyncEntityDefinition() => OutboxPriority.low.index,
      SyncTagEntity() => OutboxPriority.low.index,
      SyncAiConfig() => OutboxPriority.low.index,
      SyncAiConfigDelete() => OutboxPriority.low.index,
    };
  }

  static const int _maxDrainPasses = 20;
  static const Duration _defaultPostDrainSettle = Duration(milliseconds: 250);
  final Duration _postDrainSettle;

  void _recordBackoff(Duration delay) {
    if (delay <= Duration.zero) return;
    final now = DateTime.now();
    final candidate = now.add(delay);
    final current = _nextSendAllowedAt;
    if (current == null || candidate.isAfter(current)) {
      _nextSendAllowedAt = candidate;
    }
    _scheduleBackoffAt(_nextSendAllowedAt!);
  }

  void _scheduleBackoffAt(DateTime when) {
    if (_isDisposed) return;
    final scheduled = _backoffScheduledAt;
    if (scheduled != null && !when.isAfter(scheduled)) {
      return;
    }
    _backoffScheduledAt = when;
    final delay = when.difference(DateTime.now());
    unawaited(
      enqueueNextSendRequest(
        delay: delay.isNegative ? Duration.zero : delay,
      ),
    );
  }

  @visibleForTesting
  Duration computeEnqueueDelay(Duration delay) {
    final now = DateTime.now();
    final nextAllowed = _nextSendAllowedAt;
    var adjusted = delay;
    if (adjusted < Duration.zero) {
      adjusted = Duration.zero;
    }
    if (nextAllowed == null) return adjusted;
    if (!nextAllowed.isAfter(now)) return adjusted;
    final backoffDelay = nextAllowed.difference(now);
    return backoffDelay > adjusted ? backoffDelay : adjusted;
  }

  Future<bool> _drainOutbox() async {
    for (var pass = 0; pass < _maxDrainPasses; pass++) {
      if (!_activityGate.canProcess) {
        _loggingService.captureEvent(
          'drain.paused activityGate.canProcess=false',
          domain: 'OUTBOX',
          subDomain: 'activityGate',
        );
        _recordBackoff(SyncTuning.outboxRetryDelay);
        return false;
      }
      final result = await _processor.processQueue();
      if (!result.shouldSchedule) {
        // Queue appears drained for now.
        return true;
      }
      final delay = result.nextDelay ?? Duration.zero;
      if (delay == Duration.zero) {
        // Immediate continue to the next item.
        continue;
      }
      // Non-zero delay indicates retry/error backoff; schedule and exit.
      _recordBackoff(delay);
      return false;
    }

    // Reached pass cap; proactively schedule an immediate continuation to avoid
    // stalling large backlogs on environments where external nudges are rare.
    // We attempt to check for pending items for observability, but schedule the
    // follow-up regardless as a safety net.
    try {
      final stillPending = (await _repository.fetchPending(
        limit: 1,
      )).isNotEmpty;
      _loggingService.captureEvent(
        'drain.passCap stillPending=$stillPending → enqueueImmediate',
        domain: 'OUTBOX',
        subDomain: 'drain',
      );
    } catch (_) {
      // best-effort logging only
    }
    await enqueueNextSendRequest(delay: Duration.zero);
    return false;
  }

  Future<void> sendNext() async {
    try {
      final enableMatrix = await _journalDb.getConfigFlag(
        enableMatrixFlag,
      );

      if (!enableMatrix) {
        return;
      }

      // State snapshot to aid debugging of stuck outbox scenarios.
      try {
        final loggedIn = _matrixService?.isLoggedIn() ?? false;
        final canProc = _activityGate.canProcess;
        final hasPending = (await _repository.fetchPending(
          limit: 1,
        )).isNotEmpty;
        _loggingService.captureEvent(
          'sendNext.state loggedIn=$loggedIn canProcess=$canProc pending=$hasPending',
          domain: 'OUTBOX',
          subDomain: 'sendNext',
        );
      } catch (_) {
        // best-effort only
      }

      // Pause processing while not logged in. Do not schedule immediate retries
      // from here to avoid spin while logged out. Normal triggers (enqueue,
      // connectivity regain, UI actions) will re-nudge the outbox after login.
      if (_matrixService != null && !_matrixService.isLoggedIn()) {
        _loggingService.captureEvent(
          'sendNext.loginGate.notLoggedIn',
          domain: 'OUTBOX',
          subDomain: 'sendNext',
        );
        // Notify listeners only when meaningful and outside startup grace:
        // - There are pending outbox items
        // - We are past the initial startup window
        final withinGrace =
            DateTime.now().difference(_createdAt) < _loginGateStartupGrace;
        if (!withinGrace && !_loginGateEventsController.isClosed) {
          final hasPending = (await _repository.fetchPending(
            limit: 1,
          )).isNotEmpty;
          if (hasPending) {
            _loginGateEventsController.add(null);
          }
        }
        return;
      }

      final nextAllowed = _nextSendAllowedAt;
      final now = DateTime.now();
      if (nextAllowed != null) {
        if (now.isBefore(nextAllowed)) {
          _scheduleBackoffAt(nextAllowed);
          return;
        }
        _nextSendAllowedAt = null;
        _backoffScheduledAt = null;
      }

      // Drain the outbox in a single runner callback to avoid leaving the
      // latest item unsent (which can manifest as receivers being one behind).
      final firstDrained = await _drainOutbox();
      if (!firstDrained) return;

      // Allow recent enqueues to settle then attempt one more drain.
      await Future<void>.delayed(_postDrainSettle);
      if (!_activityGate.canProcess) {
        _loggingService.captureEvent(
          'sendNext.postSettle.paused activityGate.canProcess=false',
          domain: 'OUTBOX',
          subDomain: 'activityGate',
        );
        _recordBackoff(SyncTuning.outboxRetryDelay);
        return;
      }
      await _drainOutbox();
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'OUTBOX',
        subDomain: 'sendNext',
        stackTrace: stackTrace,
      );
      _recordBackoff(const Duration(seconds: 15));
    }
  }

  Future<void> enqueueNextSendRequest({
    Duration delay = const Duration(milliseconds: 1),
  }) async {
    if (_isDisposed) return;
    final adjustedDelay = computeEnqueueDelay(delay);
    unawaited(
      Future<void>.delayed(adjustedDelay).then((_) {
        if (_isDisposed) return;
        _clientRunner.enqueueRequest(DateTime.now().millisecondsSinceEpoch);
        _loggingService.captureEvent('enqueueRequest() done', domain: 'OUTBOX');
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Message preparation helpers
  // ---------------------------------------------------------------------------

  /// Prepares a SyncJournalEntity by adding originatingHostId, attaching entry
  /// links, and merging covered vector clocks.
  Future<SyncJournalEntity> _prepareJournalEntity(
    SyncJournalEntity msg,
    String? host,
  ) async {
    var journalMsg = msg;

    // Add originating host ID (this device) for sequence tracking
    if (journalMsg.originatingHostId == null && host != null) {
      journalMsg = journalMsg.copyWith(originatingHostId: host);
    }

    // Attach entry links if available
    try {
      final links = await _journalDb.linksForEntryIdsBidirectional({
        journalMsg.id,
      });
      if (links.isNotEmpty) {
        final fromCount = links
            .where((link) => link.fromId == journalMsg.id)
            .length;
        final toCount = links
            .where((link) => link.toId == journalMsg.id)
            .length;
        // Cap embedded links to prevent oversized envelopes. Remaining
        // links still sync independently as SyncEntryLink messages.
        final capped = links.length > SyncTuning.maxEmbeddedEntryLinks
            ? links.sublist(links.length - SyncTuning.maxEmbeddedEntryLinks)
            : links;
        _loggingService.captureEvent(
          'enqueueMessage.attachedLinks id=${journalMsg.id} '
          'count=${links.length} embedded=${capped.length} '
          'from=$fromCount to=$toCount',
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage.attachLinks',
        );
        journalMsg = journalMsg.copyWith(entryLinks: capped);
      } else {
        _loggingService.captureEvent(
          'enqueueMessage.noLinks id=${journalMsg.id}',
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage.attachLinks',
        );
      }
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'OUTBOX',
        subDomain: 'enqueueMessage.fetchLinks',
        stackTrace: st,
      );
      // Continue with original message without links on error
    }

    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?journalMsg.coveredVectorClocks,
      journalMsg.vectorClock,
    ]);
    if (coveredClocks != journalMsg.coveredVectorClocks) {
      journalMsg = journalMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncJournalEntity',
        entryId: journalMsg.id,
        jsonPath: journalMsg.jsonPath,
        reason: 'ensure_current_clock_covered',
        assigned: journalMsg.vectorClock,
        coveredVectorClocks: coveredClocks,
      );
    }

    return journalMsg;
  }

  /// Prepares a SyncEntryLink by adding originatingHostId and merging covered
  /// vector clocks.
  Future<SyncEntryLink> _prepareEntryLink(
    SyncEntryLink msg,
    String? host,
  ) async {
    var linkMsg = msg;
    if (linkMsg.originatingHostId == null && host != null) {
      linkMsg = linkMsg.copyWith(originatingHostId: host);
    }
    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?linkMsg.coveredVectorClocks,
      linkMsg.entryLink.vectorClock,
    ]);
    if (coveredClocks != linkMsg.coveredVectorClocks) {
      linkMsg = linkMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncEntryLink',
        entryId: linkMsg.entryLink.id,
        reason: 'ensure_current_clock_covered',
        assigned: linkMsg.entryLink.vectorClock,
        coveredVectorClocks: coveredClocks,
      );
    }
    return linkMsg;
  }

  /// Prepares a SyncAgentEntity by adding originatingHostId and merging covered
  /// vector clocks.
  SyncAgentEntity _prepareAgentEntity(SyncAgentEntity msg, String? host) {
    var agentMsg = msg;
    if (agentMsg.originatingHostId == null && host != null) {
      agentMsg = agentMsg.copyWith(originatingHostId: host);
    }
    final vc = agentMsg.agentEntity?.vectorClock;
    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?agentMsg.coveredVectorClocks,
      vc,
    ]);
    if (coveredClocks != agentMsg.coveredVectorClocks) {
      agentMsg = agentMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncAgentEntity',
        entryId: agentMsg.agentEntity?.id,
        jsonPath: agentMsg.jsonPath,
        reason: 'ensure_current_clock_covered',
        assigned: vc,
        coveredVectorClocks: coveredClocks,
      );
    }
    return agentMsg;
  }

  /// Prepares a SyncAgentLink by adding originatingHostId and merging covered
  /// vector clocks.
  SyncAgentLink _prepareAgentLink(SyncAgentLink msg, String? host) {
    var linkMsg = msg;
    if (linkMsg.originatingHostId == null && host != null) {
      linkMsg = linkMsg.copyWith(originatingHostId: host);
    }
    final vc = linkMsg.agentLink?.vectorClock;
    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?linkMsg.coveredVectorClocks,
      vc,
    ]);
    if (coveredClocks != linkMsg.coveredVectorClocks) {
      linkMsg = linkMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncAgentLink',
        entryId: linkMsg.agentLink?.id,
        jsonPath: linkMsg.jsonPath,
        reason: 'ensure_current_clock_covered',
        assigned: vc,
        coveredVectorClocks: coveredClocks,
      );
    }
    return linkMsg;
  }

  /// Routes message preparation based on type.
  Future<SyncMessage> _prepareMessage(SyncMessage message, String? host) async {
    return switch (message) {
      final SyncJournalEntity msg => await _prepareJournalEntity(msg, host),
      final SyncEntryLink msg => await _prepareEntryLink(msg, host),
      final SyncAgentEntity msg => _prepareAgentEntity(msg, host),
      final SyncAgentLink msg => _prepareAgentLink(msg, host),
      _ => message,
    };
  }

  // ---------------------------------------------------------------------------
  // Per-type enqueue helpers
  // ---------------------------------------------------------------------------

  /// Enqueues a SyncJournalEntity. Returns true if merge happened (caller
  /// should not call enqueueNextSendRequest again).
  Future<bool> _enqueueJournalEntity({
    required SyncJournalEntity msg,
    required OutboxCompanion commonFields,
    required String? host,
    required String? hostHash,
  }) async {
    // Refresh JSON from DB before reading descriptor
    try {
      final latest = await _journalDb.journalEntityById(msg.id);
      if (latest != null) {
        final canonicalPath = entityPath(latest, _documentsDirectory);
        await _saveJson(canonicalPath, jsonEncode(latest));
      } else {
        _loggingService.captureEvent(
          'enqueueMessage.missingEntity id=${msg.id}',
          domain: 'MATRIX_SERVICE',
          subDomain: 'enqueueMessage',
        );
      }
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'enqueueMessage.refreshJson',
        stackTrace: stackTrace,
      );
    }

    final fullPath = '${_documentsDirectory.path}${msg.jsonPath}';
    final journalEntity = await readEntityFromJson(fullPath);

    File? attachment;
    final localCounter = journalEntity.meta.vectorClock?.vclock[host];

    journalEntity.maybeMap(
      journalAudio: (JournalAudio journalAudio) {
        if (msg.status == SyncEntryStatus.initial) {
          attachment = File(
            AudioUtils.getAudioPath(journalAudio, _documentsDirectory),
          );
        }
      },
      journalImage: (JournalImage journalImage) {
        if (msg.status == SyncEntryStatus.initial) {
          attachment = File(
            getFullImagePath(
              journalImage,
              documentsDirectory: _documentsDirectory.path,
            ),
          );
        }
      },
      orElse: () {},
    );

    var fileLength = 0;
    if (attachment != null) {
      try {
        fileLength = await attachment!.length();
      } catch (_) {
        fileLength = 0;
      }
    }
    final embeddedLinksCount = msg.entryLinks?.length ?? 0;

    // Check for existing pending outbox item for this entry (merge logic)
    final existingItem = await _syncDatabase.findPendingByEntryId(msg.id);

    if (existingItem != null) {
      // Merge: extract old VC and add to coveredVectorClocks
      try {
        final oldMessage = SyncMessage.fromJson(
          json.decode(existingItem.message) as Map<String, dynamic>,
        );

        if (oldMessage is SyncJournalEntity) {
          final latestVc = journalEntity.meta.vectorClock;
          final coveredClocks = VectorClock.mergeUniqueClocks([
            ...?oldMessage.coveredVectorClocks,
            ...?msg.coveredVectorClocks,
            oldMessage.vectorClock,
            // Also capture the current enqueue call's VC if it differs from
            // the latest. This handles the race condition where multiple
            // enqueue calls are in flight concurrently - each intermediate
            // VC must be captured to prevent false gaps.
            if (msg.vectorClock != null && msg.vectorClock != latestVc)
              msg.vectorClock,
            latestVc,
          ]);

          // Create merged message with updated VC and covered clocks
          final mergedMessage = msg.copyWith(
            vectorClock: latestVc,
            coveredVectorClocks: coveredClocks,
          );
          logVectorClockAssignment(
            _loggingService,
            subDomain: 'enqueue.merge',
            action: 'assign',
            type: 'SyncJournalEntity',
            entryId: msg.id,
            jsonPath: msg.jsonPath,
            reason: 'pending_merge_refresh',
            previous: msg.vectorClock,
            assigned: latestVc,
            coveredVectorClocks: coveredClocks,
            extras: {'oldVc': oldMessage.vectorClock?.vclock},
          );

          final mergedJson = json.encode(mergedMessage.toJson());
          final mergedPayloadSize = utf8.encode(mergedJson).length + fileLength;
          final mergedPriority = math.min(
            existingItem.priority,
            commonFields.priority.value,
          );
          final affectedRows = await _syncDatabase.updateOutboxMessage(
            itemId: existingItem.id,
            newMessage: mergedJson,
            newSubject: '$hostHash:$localCounter',
            payloadSize: mergedPayloadSize,
            priority: mergedPriority,
          );

          if (affectedRows == 0) {
            // Row was no longer pending — insert fresh row with merged data
            _loggingService.captureEvent(
              'enqueue MERGE-MISS type=SyncJournalEntity id=${msg.id} '
              '(row no longer pending, inserting fresh)',
              domain: 'OUTBOX',
              subDomain: 'enqueueMessage',
            );
            await _syncDatabase.addOutboxItem(
              commonFields.copyWith(
                subject: Value('$hostHash:$localCounter'),
                message: Value(mergedJson),
                payloadSize: Value(mergedPayloadSize),
                outboxEntryId: Value(msg.id),
                priority: Value(mergedPriority),
              ),
            );
          }

          // Log covered clocks for debugging
          final coveredVcStrings = coveredClocks
              ?.map((vc) => vc.vclock)
              .toList();
          _loggingService.captureEvent(
            'enqueue MERGED type=SyncJournalEntity id=${msg.id} '
            'coveredClocks=${coveredClocks?.length ?? 0} covered=$coveredVcStrings '
            'latest=${latestVc?.vclock}',
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          );

          // Still record in sequence log for the new counter
          if (_sequenceLogService != null &&
              journalEntity.meta.vectorClock != null) {
            try {
              await _sequenceLogService.recordSentEntry(
                entryId: journalEntity.meta.id,
                vectorClock: journalEntity.meta.vectorClock!,
              );
            } catch (e, st) {
              _loggingService.captureException(
                e,
                domain: 'SYNC_SEQUENCE',
                subDomain: 'recordSent',
                stackTrace: st,
              );
            }
          }

          unawaited(enqueueNextSendRequest(delay: const Duration(seconds: 1)));
          return true; // Merge happened - don't create new item
        }
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage.merge',
          stackTrace: st,
        );
        // Fall through to create new item on merge error
      }
    }

    // No existing item or merge failed - create new outbox item with entryId.
    // Enrich covered VCs from the sequence log so receivers can resolve
    // intermediate counters even when the predecessor was already sent.
    final enrichedCovered = await _enrichCoveredVcsFromSequenceLog(
      msg.id,
      msg.coveredVectorClocks,
    );
    var outboxMsg = msg;
    if (enrichedCovered != msg.coveredVectorClocks) {
      outboxMsg = msg.copyWith(coveredVectorClocks: enrichedCovered);
    }
    final outboxJson = json.encode(outboxMsg.toJson());
    final outboxSize = utf8.encode(outboxJson).length + fileLength;
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        filePath: Value(
          (fileLength > 0) ? getRelativeAssetPath(attachment!.path) : null,
        ),
        subject: Value('$hostHash:$localCounter'),
        outboxEntryId: Value(msg.id),
        message: Value(outboxJson),
        payloadSize: Value(outboxSize),
      ),
    );
    _loggingService.captureEvent(
      'enqueue type=SyncJournalEntity subject=${'$hostHash:$localCounter'} '
      'id=${msg.id} attachBytes=$fileLength embeddedLinks=$embeddedLinksCount',
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );

    // Record in sequence log for backfill support (self-healing sync)
    if (_sequenceLogService != null && journalEntity.meta.vectorClock != null) {
      try {
        await _sequenceLogService.recordSentEntry(
          entryId: journalEntity.meta.id,
          vectorClock: journalEntity.meta.vectorClock!,
        );
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'SYNC_SEQUENCE',
          subDomain: 'recordSent',
          stackTrace: st,
        );
      }
    }

    return false; // No merge - caller should call enqueueNextSendRequest
  }

  /// Looks up the last sent vector clock for [entryId] from the sequence log
  /// and merges it into [existingCovered].  Returns [existingCovered] unchanged
  /// when no previous send is found or the sequence log service is absent.
  Future<List<VectorClock>?> _enrichCoveredVcsFromSequenceLog(
    String entryId,
    List<VectorClock>? existingCovered,
  ) async {
    if (_sequenceLogService == null) return existingCovered;
    try {
      final lastSentVc = await _sequenceLogService
          .getLastSentVectorClockForEntry(entryId);
      if (lastSentVc == null) return existingCovered;
      return VectorClock.mergeUniqueClocks([
        ...?existingCovered,
        lastSentVc,
      ]);
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_SEQUENCE',
        subDomain: 'enrichCoveredVcs',
        stackTrace: st,
      );
      return existingCovered;
    }
  }

  /// Enqueues a SyncEntryLink. Returns true if merge happened (caller should
  /// not call enqueueNextSendRequest again).
  Future<bool> _enqueueEntryLink({
    required SyncEntryLink msg,
    required OutboxCompanion commonFields,
    required String? host,
    required String? hostHash,
  }) async {
    final linkId = msg.entryLink.id;
    final localCounter = msg.entryLink.vectorClock?.vclock[host];
    final subject = localCounter == null
        ? '$hostHash:link'
        : '$hostHash:link:$localCounter';

    // Check for existing pending outbox item for this entry link (merge logic)
    final existingItem = await _syncDatabase.findPendingByEntryId(linkId);

    if (existingItem != null) {
      // Merge: extract old VC and add to coveredVectorClocks
      try {
        final oldMessage = SyncMessage.fromJson(
          json.decode(existingItem.message) as Map<String, dynamic>,
        );

        if (oldMessage is SyncEntryLink) {
          final coveredClocks = VectorClock.mergeUniqueClocks([
            ...?oldMessage.coveredVectorClocks,
            ...?msg.coveredVectorClocks,
            oldMessage.entryLink.vectorClock,
            msg.entryLink.vectorClock,
          ]);

          // Create merged message with covered clocks
          // Note: Unlike journal entities, entry links don't refresh from DB,
          // so each enqueue's VC is captured correctly when oldMessage.VC
          // is added to coveredClocks in subsequent merges.
          final mergedMessage = msg.copyWith(
            coveredVectorClocks: coveredClocks,
          );
          logVectorClockAssignment(
            _loggingService,
            subDomain: 'enqueue.merge',
            action: 'assign',
            type: 'SyncEntryLink',
            entryId: linkId,
            reason: 'pending_merge_cover',
            previous: msg.entryLink.vectorClock,
            assigned: msg.entryLink.vectorClock,
            coveredVectorClocks: coveredClocks,
            extras: {'oldVc': oldMessage.entryLink.vectorClock?.vclock},
          );

          final mergedJson = json.encode(mergedMessage.toJson());
          final mergedSize = utf8.encode(mergedJson).length;
          final mergedPriority = math.min(
            existingItem.priority,
            commonFields.priority.value,
          );
          final affectedRows = await _syncDatabase.updateOutboxMessage(
            itemId: existingItem.id,
            newMessage: mergedJson,
            newSubject: subject,
            payloadSize: mergedSize,
            priority: mergedPriority,
          );

          if (affectedRows == 0) {
            // Row was no longer pending — insert fresh row with merged data
            _loggingService.captureEvent(
              'enqueue MERGE-MISS type=SyncEntryLink id=$linkId '
              '(row no longer pending, inserting fresh)',
              domain: 'OUTBOX',
              subDomain: 'enqueueMessage',
            );
            await _syncDatabase.addOutboxItem(
              commonFields.copyWith(
                subject: Value(subject),
                message: Value(mergedJson),
                payloadSize: Value(mergedSize),
                outboxEntryId: Value(linkId),
                priority: Value(mergedPriority),
              ),
            );
          }

          // Log covered clocks for debugging
          final coveredVcStrings = coveredClocks
              ?.map((vc) => vc.vclock)
              .toList();
          final latestVcStr = msg.entryLink.vectorClock?.vclock;
          _loggingService.captureEvent(
            'enqueue MERGED type=SyncEntryLink id=$linkId '
            'coveredClocks=${coveredClocks?.length ?? 0} covered=$coveredVcStrings '
            'latest=$latestVcStr',
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          );

          // Still record in sequence log for the new counter
          if (_sequenceLogService != null &&
              msg.entryLink.vectorClock != null) {
            try {
              await _sequenceLogService.recordSentEntryLink(
                linkId: linkId,
                vectorClock: msg.entryLink.vectorClock!,
              );
            } catch (e, st) {
              _loggingService.captureException(
                e,
                domain: 'SYNC_SEQUENCE',
                subDomain: 'recordSent',
                stackTrace: st,
              );
            }
          }

          unawaited(enqueueNextSendRequest(delay: const Duration(seconds: 1)));
          return true; // Merge happened - don't create new item
        }
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage.merge',
          stackTrace: st,
        );
        // Fall through to create new item on merge error
      }
    }

    // No existing item or merge failed - create new outbox item with entryId.
    // Enrich covered VCs from the sequence log for already-sent predecessors.
    final enrichedLinkCovered = await _enrichCoveredVcsFromSequenceLog(
      linkId,
      msg.coveredVectorClocks,
    );
    var outboxLinkMsg = msg;
    if (enrichedLinkCovered != msg.coveredVectorClocks) {
      outboxLinkMsg = msg.copyWith(coveredVectorClocks: enrichedLinkCovered);
    }
    final outboxLinkJson = json.encode(outboxLinkMsg.toJson());
    final outboxLinkSize = utf8.encode(outboxLinkJson).length;
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value(subject),
        outboxEntryId: Value(linkId),
        message: Value(outboxLinkJson),
        payloadSize: Value(outboxLinkSize),
      ),
    );
    _loggingService.captureEvent(
      'enqueue type=SyncEntryLink subject=$subject '
      'from=${msg.entryLink.fromId} to=${msg.entryLink.toId}',
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );

    // Record in sequence log for backfill support (self-healing sync)
    if (_sequenceLogService != null && msg.entryLink.vectorClock != null) {
      try {
        await _sequenceLogService.recordSentEntryLink(
          linkId: linkId,
          vectorClock: msg.entryLink.vectorClock!,
        );
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'SYNC_SEQUENCE',
          subDomain: 'recordSent',
          stackTrace: st,
        );
      }
    }

    return false; // No merge - caller should call enqueueNextSendRequest
  }

  /// Shared helper for simple message types that don't require merge logic.
  /// Adds the item to the outbox and logs the event.
  Future<bool> _enqueueSimple({
    required OutboxCompanion commonFields,
    required String subject,
    required String logMessage,
  }) async {
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(subject: Value(subject)),
    );
    _loggingService.captureEvent(
      logMessage,
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );
    return false;
  }

  Future<bool> _enqueueEntityDefinition({
    required SyncEntityDefinition msg,
    required OutboxCompanion commonFields,
    required String? host,
    required String? hostHash,
  }) async {
    final localCounter = msg.entityDefinition.vectorClock?.vclock[host];
    final subject = '$hostHash:$localCounter';
    return _enqueueSimple(
      commonFields: commonFields,
      subject: subject,
      logMessage:
          'enqueue type=SyncEntityDefinition '
          'subject=$subject id=${msg.entityDefinition.id}',
    );
  }

  Future<bool> _enqueueAiConfig({
    required SyncAiConfig msg,
    required OutboxCompanion commonFields,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: 'aiConfig',
    logMessage:
        'enqueue type=SyncAiConfig subject=aiConfig '
        'id=${msg.aiConfig.id}',
  );

  Future<bool> _enqueueAiConfigDelete({
    required SyncAiConfigDelete msg,
    required OutboxCompanion commonFields,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: 'aiConfigDelete',
    logMessage:
        'enqueue type=SyncAiConfigDelete subject=aiConfigDelete '
        'id=${msg.id}',
  );

  Future<bool> _enqueueTagEntity({
    required SyncTagEntity msg,
    required OutboxCompanion commonFields,
    required String? hostHash,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: '$hostHash:tag',
    logMessage:
        'enqueue type=SyncTagEntity subject=$hostHash:tag '
        'id=${msg.tagEntity.id}',
  );

  Future<bool> _enqueueThemingSelection({
    required SyncThemingSelection msg,
    required OutboxCompanion commonFields,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: 'themingSelection',
    logMessage:
        'enqueue type=SyncThemingSelection subject=themingSelection '
        'light=${msg.lightThemeName} dark=${msg.darkThemeName} '
        'mode=${msg.themeMode}',
  );

  Future<bool> _enqueueBackfillRequest({
    required SyncBackfillRequest msg,
    required OutboxCompanion commonFields,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: 'backfillRequest:batch:${msg.entries.length}',
    logMessage:
        'enqueue type=SyncBackfillRequest '
        'entries=${msg.entries.length}',
  );

  Future<bool> _enqueueBackfillResponse({
    required SyncBackfillResponse msg,
    required OutboxCompanion commonFields,
  }) => _enqueueSimple(
    commonFields: commonFields,
    subject: 'backfillResponse:${msg.hostId}:${msg.counter}',
    logMessage:
        'enqueue type=SyncBackfillResponse hostId=${msg.hostId} '
        'counter=${msg.counter} deleted=${msg.deleted}',
  );

  Future<bool> _enqueueAgentEntity({
    required SyncAgentEntity msg,
    required OutboxCompanion commonFields,
  }) async {
    final entity = msg.agentEntity;
    if (entity == null) {
      _loggingService.captureEvent(
        'enqueue.skip agentEntity is null',
        domain: 'OUTBOX',
        subDomain: 'enqueueMessage',
      );
      return false;
    }
    return _enqueueAgentPayload(
      id: entity.id,
      payloadJson: json.encode(entity.toJson()),
      relativePath: relativeAgentEntityPath(entity.id),
      enrichedMessage: msg.copyWith(
        jsonPath: relativeAgentEntityPath(entity.id),
      ),
      subjectPrefix: 'agentEntity',
      typeName: 'SyncAgentEntity',
      commonFields: commonFields,
      vectorClock: entity.vectorClock,
      payloadType: SyncSequencePayloadType.agentEntity,
    );
  }

  Future<bool> _enqueueAgentLink({
    required SyncAgentLink msg,
    required OutboxCompanion commonFields,
  }) async {
    final link = msg.agentLink;
    if (link == null) {
      _loggingService.captureEvent(
        'enqueue.skip agentLink is null',
        domain: 'OUTBOX',
        subDomain: 'enqueueMessage',
      );
      return false;
    }
    return _enqueueAgentPayload(
      id: link.id,
      payloadJson: json.encode(link.toJson()),
      relativePath: relativeAgentLinkPath(link.id),
      enrichedMessage: msg.copyWith(jsonPath: relativeAgentLinkPath(link.id)),
      subjectPrefix: 'agentLink',
      typeName: 'SyncAgentLink',
      commonFields: commonFields,
      vectorClock: link.vectorClock,
      payloadType: SyncSequencePayloadType.agentLink,
    );
  }

  /// Shared implementation for enqueuing agent entities and links.
  /// Saves [payloadJson] to disk, builds an enriched outbox message from
  /// [enrichedMessage], and either merges into an existing pending item or
  /// creates a new one. Records sent entries in the sequence log when a
  /// [vectorClock] is provided.
  Future<bool> _enqueueAgentPayload({
    required String id,
    required String payloadJson,
    required String relativePath,
    required SyncMessage enrichedMessage,
    required String subjectPrefix,
    required String typeName,
    required OutboxCompanion commonFields,
    required VectorClock? vectorClock,
    required SyncSequencePayloadType payloadType,
  }) async {
    final relativeJoined = p.joinAll(
      relativePath.split('/').where((part) => part.isNotEmpty),
    );
    final docsRoot = p.normalize(_documentsDirectory.path);
    final fullPath = p.normalize(p.join(docsRoot, relativeJoined));
    final subject = '$subjectPrefix:$id';

    if (!p.isWithin(docsRoot, fullPath)) {
      _loggingService.captureEvent(
        'enqueue.skip invalid agent payload path: $relativePath',
        domain: 'OUTBOX',
        subDomain: 'enqueueMessage',
      );
      return false;
    }

    try {
      await _saveJson(fullPath, payloadJson);
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'OUTBOX',
        subDomain: 'enqueueMessage.saveAgentPayload',
        stackTrace: stackTrace,
      );
      // Fallback: enqueue with inline payload so the sender's legacy
      // enrichment path can write the file and upload on retry.
      await _syncDatabase.addOutboxItem(
        commonFields.copyWith(
          subject: Value(subject),
          outboxEntryId: Value(id),
        ),
      );
      return false;
    }

    final existingItem = await _syncDatabase.findPendingByEntryId(id);

    if (existingItem != null) {
      // Merge: extract old VC and add to coveredVectorClocks so receivers
      // can mark the old counter as covered instead of creating a gap.
      var mergedMessage = enrichedMessage;
      try {
        final oldMessage = SyncMessage.fromJson(
          json.decode(existingItem.message) as Map<String, dynamic>,
        );

        final VectorClock? oldVc;
        final List<VectorClock>? oldCovered;
        if (oldMessage is SyncAgentEntity) {
          oldVc = oldMessage.agentEntity?.vectorClock;
          oldCovered = oldMessage.coveredVectorClocks;
        } else if (oldMessage is SyncAgentLink) {
          oldVc = oldMessage.agentLink?.vectorClock;
          oldCovered = oldMessage.coveredVectorClocks;
        } else {
          oldVc = null;
          oldCovered = null;
        }

        final List<VectorClock>? newCovered;
        if (mergedMessage case final SyncAgentEntity entity) {
          newCovered = entity.coveredVectorClocks;
        } else if (mergedMessage case final SyncAgentLink link) {
          newCovered = link.coveredVectorClocks;
        } else {
          newCovered = null;
        }

        final coveredClocks = VectorClock.mergeUniqueClocks([
          ...?oldCovered,
          ...?newCovered,
          oldVc,
          vectorClock,
        ]);

        if (mergedMessage case final SyncAgentEntity entity) {
          mergedMessage = entity.copyWith(
            coveredVectorClocks: coveredClocks,
          );
          logVectorClockAssignment(
            _loggingService,
            subDomain: 'enqueue.merge',
            action: 'assign',
            type: 'SyncAgentEntity',
            entryId: id,
            jsonPath: entity.jsonPath,
            reason: 'pending_merge_cover',
            previous: oldVc,
            assigned: vectorClock,
            coveredVectorClocks: coveredClocks,
          );
        } else if (mergedMessage case final SyncAgentLink link) {
          mergedMessage = link.copyWith(
            coveredVectorClocks: coveredClocks,
          );
          logVectorClockAssignment(
            _loggingService,
            subDomain: 'enqueue.merge',
            action: 'assign',
            type: 'SyncAgentLink',
            entryId: id,
            jsonPath: link.jsonPath,
            reason: 'pending_merge_cover',
            previous: oldVc,
            assigned: vectorClock,
            coveredVectorClocks: coveredClocks,
          );
        }

        final coveredVcStrings = coveredClocks?.map((vc) => vc.vclock).toList();
        _loggingService.captureEvent(
          'enqueue MERGED type=$typeName id=$id '
          'coveredClocks=${coveredClocks?.length ?? 0} '
          'covered=$coveredVcStrings',
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
        );
      } catch (e, st) {
        _loggingService
          ..captureException(
            e,
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage.agentMerge',
            stackTrace: st,
          )
          // Fallback: proceed without merging covered clocks
          ..captureEvent(
            'enqueue MERGED type=$typeName id=$id (no VC merge)',
            domain: 'OUTBOX',
            subDomain: 'enqueueMessage',
          );
      }

      final mergedJson = json.encode(mergedMessage.toJson());
      final mergedSize = utf8.encode(mergedJson).length;
      final mergedPriority = math.min(
        existingItem.priority,
        commonFields.priority.value,
      );
      final affectedRows = await _syncDatabase.updateOutboxMessage(
        itemId: existingItem.id,
        newMessage: mergedJson,
        newSubject: subject,
        payloadSize: mergedSize,
        priority: mergedPriority,
      );

      if (affectedRows == 0) {
        // Row was no longer pending (sent or in-flight between lookup and
        // update). Insert a fresh row with the merged message so nothing is
        // lost.
        _loggingService.captureEvent(
          'enqueue MERGE-MISS type=$typeName id=$id '
          '(row no longer pending, inserting fresh)',
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
        );
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            subject: Value(subject),
            message: Value(mergedJson),
            payloadSize: Value(mergedSize),
            priority: Value(mergedPriority),
            outboxEntryId: Value(id),
          ),
        );
      }

      // Still record in sequence log for the new counter
      await _recordAgentSent(
        entryId: id,
        vectorClock: vectorClock,
        payloadType: payloadType,
      );

      unawaited(enqueueNextSendRequest(delay: const Duration(seconds: 1)));
      return true;
    }

    // Enrich covered VCs from the sequence log for already-sent predecessors.
    final initialCovered = switch (enrichedMessage) {
      final SyncAgentEntity e => e.coveredVectorClocks,
      final SyncAgentLink l => l.coveredVectorClocks,
      _ => null,
    };
    final enrichedAgentCovered = await _enrichCoveredVcsFromSequenceLog(
      id,
      initialCovered,
    );
    var outboxAgentMsg = enrichedMessage;
    if (enrichedAgentCovered != initialCovered) {
      outboxAgentMsg = switch (outboxAgentMsg) {
        final SyncAgentEntity e => e.copyWith(
          coveredVectorClocks: enrichedAgentCovered,
        ),
        final SyncAgentLink l => l.copyWith(
          coveredVectorClocks: enrichedAgentCovered,
        ),
        _ => outboxAgentMsg,
      };
    }
    final outboxAgentJson = json.encode(outboxAgentMsg.toJson());
    final outboxAgentSize = utf8.encode(outboxAgentJson).length;
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value(subject),
        message: Value(outboxAgentJson),
        outboxEntryId: Value(id),
        payloadSize: Value(outboxAgentSize),
      ),
    );
    _loggingService.captureEvent(
      'enqueue type=$typeName subject=$subject',
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );

    // Record in sequence log for backfill support (self-healing sync)
    await _recordAgentSent(
      entryId: id,
      vectorClock: vectorClock,
      payloadType: payloadType,
    );

    return false;
  }

  /// Records an agent entity or link in the sequence log.
  Future<void> _recordAgentSent({
    required String entryId,
    required VectorClock? vectorClock,
    required SyncSequencePayloadType payloadType,
  }) async {
    if (_sequenceLogService != null && vectorClock != null) {
      try {
        await _sequenceLogService.recordSentEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          payloadType: payloadType,
        );
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'SYNC_SEQUENCE',
          subDomain: 'recordSent',
          stackTrace: st,
        );
      }
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _clientRunner.close();
    await _connectivitySubscription?.cancel();
    await _loginSubscription?.cancel();
    await _outboxCountSubscription?.cancel();
    _watchdogTimer?.cancel();
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
