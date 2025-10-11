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
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';

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
  })  : _syncDatabase = syncDatabase,
        _loggingService = loggingService,
        _vectorClockService = vectorClockService,
        _journalDb = journalDb,
        _documentsDirectory = documentsDirectory,
        _activityGate = activityGate ??
            UserActivityGate(
              activityService: userActivityService,
            ),
        _ownsActivityGate = ownsActivityGate ?? activityGate == null {
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
        );

    _startRunner();

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      if ({
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
      }.intersection(result.toSet()).isNotEmpty) {
        _clientRunner.enqueueRequest(DateTime.now().millisecondsSinceEpoch);
      }
    });
  }

  final LoggingService _loggingService;
  final SyncDatabase _syncDatabase;
  final VectorClockService _vectorClockService;
  final JournalDb _journalDb;
  final Directory _documentsDirectory;
  final UserActivityGate _activityGate;
  final bool _ownsActivityGate;
  late final OutboxRepository _repository;
  late final OutboxMessageSender _messageSender;
  late final OutboxProcessor _processor;

  late ClientRunner<int> _clientRunner;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  void _startRunner() {
    _clientRunner = ClientRunner<int>(
      callback: (event) async {
        await _activityGate.waitUntilIdle();
        await sendNext();
      },
    );
  }

  Future<List<OutboxItem>> getNextItems() async {
    return _syncDatabase.oldestOutboxItems(10);
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final hostHash = await _vectorClockService.getHostHash();
      final host = await _vectorClockService.getHost();
      final jsonString = json.encode(syncMessage);
      final docDir = _documentsDirectory;

      final commonFields = OutboxCompanion(
        status: Value(OutboxStatus.pending.index),
        message: Value(jsonString),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );

      if (syncMessage is SyncJournalEntity) {
        final fullPath = '${docDir.path}${syncMessage.jsonPath}';
        final journalEntity = await readEntityFromJson(fullPath);

        File? attachment;
        final localCounter = journalEntity.meta.vectorClock?.vclock[host];

        journalEntity.maybeMap(
          journalAudio: (JournalAudio journalAudio) {
            if (syncMessage.status == SyncEntryStatus.initial) {
              attachment = File(AudioUtils.getAudioPath(journalAudio, docDir));
            }
          },
          journalImage: (JournalImage journalImage) {
            if (syncMessage.status == SyncEntryStatus.initial) {
              attachment = File(
                getFullImagePath(
                  journalImage,
                  documentsDirectory: docDir.path,
                ),
              );
            }
          },
          orElse: () {},
        );

        final fileLength = attachment?.lengthSync() ?? 0;
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            filePath: Value(
              (fileLength > 0) ? getRelativeAssetPath(attachment!.path) : null,
            ),
            subject: Value('$hostHash:$localCounter'),
          ),
        );
      }

      if (syncMessage is SyncEntityDefinition) {
        final localCounter =
            syncMessage.entityDefinition.vectorClock?.vclock[host];

        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            subject: Value('$hostHash:$localCounter'),
          ),
        );
      }

      if (syncMessage is SyncEntryLink) {
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(subject: Value('$hostHash:link')),
        );
      }

      if (syncMessage is SyncAiConfig) {
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(subject: const Value('aiConfig')),
        );
      }

      if (syncMessage is SyncAiConfigDelete) {
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(subject: const Value('aiConfigDelete')),
        );
      }

      if (syncMessage is SyncTagEntity) {
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            subject: Value('$hostHash:tag'),
          ),
        );
      }
      unawaited(enqueueNextSendRequest(delay: const Duration(seconds: 1)));
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

  Future<bool> _drainOutbox() async {
    for (var pass = 0; pass < _maxDrainPasses; pass++) {
      final result = await _processor.processQueue();
      if (!result.shouldSchedule) {
        return true; // drained without needing a scheduled retry
      }
      final delay = result.nextDelay ?? Duration.zero;
      if (delay == Duration.zero) {
        // Immediate continue to the next item.
        continue;
      }
      // Non-zero delay indicates retry/error backoff; schedule and exit.
      await enqueueNextSendRequest(delay: delay);
      return false; // scheduled
    }
    return true;
  }

  Future<void> sendNext() async {
    try {
      final enableMatrix = await _journalDb.getConfigFlag(
        enableMatrixFlag,
      );

      if (!enableMatrix) {
        return;
      }

      // Drain the outbox in a single runner callback to avoid leaving the
      // latest item unsent (which can manifest as receivers being one behind).
      final firstDrained = await _drainOutbox();
      if (!firstDrained) return;

      // Allow recent enqueues to settle then attempt one more drain.
      await Future<void>.delayed(_postDrainSettle);
      await _drainOutbox();
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'OUTBOX',
        subDomain: 'sendNext',
        stackTrace: stackTrace,
      );
      await enqueueNextSendRequest(delay: const Duration(seconds: 15));
    }
  }

  Future<void> enqueueNextSendRequest({
    Duration delay = const Duration(milliseconds: 1),
  }) async {
    unawaited(
      Future<void>.delayed(delay).then((_) {
        _clientRunner.enqueueRequest(DateTime.now().millisecondsSinceEpoch);
        _loggingService.captureEvent('enqueueRequest() done', domain: 'OUTBOX');
      }),
    );
  }

  Future<void> dispose() async {
    _clientRunner.close();
    await _connectivitySubscription?.cancel();
    if (_ownsActivityGate) {
      await _activityGate.dispose();
    }
  }
}

class MatrixOutboxMessageSender implements OutboxMessageSender {
  MatrixOutboxMessageSender(this._matrixService);

  final MatrixService _matrixService;

  @override
  Future<bool> send(SyncMessage message) {
    return _matrixService.sendMatrixMsg(message);
  }
}
