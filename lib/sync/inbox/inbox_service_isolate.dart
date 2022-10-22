import 'dart:async';
import 'dart:isolate';

import 'package:drift/isolate.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/client_runner.dart';
import 'package:lotti/sync/imap_client.dart';
import 'package:lotti/sync/inbox/messages.dart';

Future<void> entryPoint(SendPort sendPort) async {
  final port = ReceivePort();
  sendPort.send(port.sendPort);
  InboxServiceIsolate? inbox;

  await for (final msg in port) {
    if (msg is InboxIsolateMessage) {
      msg.map(
        init: (initMsg) {
          final syncDb = SyncDatabase.connect(
            getDbConnFromIsolate(
              DriftIsolate.fromConnectPort(initMsg.syncDbConnectPort),
            ),
          );

          final loggingDb = LoggingDb.connect(
            getDbConnFromIsolate(
              DriftIsolate.fromConnectPort(initMsg.loggingDbConnectPort),
            ),
          );

          final journalDb = JournalDb.connect(
            getDbConnFromIsolate(
              DriftIsolate.fromConnectPort(initMsg.journalDbConnectPort),
            ),
          );

          getIt
            ..registerSingleton<ImapClientManager>(ImapClientManager())
            ..registerSingleton<SyncDatabase>(syncDb)
            ..registerSingleton<LoggingDb>(loggingDb)
            ..registerSingleton<JournalDb>(journalDb);

          inbox = InboxServiceIsolate(
            syncConfig: initMsg.syncConfig,
            networkConnected: initMsg.networkConnected,
            allowInvalidCert: initMsg.allowInvalidCert,
          );
        },
        restart: (_) {},
      );
    }
  }
}

class InboxServiceIsolate {
  InboxServiceIsolate({
    required this.syncConfig,
    required this.networkConnected,
    required this.allowInvalidCert,
  }) {}

  late ClientRunner<int> _clientRunner;

  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final JournalDb _journalDb = getIt<JournalDb>();
  SyncConfig syncConfig;
  bool networkConnected;
  bool allowInvalidCert;

  void dispose() {}
}
