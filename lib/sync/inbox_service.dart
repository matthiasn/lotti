import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_links.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/imap_client.dart';
import 'package:lotti/sync/inbox_read.dart';
import 'package:lotti/sync/inbox_save_attachments.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mutex/mutex.dart';

const String sharedSecretKey = 'sharedSecret';
const String imapConfigKey = 'imapConfig';
const String lastReadUidKey = 'lastReadUid';

class SyncInboxService {
  SyncInboxService() {
    _vectorClockService = getIt<VectorClockService>();
    init();
  }

  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  late final VectorClockService _vectorClockService;
  MailClient? _observingClient;
  late final StreamSubscription<FGBGType> fgBgSubscription;
  Timer? timer;
  final fetchMutex = Mutex();
  final _storage = const FlutterSecureStorage();
  final JournalDb _journalDb = getIt<JournalDb>();
  final LoggingDb _loggingDb = getIt<LoggingDb>();

  void dispose() {
    fgBgSubscription.cancel();
  }

  Future<void> init() async {
    if (!Platform.isMacOS && !Platform.isLinux && !Platform.isWindows) {
      fgBgSubscription = FGBGEvents.stream.listen((event) {
        _loggingDb.captureEvent(event, domain: 'INBOX_CUBIT');

        if (event == FGBGType.foreground) {
          _startPeriodicFetching();
          _observeInbox();
        }
        if (event == FGBGType.background) {
          _stopPeriodicFetching();
        }
      });
    }

    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _loggingDb.captureEvent(
        'INBOX: Connectivity onConnectivityChanged $result',
        domain: 'INBOX_SERVICE',
      );

      if (result == ConnectivityResult.none) {
        _stopPeriodicFetching();
      } else {
        _startPeriodicFetching();
        _observeInbox();
      }
    });

    await _startPeriodicFetching();
    await _observeInbox();
  }

  Future<void> processMessage(MimeMessage message) async {
    final transaction = _loggingDb.startTransaction('processMessage()', 'task');
    try {
      final encryptedMessage = readMessage(message);
      final syncConfig = await _syncConfigService.getSyncConfig();

      if (syncConfig != null) {
        final b64Secret = syncConfig.sharedSecret;

        final syncMessage =
            await decryptMessage(encryptedMessage, message, b64Secret);

        await syncMessage?.when(
          journalEntity:
              (JournalEntity journalEntity, SyncEntryStatus status) async {
            await saveJournalEntityJson(journalEntity);

            await journalEntity.maybeMap(
              journalAudio: (JournalAudio journalAudio) async {
                if (syncMessage.status == SyncEntryStatus.initial) {
                  await saveAudioAttachment(message, journalAudio, b64Secret);
                }
              },
              journalImage: (JournalImage journalImage) async {
                if (syncMessage.status == SyncEntryStatus.initial) {
                  await saveImageAttachment(message, journalImage, b64Secret);
                }
              },
              orElse: () {},
            );

            if (status == SyncEntryStatus.update) {
              await persistenceLogic.updateDbEntity(journalEntity);
            } else {
              await persistenceLogic.createDbEntity(journalEntity);
            }
          },
          entryLink: (EntryLink entryLink, SyncEntryStatus _) {
            _journalDb.upsertEntryLink(entryLink);
          },
          entityDefinition: (
            EntityDefinition entityDefinition,
            SyncEntryStatus status,
          ) {
            _journalDb.upsertEntityDefinition(entityDefinition);
          },
          tagEntity: (
            TagEntity tagEntity,
            SyncEntryStatus status,
          ) {
            _journalDb.upsertTagEntity(tagEntity);
          },
        );
      } else {
        throw Exception('missing IMAP config');
      }
    } catch (e, stackTrace) {
      _loggingDb.captureException(
        e,
        domain: 'INBOX_SERVICE',
        subDomain: 'processMessage',
        stackTrace: stackTrace,
      );
    }

    await transaction.finish();
  }

  Future<void> _startPeriodicFetching() async {
    final syncConfig = await _syncConfigService.getSyncConfig();

    if (syncConfig == null) {
      _loggingDb.captureEvent(
        'Sync config missing -> periodic fetching not started',
        domain: 'OUTBOX_CUBIT',
      );
      return;
    } else {
      timer?.cancel();
      await _fetchInbox();
      timer = Timer.periodic(
        const Duration(seconds: 15),
        (timer) async {
          await _fetchInbox();
        },
      );
    }
  }

  Future<void> _stopPeriodicFetching() async {
    if (timer != null) {
      timer!.cancel();
      timer = null;
    }
  }

  bool validSubject(String subject) {
    final validSubject = RegExp('[a-z0-9]{40}:[a-z0-9]+');
    return validSubject.hasMatch(subject);
  }

  Future<void> _fetchInbox() async {
    final transaction = _loggingDb.startTransaction('_fetchInbox()', 'task');
    ImapClient? imapClient;

    _loggingDb.captureEvent('_fetchInbox()', domain: 'INBOX_CUBIT');

    if (!fetchMutex.isLocked) {
      await fetchMutex.acquire();

      try {
        final syncConfig = await _syncConfigService.getSyncConfig();
        imapClient = await createImapClient(syncConfig);

        final lastReadUidValue = await _storage.read(key: lastReadUidKey);
        final lastReadUid =
            lastReadUidValue != null ? int.parse(lastReadUidValue) : 0;

        final sequence = MessageSequence(isUidSequence: true)
          ..addRangeToLast(lastReadUid + 1);
        debugPrint('_fetchInbox sequence: $sequence');

        if (imapClient != null) {
          final fetchResult =
              await imapClient.uidFetchMessages(sequence, 'ENVELOPE');

          for (final msg in fetchResult.messages) {
            final lastReadUidValue = await _storage.read(key: lastReadUidKey);
            final lastReadUid =
                lastReadUidValue != null ? int.parse(lastReadUidValue) : 0;
            final current = msg.uid;
            final subject = '${msg.decodeSubject()}';
            if (lastReadUid != current) {
              _loggingDb.captureEvent(
                '_fetchInbox lastReadUid $lastReadUid current $current',
                domain: 'INBOX_CUBIT',
                subDomain: '_fetchInbox',
              );
              if (!validSubject(subject)) {
                debugPrint('_fetchInbox ignoring invalid email: $current');
                _loggingDb.captureEvent(
                  '_fetchInbox ignoring invalid email: $current',
                  domain: 'INBOX_CUBIT',
                );
                await _setLastReadUid(current);
              } else if (subject
                  .contains(await _vectorClockService.getHostHash())) {
                debugPrint('_fetchInbox ignoring from same host: $current');
                _loggingDb.captureEvent(
                  '_fetchInbox ignoring from same host: $current',
                  domain: 'INBOX_CUBIT',
                );
                await _setLastReadUid(current);
              } else {
                await _fetchByUid(uid: current, imapClient: imapClient);
              }
            }
          }
          fetchMutex.release();
        }
      } on MailException catch (e, stackTrace) {
        debugPrint('High level API failed with $e');
        _loggingDb.captureException(
          e,
          domain: 'INBOX_SERVICE',
          subDomain: '_fetchInbox',
          stackTrace: stackTrace,
        );
      } catch (e, stackTrace) {
        debugPrint('Exception $e');
        _loggingDb.captureException(
          e,
          domain: 'INBOX_SERVICE',
          subDomain: '_fetchInbox',
          stackTrace: stackTrace,
        );
      } finally {
        await imapClient?.disconnect();
        if (fetchMutex.isLocked) {
          fetchMutex.release();
        }
      }
    }
    await transaction.finish();
  }

  Future<void> _setLastReadUid(int? uid) async {
    await _storage.write(key: lastReadUidKey, value: '$uid');
  }

  Future<void> _fetchByUid({
    int? uid,
    ImapClient? imapClient,
  }) async {
    final transaction = _loggingDb.startTransaction('_fetchByUid()', 'task');
    if (uid != null) {
      try {
        if (imapClient != null) {
          // odd workaround, prevents intermittent failures on macOS
          await imapClient.uidFetchMessage(uid, 'BODY.PEEK[]');
          final res = await imapClient.uidFetchMessage(uid, 'BODY.PEEK[]');

          for (final message in res.messages) {
            await processMessage(message);
          }
          await _setLastReadUid(uid);
        }
      } on MailException catch (e) {
        debugPrint('High level API failed with $e');
        _loggingDb.captureException(
          e,
          domain: 'INBOX_SERVICE',
          subDomain: '_fetchByUid',
        );
      } catch (e, stackTrace) {
        _loggingDb.captureException(
          e,
          domain: 'INBOX_SERVICE',
          subDomain: '_fetchByUid',
          stackTrace: stackTrace,
        );
      } finally {}
    }
    await transaction.finish();
  }

  Future<void> _observeInbox() async {
    try {
      final syncConfig = await _syncConfigService.getSyncConfig();

      if (syncConfig != null) {
        await _observingClient?.disconnect();
        _observingClient = null;

        final imapConfig = syncConfig.imapConfig;
        final account = MailAccount.fromManualSettings(
          'sync',
          imapConfig.userName,
          imapConfig.host,
          imapConfig.host,
          imapConfig.password,
        );

        _observingClient = MailClient(account);

        await _observingClient!.connect();
        await _observingClient!.selectMailboxByPath(imapConfig.folder);

        _observingClient!.eventBus
            .on<MailLoadEvent>()
            .listen((MailLoadEvent event) async {
          if (!fetchMutex.isLocked) {
            await _fetchInbox();
          }
        });

        _observingClient?.eventBus
            .on<MailConnectionLostEvent>()
            .listen((MailConnectionLostEvent event) async {
          _loggingDb.captureEvent(
            event,
            domain: 'INBOX_SERVICE',
          );

          try {
            await _observingClient?.disconnect();
            _observingClient = null;
          } catch (e, stackTrace) {
            _loggingDb.captureException(
              e,
              domain: 'INBOX_SERVICE',
              subDomain: '_observeInbox',
              stackTrace: stackTrace,
            );
          }

          _loggingDb.captureEvent(
            'isConnected: ${_observingClient?.isConnected} '
            'isPolling: ${_observingClient?.isPolling()}',
            domain: 'INBOX_SERVICE',
          );
        });

        await _observingClient!.startPolling();
      }
    } on MailException catch (e) {
      debugPrint('High level API failed with $e');
      _loggingDb.captureException(
        e,
        domain: 'INBOX_SERVICE',
      );
    } catch (e, stackTrace) {
      _loggingDb.captureException(
        e,
        domain: 'INBOX_SERVICE',
        subDomain: '_observeInbox',
        stackTrace: stackTrace,
      );
    }
  }
}
