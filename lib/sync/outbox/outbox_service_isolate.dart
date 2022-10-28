import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/client_runner.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/sync/imap_client.dart';
import 'package:lotti/sync/outbox/messages.dart';
import 'package:lotti/sync/outbox/outbox_imap.dart';

Future<void> entryPoint(SendPort sendPort) async {
  final port = ReceivePort();
  sendPort.send(port.sendPort);
  OutboxServiceIsolate? outbox;

  await for (final msg in port) {
    if (msg is OutboxIsolateMessage) {
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

          getIt
            ..registerSingleton<Directory>(initMsg.docDir)
            ..registerSingleton<ImapClientManager>(ImapClientManager())
            ..registerSingleton<SyncDatabase>(syncDb)
            ..registerSingleton<LoggingDb>(loggingDb);

          outbox = OutboxServiceIsolate(
            syncConfig: initMsg.syncConfig,
            allowInvalidCert: initMsg.allowInvalidCert,
            docDir: initMsg.docDir,
          );

          unawaited(
            getIt<SyncDatabase>().watchOutboxCount().forEach((element) {
              outbox?.enqueueNextSendRequest();
            }),
          );
        },
        restart: (_) => outbox?.restartRunner(),
      );
    }
  }
}

class OutboxServiceIsolate {
  OutboxServiceIsolate({
    required this.syncConfig,
    required this.allowInvalidCert,
    required this.docDir,
  }) {
    _startRunner();
  }

  late ClientRunner<int> _clientRunner;

  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final SyncDatabase _syncDatabase = getIt<SyncDatabase>();
  SyncConfig syncConfig;
  Directory docDir;
  bool allowInvalidCert;

  void dispose() {}

  void _startRunner() {
    _clientRunner = ClientRunner<int>(
      callback: (event) async {
        await sendNext();
      },
    );
  }

  void restartRunner() {
    _loggingDb.captureEvent(
      'restartRunner()',
      domain: 'OUTBOX_ISOLATE',
      subDomain: 'Runner',
    );
    _clientRunner.close();
    _startRunner();
  }

  Future<void> init() async {
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      final unprocessed = await getNextItems();
      if (unprocessed.isNotEmpty) {
        await enqueueNextSendRequest();
      }
    });
  }

  Future<List<OutboxItem>> getNextItems() async {
    return _syncDatabase.oldestOutboxItems(10);
  }

  Future<void> sendNext() async {
    _loggingDb.captureEvent(
      'start',
      domain: 'OUTBOX_ISOLATE',
      subDomain: 'sendNext()',
    );

    final b64Secret = syncConfig.sharedSecret;

    _loggingDb.captureEvent(
      'sendNext() start',
      domain: 'OUTBOX_ISOLATE',
    );

    try {
      _loggingDb.captureEvent('sendNext() start ', domain: 'OUTBOX_ISOLATE');

      final unprocessed = await getNextItems();
      if (unprocessed.isNotEmpty) {
        final nextPending = unprocessed.first;
        try {
          final encryptedMessage = await encryptString(
            b64Secret: b64Secret,
            plainText: nextPending.message,
          );

          final filePath = nextPending.filePath;
          String? encryptedFilePath;

          if (filePath != null) {
            final encryptedFile =
                File('${docDir.path}${nextPending.filePath}.aes');
            final attachment = File('${docDir.path}$filePath');
            await encryptFile(attachment, encryptedFile, b64Secret);
            encryptedFilePath = encryptedFile.path;
          }

          final success = await persistImap(
            encryptedFilePath: encryptedFilePath,
            subject: nextPending.subject,
            encryptedMessage: encryptedMessage,
            syncConfig: syncConfig,
            allowInvalidCert: allowInvalidCert,
          );
          if (success) {
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
          } else {
            await enqueueNextSendRequest(
              delay: const Duration(seconds: 15),
            );
          }

          _loggingDb.captureEvent(
            'sendNext() done',
            domain: 'OUTBOX_ISOLATE',
          );
        } catch (e) {
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
      _loggingDb.captureException(
        exception,
        domain: 'OUTBOX_ISOLATE',
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
        _loggingDb.captureEvent(
          'enqueueRequest() done',
          domain: 'OUTBOX_ISOLATE',
        );
      }),
    );
  }
}
