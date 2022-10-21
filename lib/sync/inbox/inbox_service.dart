import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/client_runner.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/imap_client.dart';
import 'package:lotti/sync/inbox/process_message.dart';
import 'package:lotti/sync/utils.dart';
import 'package:lotti/utils/consts.dart';

class InboxService {
  InboxService() {
    _startRunner();
  }

  late ClientRunner<int> _clientRunner;
  final ConnectivityService _connectivityService = getIt<ConnectivityService>();
  final FgBgService _fgBgService = getIt<FgBgService>();
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final VectorClockService _vectorClockService = getIt<VectorClockService>();
  MailClient? _observingClient;
  late final StreamSubscription<FGBGType> fgBgSubscription;
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  late Timer _timer;

  void _startRunner() {
    _clientRunner = ClientRunner<int>(
      callback: (event) async {
        await _fetchInbox();
      },
    );
  }

  void restartRunner() {
    _timer.cancel();
    _clientRunner.close();
    _startRunner();
    _startTimer();
  }

  void dispose() {
    fgBgSubscription.cancel();
    _clientRunner.close();
  }

  void _startTimer() {
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) async {
        enqueueNextFetchRequest();
        await _observeInbox();
      },
    );
  }

  Future<void> init() async {
    debugPrint('SyncInboxService init');
    final syncConfig = await _syncConfigService.getSyncConfig();

    final enableSyncInbox =
        await getIt<JournalDb>().getConfigFlag(enableSyncInboxFlag);

    if (!enableSyncInbox || syncConfig == null) {
      return;
    }

    _fgBgService.fgBgStream.listen((foreground) {
      if (foreground) {
        restartRunner();
        enqueueNextFetchRequest();
        _observeInbox();
      }
    });

    _connectivityService.connectedStream.listen((connected) {
      if (connected) {
        restartRunner();
        enqueueNextFetchRequest();
        _observeInbox();
      }
    });

    _startTimer();
    enqueueNextFetchRequest();
    await _observeInbox();
  }

  void enqueueNextFetchRequest({
    Duration delay = const Duration(milliseconds: 1),
  }) {
    unawaited(
      Future<void>.delayed(delay).then(
        (_) =>
            _clientRunner.enqueueRequest(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> _fetchInbox() async {
    final allowInvalidCert =
        await getIt<JournalDb>().getConfigFlag(allowInvalidCertFlag);
    final syncConfig = await _syncConfigService.getSyncConfig();

    await getIt<ImapClientManager>().imapAction(
      (imapClient) async {
        try {
          final lastReadUid = await getLastReadUid() ?? -1;

          if (lastReadUid == -1) {
            enqueueNextFetchRequest(delay: const Duration(seconds: 1));
          }

          final sequence = MessageSequence(isUidSequence: true)
            ..addRangeToLast(lastReadUid + 1);

          final hostHash = await _vectorClockService.getHostHash();

          if (hostHash != null) {
            final fetchResult = await imapClient.uidFetchMessages(
              sequence,
              'ENVELOPE',
            );

            for (final msg in fetchResult.messages.take(1)) {
              final lastReadUid = await getLastReadUid();
              final current = msg.uid;
              final subject = '${msg.decodeSubject()}';
              if (lastReadUid != current) {
                _loggingDb.captureEvent(
                  'lastReadUid $lastReadUid current $current',
                  domain: 'INBOX',
                  subDomain: 'fetch',
                );
                if (!validSubject(subject)) {
                  debugPrint('_fetchInbox ignoring invalid email: $current');
                  _loggingDb.captureEvent(
                    '_fetchInbox ignoring invalid email: $current',
                    domain: 'INBOX',
                  );
                  await setLastReadUid(current);
                } else if (subject.contains(hostHash)) {
                  debugPrint('_fetchInbox ignoring from same host: $current');
                  _loggingDb.captureEvent(
                    '_fetchInbox ignoring from same host: $current',
                    domain: 'INBOX',
                  );
                  await setLastReadUid(current);
                } else {
                  await fetchByUid(uid: current, imapClient: imapClient);
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
            domain: 'INBOX',
            subDomain: '_fetchInbox',
            stackTrace: stackTrace,
          );
          return false;
        } catch (e, stackTrace) {
          debugPrint('Exception $e');
          _loggingDb.captureException(
            e,
            domain: 'INBOX',
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
      final syncConfig = await _syncConfigService.getSyncConfig();

      if (syncConfig != null) {
        final imapConfig = syncConfig.imapConfig;

        final account = MailAccount.fromManualSettings(
          'sync',
          imapConfig.userName,
          imapConfig.host,
          imapConfig.host,
          imapConfig.password,
        );

        await _observingClient?.stopPolling();
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
            domain: 'INBOX',
          );

          try {
            await _observingClient?.disconnect();
            _observingClient = null;
          } catch (e, stackTrace) {
            _loggingDb.captureException(
              e,
              domain: 'INBOX',
              subDomain: '_observeInbox',
              stackTrace: stackTrace,
            );
          }

          _loggingDb.captureEvent(
            'isConnected: ${_observingClient?.isConnected} '
            'isPolling: ${_observingClient?.isPolling()}',
            domain: 'INBOX',
          );
        });

        await _observingClient!.startPolling();
      }
    } on MailException catch (e) {
      debugPrint('High level API failed with $e');
      _loggingDb.captureException(
        e,
        domain: 'INBOX',
        stackTrace: e.stackTrace,
      );
    } catch (e, stackTrace) {
      _loggingDb.captureException(
        e,
        domain: 'INBOX',
        subDomain: '_observeInbox',
        stackTrace: stackTrace,
      );
    }
  }
}
