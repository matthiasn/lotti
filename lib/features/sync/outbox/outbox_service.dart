import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/client_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';

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
  })  : _syncDatabase = syncDatabase,
        _loggingService = loggingService,
        _vectorClockService = vectorClockService,
        _journalDb = journalDb,
        _documentsDirectory = documentsDirectory,
        _saveJson = saveJsonHandler ?? saveJson,
        _activityGate = activityGate ??
            UserActivityGate(
              activityService: userActivityService,
              idleThreshold: SyncTuning.outboxIdleThreshold,
            ),
        _ownsActivityGate = ownsActivityGate ?? activityGate == null,
        _matrixService = matrixService,
        _connectivityStream = connectivityStream,
        _sequenceLogService = sequenceLogService {
    // Runtime validation that works in release builds
    if (messageSender == null && matrixService == null) {
      throw ArgumentError(
        'Either messageSender or matrixService must be provided.',
      );
    }

    _repository = repository ??
        DatabaseOutboxRepository(
          syncDatabase,
          maxRetries: maxRetries,
        );
    _messageSender = messageSender ?? MatrixOutboxMessageSender(matrixService!);
    _processor = processor ??
        OutboxProcessor(
          repository: _repository,
          messageSender: _messageSender,
          loggingService: _loggingService,
          maxRetriesOverride: maxRetries,
        );

    _startRunner();

    // Connectivity regain: nudge the outbox to attempt sending. If the client
    // is not yet logged in, schedule a couple of bounded follow-up nudges and
    // rely on the login-state subscription to trigger a send once login
    // completes.
    _connectivitySubscription =
        (_connectivityStream ?? Connectivity().onConnectivityChanged)
            .listen((List<ConnectivityResult> result) {
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
            _matrixService != null && !_matrixService!.isLoggedIn();
        if (notLoggedIn) {
          unawaited(enqueueNextSendRequest(delay: const Duration(seconds: 1)));
          unawaited(enqueueNextSendRequest(delay: const Duration(seconds: 5)));
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
    _watchdogTimer =
        Timer.periodic(SyncTuning.outboxWatchdogInterval, (Timer _) async {
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
        final hasPending =
            (await _repository.fetchPending(limit: 1)).isNotEmpty;
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
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final hostHash = await _vectorClockService.getHostHash();
      final host = await _vectorClockService.getHost();

      // Prepare message (attach links, add originating host ID, merge covered clocks)
      final messageToEnqueue = await _prepareMessage(syncMessage, host);

      final jsonString = json.encode(messageToEnqueue);
      final commonFields = OutboxCompanion(
        status: Value(OutboxStatus.pending.index),
        message: Value(jsonString),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
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
      };

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

  static const int _maxDrainPasses = 20;
  static const Duration _postDrainSettle = Duration(milliseconds: 250);

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
      final stillPending =
          (await _repository.fetchPending(limit: 1)).isNotEmpty;
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
        final hasPending =
            (await _repository.fetchPending(limit: 1)).isNotEmpty;
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
      if (_matrixService != null && !_matrixService!.isLoggedIn()) {
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
          final hasPending =
              (await _repository.fetchPending(limit: 1)).isNotEmpty;
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
      final links =
          await _journalDb.linksForEntryIdsBidirectional({journalMsg.id});
      if (links.isNotEmpty) {
        final fromCount =
            links.where((link) => link.fromId == journalMsg.id).length;
        final toCount =
            links.where((link) => link.toId == journalMsg.id).length;
        _loggingService.captureEvent(
          'enqueueMessage.attachedLinks id=${journalMsg.id} '
          'count=${links.length} from=$fromCount to=$toCount',
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage.attachLinks',
        );
        journalMsg = journalMsg.copyWith(entryLinks: links);
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
    }

    return journalMsg;
  }

  /// Prepares a SyncEntryLink by adding originatingHostId and merging covered
  /// vector clocks.
  Future<SyncEntryLink> _prepareEntryLink(
      SyncEntryLink msg, String? host) async {
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
    }
    return linkMsg;
  }

  /// Routes message preparation based on type.
  Future<SyncMessage> _prepareMessage(SyncMessage message, String? host) async {
    return switch (message) {
      final SyncJournalEntity msg => await _prepareJournalEntity(msg, host),
      final SyncEntryLink msg => await _prepareEntryLink(msg, host),
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
          attachment =
              File(AudioUtils.getAudioPath(journalAudio, _documentsDirectory));
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

    final fileLength = attachment?.lengthSync() ?? 0;
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
            // enqueue calls are in flight due to the 200ms delay - each
            // intermediate VC must be captured to prevent false gaps.
            if (msg.vectorClock != null && msg.vectorClock != latestVc)
              msg.vectorClock,
            latestVc,
          ]);

          // Create merged message with updated VC and covered clocks
          final mergedMessage = msg.copyWith(
            vectorClock: latestVc,
            coveredVectorClocks: coveredClocks,
          );

          await _syncDatabase.updateOutboxMessage(
            itemId: existingItem.id,
            newMessage: json.encode(mergedMessage.toJson()),
            newSubject: '$hostHash:$localCounter',
          );

          // Log covered clocks for debugging
          final coveredVcStrings =
              coveredClocks?.map((vc) => vc.vclock).toList();
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
              await _sequenceLogService!.recordSentEntry(
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

    // No existing item or merge failed - create new outbox item with entryId
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        filePath: Value(
          (fileLength > 0) ? getRelativeAssetPath(attachment!.path) : null,
        ),
        subject: Value('$hostHash:$localCounter'),
        outboxEntryId: Value(msg.id),
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
        await _sequenceLogService!.recordSentEntry(
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
          final mergedMessage =
              msg.copyWith(coveredVectorClocks: coveredClocks);

          await _syncDatabase.updateOutboxMessage(
            itemId: existingItem.id,
            newMessage: json.encode(mergedMessage.toJson()),
            newSubject: subject,
          );

          // Log covered clocks for debugging
          final coveredVcStrings =
              coveredClocks?.map((vc) => vc.vclock).toList();
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
              await _sequenceLogService!.recordSentEntryLink(
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

    // No existing item or merge failed - create new outbox item with entryId
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value(subject),
        outboxEntryId: Value(linkId),
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
        await _sequenceLogService!.recordSentEntryLink(
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

  Future<bool> _enqueueEntityDefinition({
    required SyncEntityDefinition msg,
    required OutboxCompanion commonFields,
    required String? host,
    required String? hostHash,
  }) async {
    final localCounter = msg.entityDefinition.vectorClock?.vclock[host];
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(subject: Value('$hostHash:$localCounter')),
    );
    _loggingService.captureEvent(
      'enqueue type=SyncEntityDefinition '
      'subject=$hostHash:$localCounter id=${msg.entityDefinition.id}',
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );
    return false;
  }

  Future<bool> _enqueueAiConfig({
    required SyncAiConfig msg,
    required OutboxCompanion commonFields,
  }) async {
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(subject: const Value('aiConfig')),
    );
    _loggingService.captureEvent(
      'enqueue type=SyncAiConfig subject=aiConfig id=${msg.aiConfig.id}',
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );
    return false;
  }

  Future<bool> _enqueueAiConfigDelete({
    required SyncAiConfigDelete msg,
    required OutboxCompanion commonFields,
  }) async {
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(subject: const Value('aiConfigDelete')),
    );
    _loggingService.captureEvent(
      'enqueue type=SyncAiConfigDelete subject=aiConfigDelete id=${msg.id}',
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );
    return false;
  }

  Future<bool> _enqueueTagEntity({
    required SyncTagEntity msg,
    required OutboxCompanion commonFields,
    required String? hostHash,
  }) async {
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(subject: Value('$hostHash:tag')),
    );
    _loggingService.captureEvent(
      'enqueue type=SyncTagEntity subject=$hostHash:tag '
      'id=${msg.tagEntity.id}',
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );
    return false;
  }

  Future<bool> _enqueueThemingSelection({
    required SyncThemingSelection msg,
    required OutboxCompanion commonFields,
  }) async {
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(subject: const Value('themingSelection')),
    );
    _loggingService.captureEvent(
      'enqueue type=SyncThemingSelection subject=themingSelection '
      'light=${msg.lightThemeName} dark=${msg.darkThemeName} '
      'mode=${msg.themeMode}',
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );
    return false;
  }

  Future<bool> _enqueueBackfillRequest({
    required SyncBackfillRequest msg,
    required OutboxCompanion commonFields,
  }) async {
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value('backfillRequest:batch:${msg.entries.length}'),
      ),
    );
    _loggingService.captureEvent(
      'enqueue type=SyncBackfillRequest entries=${msg.entries.length}',
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );
    return false;
  }

  Future<bool> _enqueueBackfillResponse({
    required SyncBackfillResponse msg,
    required OutboxCompanion commonFields,
  }) async {
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value(
          'backfillResponse:${msg.hostId}:${msg.counter}',
        ),
      ),
    );
    _loggingService.captureEvent(
      'enqueue type=SyncBackfillResponse hostId=${msg.hostId} '
      'counter=${msg.counter} deleted=${msg.deleted}',
      domain: 'OUTBOX',
      subDomain: 'enqueueMessage',
    );
    return false;
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
