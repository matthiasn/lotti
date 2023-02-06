import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/isolate.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/client_runner.dart';
import 'package:lotti/sync/imap_client.dart';
import 'package:lotti/sync/inbox/messages.dart';
import 'package:lotti/sync/inbox/process_message.dart';
import 'package:lotti/sync/utils.dart';
import 'package:lotti/utils/consts.dart';

Future<void> entryPoint(SendPort sendPort) async {
  final port = ReceivePort();
  sendPort.send(port.sendPort);
  InboxServiceIsolate? inbox;

  await for (final msg in port) {
    if (msg is InboxIsolateMessage) {
      msg.map(
        init: (initMsg) {
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

          final settingsDb = SettingsDb.connect(
            getDbConnFromIsolate(
              DriftIsolate.fromConnectPort(initMsg.settingsDbConnectPort),
            ),
          );

          getIt
            ..registerSingleton<Directory>(initMsg.docDir)
            ..registerSingleton<SettingsDb>(settingsDb)
            ..registerSingleton<ImapClientManager>(ImapClientManager())
            ..registerSingleton<LoggingDb>(loggingDb)
            ..registerSingleton<JournalDb>(journalDb);

          inbox = InboxServiceIsolate(
            syncConfig: initMsg.syncConfig,
            allowInvalidCert: initMsg.allowInvalidCert,
            hostHash: initMsg.hostHash,
            lastReadUid: initMsg.lastReadUid,
            sendPort: sendPort,
          );
        },
        restart: (_) {},
      );
    }

    if (msg is InboxIsolateRestartMessage) {
      inbox?.restartRunner();
    }
  }
}

class InboxServiceIsolate {
  InboxServiceIsolate({
    required this.syncConfig,
    required this.allowInvalidCert,
    required this.hostHash,
    required this.lastReadUid,
    required this.sendPort,
  }) {
    _startRunner();
    _startTimer();
    enqueueNextFetchRequest();
  }

  void restartRunner() {
    debugPrint('INBOX ISOLATE restart');
    _timer.cancel();
    _clientRunner.close();
    _startRunner();
    _startTimer();
  }

  void _startRunner() {
    _clientRunner = ClientRunner<int>(
      callback: (event) async {
        await _fetchInbox();
      },
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) async {
        enqueueNextFetchRequest();
        await _observeInbox();
      },
    );
  }

  int lastReadUid;
  final SendPort sendPort;

  Future<void> setLastReadUid(int uid) async {
    lastReadUid = uid;
    sendPort.send(IsolateInboxMessage.setLastReadUid(lastReadUid: uid));
  }

  Future<int?> getLastReadUid() async {
    return lastReadUid;
  }

  late ClientRunner<int> _clientRunner;
  late Timer _timer;
  MailClient? _observingClient;
  final String? hostHash;

  final LoggingDb _loggingDb = getIt<LoggingDb>();

  SyncConfig syncConfig;
  bool allowInvalidCert;

  void enqueueNextFetchRequest({
    Duration delay = const Duration(milliseconds: 1),
  }) {
    unawaited(
      Future<void>.delayed(delay).then((_) {
        _clientRunner.enqueueRequest(DateTime.now().millisecondsSinceEpoch);
      }),
    );
  }

  Future<void> _fetchInbox() async {
    final allowInvalidCert =
        await getIt<JournalDb>().getConfigFlag(allowInvalidCertFlag);

    await getIt<ImapClientManager>().imapAction(
      (imapClient) async {
        try {
          if (lastReadUid == -1) {
            enqueueNextFetchRequest(delay: const Duration(seconds: 1));
          }

          final sequence = MessageSequence(isUidSequence: true)
            ..addRangeToLast(lastReadUid + 1);

          if (hostHash != null) {
            final fetchResult = await imapClient.uidFetchMessages(
              sequence,
              'ENVELOPE',
            );

            for (final msg in fetchResult.messages.take(1)) {
              final current = msg.uid!;
              final subject = '${msg.decodeSubject()}';
              if (lastReadUid != current) {
                _loggingDb.captureEvent(
                  'lastReadUid $lastReadUid current $current',
                  domain: 'INBOX_ISOLATE',
                  subDomain: 'fetch',
                );
                if (!validSubject(subject)) {
                  debugPrint('_fetchInbox ignoring invalid email: $current');
                  _loggingDb.captureEvent(
                    '_fetchInbox ignoring invalid email: $current',
                    domain: 'INBOX_ISOLATE',
                  );
                  await setLastReadUid(current);
                } else if (subject.contains('$hostHash')) {
                  debugPrint('_fetchInbox ignoring from same host: $current');
                  _loggingDb.captureEvent(
                    '_fetchInbox ignoring from same host: $current',
                    domain: 'INBOX_ISOLATE',
                  );
                  await setLastReadUid(current);
                } else {
                  await fetchByUid(
                    uid: current,
                    imapClient: imapClient,
                    syncConfig: syncConfig,
                    setLastReadUid: setLastReadUid,
                  );
                }
              }
              if (fetchResult.messages.length > 1) {
                enqueueNextFetchRequest();
              }
            }
          }
          return true;
        } on MailException catch (e, stackTrace) {
          debugPrint('High level API failed with $e');
          _loggingDb.captureException(
            e,
            domain: 'INBOX_ISOLATE',
            subDomain: '_fetchInbox',
            stackTrace: stackTrace,
          );
          return false;
        } catch (e, stackTrace) {
          debugPrint('Exception $e');
          _loggingDb.captureException(
            e,
            domain: 'INBOX_ISOLATE',
            subDomain: '_fetchInbox',
            stackTrace: stackTrace,
          );
          return false;
        }
      },
      syncConfig: syncConfig,
      allowInvalidCert: allowInvalidCert,
    );
  }

  Future<void> _observeInbox() async {
    try {
      final imapConfig = syncConfig.imapConfig;

      final account = MailAccount.fromManualSettings(
        'sync',
        imapConfig.userName,
        imapConfig.host,
        imapConfig.host,
        imapConfig.password,
      );

      await _observingClient?.stopPollingIfNeeded();
      await _observingClient?.disconnect();

      _observingClient = null;
      _observingClient = MailClient(account);

      await _observingClient?.connect();
      await _observingClient?.selectMailboxByPath(imapConfig.folder);

      _observingClient?.eventBus
          .on<MailLoadEvent>()
          .listen((MailLoadEvent event) async {
        enqueueNextFetchRequest();
      });

      _observingClient?.eventBus
          .on<MailConnectionLostEvent>()
          .listen((MailConnectionLostEvent event) async {
        _loggingDb.captureEvent(
          event,
          domain: 'INBOX_ISOLATE',
          subDomain: 'MailConnectionLostEvent',
        );

        try {
          await _observingClient?.disconnect();
          _observingClient = null;
        } catch (e, stackTrace) {
          _loggingDb.captureException(
            e,
            domain: 'INBOX_ISOLATE',
            subDomain: '_observeInbox',
            stackTrace: stackTrace,
          );
        }

        _loggingDb.captureEvent(
          'isConnected: ${_observingClient?.isConnected} '
          'isPolling: ${_observingClient?.isPolling()}',
          domain: 'INBOX_ISOLATE',
        );
      });

      await _observingClient!.startPolling();
    } on MailException catch (e) {
      debugPrint('High level API failed with $e');
      _loggingDb.captureException(
        e,
        domain: 'INBOX_ISOLATE',
        stackTrace: e.stackTrace,
      );
    } catch (e, stackTrace) {
      _loggingDb.captureException(
        e,
        domain: 'INBOX_ISOLATE',
        subDomain: '_observeInbox',
        stackTrace: stackTrace,
      );
    }
  }

  void dispose() {}
}
