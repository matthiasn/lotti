import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/outbox/messages.dart';
import 'package:lotti/sync/outbox/outbox_service_isolate.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';

class OutboxService {
  final ConnectivityService _connectivityService = getIt<ConnectivityService>();
  final FgBgService _fgBgService = getIt<FgBgService>();
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final SyncDatabase _syncDatabase = getIt<SyncDatabase>();
  late final StreamSubscription<FGBGType> fgBgSubscription;

  late SendPort _sendPort;

  void dispose() {
    fgBgSubscription.cancel();
  }

  Future<void> restartRunner() async {
    final syncConfig = await _syncConfigService.getSyncConfig();
    final networkConnected = await _connectivityService.isConnected();

    if (syncConfig != null) {
      _sendPort.send(
        OutboxIsolateMessage.restart(
          syncConfig: syncConfig,
          networkConnected: networkConnected,
        ),
      );
    }
  }

  Future<void> startIsolate() async {
    final syncConfig = await _syncConfigService.getSyncConfig();
    final networkConnected = await _connectivityService.isConnected();

    final receivePort = ReceivePort();
    await Isolate.spawn(entryPoint, receivePort.sendPort);
    _sendPort = await receivePort.first as SendPort;

    final syncDbIsolate = await getIt<Future<DriftIsolate>>(
      instanceName: syncDbFileName,
    );
    final loggingDbIsolate = await getIt<Future<DriftIsolate>>(
      instanceName: loggingDbFileName,
    );
    final allowInvalidCert =
        await getIt<JournalDb>().getConfigFlag(allowInvalidCertFlag);

    if (syncConfig != null) {
      _sendPort.send(
        OutboxIsolateMessage.init(
          syncConfig: syncConfig,
          networkConnected: networkConnected,
          syncDbConnectPort: syncDbIsolate.connectPort,
          loggingDbConnectPort: loggingDbIsolate.connectPort,
          allowInvalidCert: allowInvalidCert,
          docDir: getDocumentsDirectory(),
        ),
      );
    }
  }

  Future<void> init() async {
    final syncConfig = await _syncConfigService.getSyncConfig();

    final enableSyncOutbox =
        await getIt<JournalDb>().getConfigFlag(enableSyncOutboxFlag);

    if (syncConfig != null && enableSyncOutbox) {
      debugPrint('OutboxService init $enableSyncOutbox');
      await startIsolate();
    }

    _connectivityService.connectedStream.listen((connected) {
      if (connected) {
        restartRunner();
      }
    });

    _fgBgService.fgBgStream.listen((foreground) {
      if (foreground) {
        restartRunner();
      }
    });
  }

  Future<List<OutboxItem>> getNextItems() async {
    return _syncDatabase.oldestOutboxItems(10);
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    try {
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
        final journalEntity = syncMessage.journalEntity;
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

      if (syncMessage is SyncTagEntity) {
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            subject: Value('$hostHash:tag'),
          ),
        );
      }
    } catch (exception, stackTrace) {
      debugPrint('enqueueMessage $exception \n$stackTrace');
      _loggingDb.captureException(
        exception,
        domain: 'OUTBOX',
        subDomain: 'enqueueMessage',
        stackTrace: stackTrace,
      );
    }
  }
}
