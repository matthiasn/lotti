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
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';

class OutboxService {
  OutboxService() {
    _startRunner();

    Connectivity()
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
  final LoggingService _loggingService = getIt<LoggingService>();
  final SyncDatabase _syncDatabase = getIt<SyncDatabase>();

  late ClientRunner<int> _clientRunner;

  void _startRunner() {
    _clientRunner = ClientRunner<int>(
      callback: (event) async {
        while (getIt<UserActivityService>().msSinceLastActivity < 1000) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
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
      final vectorClockService = getIt<VectorClockService>();
      final hostHash = await vectorClockService.getHostHash();
      final host = await vectorClockService.getHost();
      final jsonString = json.encode(syncMessage);
      final docDir = getDocumentsDirectory();

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
              attachment = File(getFullImagePath(journalImage));
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

  Future<void> sendNext() async {
    try {
      final enableMatrix = await getIt<JournalDb>().getConfigFlag(
        enableMatrixFlag,
      );

      if (!enableMatrix) {
        return;
      }

      final unprocessed = await getNextItems();
      if (unprocessed.isNotEmpty) {
        final nextPending = unprocessed.first;

        _loggingService.captureEvent(
          'trying ${nextPending.subject} ',
          domain: 'OUTBOX',
          subDomain: 'sendNext()',
        );

        try {
          final success = await getIt<MatrixService>().sendMatrixMsg(
            SyncMessage.fromJson(
              json.decode(nextPending.message) as Map<String, dynamic>,
            ),
          );

          if (!success) {
            await enqueueNextSendRequest(delay: const Duration(seconds: 5));
            return;
          }

          await _syncDatabase.updateOutboxItem(
            OutboxCompanion(
              id: Value(nextPending.id),
              status: Value(OutboxStatus.sent.index),
              updatedAt: Value(DateTime.now()),
            ),
          );
          if (unprocessed.length > 1) {
            await enqueueNextSendRequest();
          }

          _loggingService.captureEvent(
            '${nextPending.subject} done',
            domain: 'OUTBOX',
            subDomain: 'sendNext()',
          );
        } catch (e, stackTrace) {
          getIt<LoggingService>().captureException(
            e,
            domain: 'MATRIX_SERVICE',
            subDomain: 'sendMatrixMsg',
            stackTrace: stackTrace,
          );

          await _syncDatabase.updateOutboxItem(
            OutboxCompanion(
              id: Value(nextPending.id),
              status: Value(
                nextPending.retries < 10
                    ? OutboxStatus.pending.index
                    : OutboxStatus.error.index,
              ),
              retries: Value(nextPending.retries + 1),
              updatedAt: Value(DateTime.now()),
            ),
          );
          await enqueueNextSendRequest(delay: const Duration(seconds: 15));
        }
      }
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
}
