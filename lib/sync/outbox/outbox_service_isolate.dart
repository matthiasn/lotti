import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/client_runner.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/sync/outbox/messages.dart';
import 'package:lotti/sync/outbox_imap.dart';
import 'package:lotti/utils/consts.dart';
import 'package:path_provider/path_provider.dart';

Future<void> entryPoint(SendPort sendPort) async {
  final port = ReceivePort();
  sendPort.send(port.sendPort);

  await for (final msg in port) {
    if (msg is OutboxIsolateInitMessage) {
      final syncDb = SyncDatabase.connect(
        getDbConnFromIsolate(
          DriftIsolate.fromConnectPort(msg.syncDbConnectPort),
        ),
      );

      final loggingDb = LoggingDb.connect(
        getDbConnFromIsolate(
          DriftIsolate.fromConnectPort(msg.loggingDbConnectPort),
        ),
      );

      getIt
        ..registerSingleton<SyncDatabase>(syncDb)
        ..registerSingleton<LoggingDb>(loggingDb);

      final outbox = OutboxServiceIsolatePart(
        syncConfig: msg.syncConfig,
        networkConnected: msg.networkConnected,
      );

      unawaited(
        getIt<SyncDatabase>().watchOutboxCount().forEach((element) {
          debugPrint('db.watchOutboxCount $element');
          outbox.restartRunner();
        }),
      );
    }
  }
}

class OutboxServiceIsolatePart {
  OutboxServiceIsolatePart({
    required this.syncConfig,
    required this.networkConnected,
  }) {
    _startRunner();
  }

  late ClientRunner<int> _clientRunner;

  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final SyncDatabase _syncDatabase = getIt<SyncDatabase>();
  ImapClient? prevImapClient;
  SyncConfig syncConfig;
  bool networkConnected;

  void dispose() {}

  void _startRunner() {
    _clientRunner = ClientRunner<int>(
      callback: (event) async {
        await sendNext();
      },
    );
  }

  void restartRunner() {
    _clientRunner.close();
    _startRunner();
  }

  Future<void> init() async {
    debugPrint('OutboxServiceIsolatePart init');

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      final unprocessed = await getNextItems();
      if (unprocessed.isNotEmpty) {
        await enqueueNextSendRequest();
      }
    });
  }

  // Inserts a fault 25% of the time, where an exception would
  // have to be handled, a retry intent recorded, and a retry
  // scheduled. Improper handling of the retry would become
  // very obvious and painful very soon.
  String insertFault(String path) {
    final random = Random();
    final randomNumber = random.nextDouble();
    return (randomNumber < 0.25) ? '${path}Nope' : path;
  }

  Future<List<OutboxItem>> getNextItems() async {
    return _syncDatabase.oldestOutboxItems(10);
  }

  Future<void> sendNext() async {
    _loggingDb.captureEvent(
      'start',
      domain: 'OUTBOX',
      subDomain: 'sendNext()',
    );

    final b64Secret = syncConfig.sharedSecret;

    final enableSyncOutbox =
        await getIt<JournalDb>().getConfigFlag(enableSyncOutboxFlag);

    if (!enableSyncOutbox) {
      _loggingDb.captureEvent(
        'sync not enabled',
        domain: 'OUTBOX',
        subDomain: 'sendNext()',
      );
      return;
    }

    _loggingDb.captureEvent('sendNext() start', domain: 'OUTBOX');

    try {
      final clientConnected = prevImapClient?.isConnected ?? false;

      _loggingDb
        ..captureEvent(
          'sendNext() networkConnected: $networkConnected ',
          domain: 'OUTBOX',
        )
        ..captureEvent(
          'sendNext() clientConnected: $clientConnected ',
          domain: 'OUTBOX',
        );

      if (!clientConnected) {
        prevImapClient = null;
      }

      if (networkConnected) {
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
              final docDir = await getApplicationDocumentsDirectory();
              final encryptedFile =
                  File('${docDir.path}${nextPending.filePath}.aes');
              final attachment = File(insertFault('${docDir.path}$filePath'));
              await encryptFile(attachment, encryptedFile, b64Secret);
              encryptedFilePath = encryptedFile.path;
            }

            final successfulClient = await persistImap(
              encryptedFilePath: encryptedFilePath,
              subject: nextPending.subject,
              encryptedMessage: encryptedMessage,
              prevImapClient: prevImapClient,
            );
            if (successfulClient != null) {
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
            prevImapClient = successfulClient;
            _loggingDb.captureEvent('sendNext() done', domain: 'OUTBOX');
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
            await prevImapClient?.disconnect();
            // ignore: unnecessary_statements
            prevImapClient == null;
            await enqueueNextSendRequest(delay: const Duration(seconds: 15));
          }
        }
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'OUTBOX',
        subDomain: 'sendNext',
        stackTrace: stackTrace,
      );
      await prevImapClient?.disconnect();
      // ignore: unnecessary_statements
      prevImapClient == null;
      await enqueueNextSendRequest(delay: const Duration(seconds: 15));
    }
  }

  Future<void> enqueueNextSendRequest({
    Duration delay = const Duration(milliseconds: 1),
  }) async {
    final enableSyncOutbox =
        await getIt<JournalDb>().getConfigFlag(enableSyncOutboxFlag);

    if (!enableSyncOutbox) {
      _loggingDb.captureEvent(
        'Sync not enabled -> not enqueued',
        domain: 'OUTBOX',
      );
      return;
    }

    unawaited(
      Future<void>.delayed(delay).then((_) {
        _clientRunner.enqueueRequest(DateTime.now().millisecondsSinceEpoch);
        _loggingDb.captureEvent('enqueueRequest() done', domain: 'OUTBOX');
      }),
    );
  }
}
