import 'dart:async';
import 'dart:isolate';

import 'package:drift/isolate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/inbox/inbox_service_isolate.dart';
import 'package:lotti/sync/inbox/messages.dart';
import 'package:lotti/sync/utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';

class InboxService {
  InboxService();

  final ConnectivityService _connectivityService = getIt<ConnectivityService>();
  final FgBgService _fgBgService = getIt<FgBgService>();
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final VectorClockService _vectorClockService = getIt<VectorClockService>();
  late final StreamSubscription<FGBGType> fgBgSubscription;
  SendPort? _sendPort;

  Future<void> restartRunner() async {
    final syncConfig = await _syncConfigService.getSyncConfig();

    if (syncConfig != null) {
      _sendPort?.send(
        InboxIsolateMessage.restart(syncConfig: syncConfig),
      );
    }
  }

  void dispose() {
    fgBgSubscription.cancel();
  }

  Future<void> init() async {
    debugPrint('SyncInboxService init');
    final syncConfig = await _syncConfigService.getSyncConfig();

    final enableSyncInbox =
        await getIt<JournalDb>().getConfigFlag(enableSyncInboxFlag);

    if (!enableSyncInbox || syncConfig == null) {
      return;
    }

    await startInboxIsolate();

    _fgBgService.fgBgStream.listen((foreground) {
      if (foreground) {
        restartRunner();
      }
    });

    _connectivityService.connectedStream.listen((connected) {
      if (connected) {
        restartRunner();
      }
    });
  }

  Future<void> startInboxIsolate() async {
    final syncConfig = await _syncConfigService.getSyncConfig();

    final receivePort = ReceivePort();
    await Isolate.spawn(entryPoint, receivePort.sendPort);
    final receiveBroadcast = receivePort.asBroadcastStream();

    unawaited(
      receiveBroadcast.forEach((msg) {
        if (msg is IsolateInboxLastReadMessage) {
          setLastReadUid(msg.lastReadUid);
        }
      }),
    );

    _sendPort = await receiveBroadcast.first as SendPort;

    final loggingDbIsolate = await getIt<Future<DriftIsolate>>(
      instanceName: loggingDbFileName,
    );

    final journalDbIsolate = await getIt<Future<DriftIsolate>>(
      instanceName: journalDbFileName,
    );

    final allowInvalidCert =
        await getIt<JournalDb>().getConfigFlag(allowInvalidCertFlag);

    final hostHash = await _vectorClockService.getHostHash();
    final lastReadUid = await getLastReadUid() ?? 0;

    if (syncConfig != null) {
      _sendPort?.send(
        InboxIsolateMessage.init(
          syncConfig: syncConfig,
          loggingDbConnectPort: loggingDbIsolate.connectPort,
          allowInvalidCert: allowInvalidCert,
          journalDbConnectPort: journalDbIsolate.connectPort,
          hostHash: hostHash,
          docDir: getDocumentsDirectory(),
          lastReadUid: lastReadUid,
        ),
      );
    }
  }
}
