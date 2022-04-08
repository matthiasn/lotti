import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lotti/classes/config.dart';
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

  SyncInboxService() {
    _vectorClockService = getIt<VectorClockService>();

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

    _startPeriodicFetching();
    _observeInbox();
  }

  Future<void> processMessage(MimeMessage message) async {
    final transaction = _loggingDb.startTransaction('processMessage()', 'task');
    try {
      String? encryptedMessage = readMessage(message);
      SyncConfig? syncConfig = await _syncConfigService.getSyncConfig();

      if (syncConfig != null) {
        String b64Secret = syncConfig.sharedSecret;

        SyncMessage? syncMessage =
            await decryptMessage(encryptedMessage, message, b64Secret);

        syncMessage?.when(
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
              await persistenceLogic.updateDbEntity(journalEntity,
                  enqueueSync: false);
            } else {
              await persistenceLogic.createDbEntity(journalEntity,
                  enqueueSync: false);
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
      await _loggingDb.captureException(
        e,
        domain: 'INBOX_SERVICE',
        subDomain: 'processMessage',
        stackTrace: stackTrace,
      );
    }

    await transaction.finish();
  }

  void _startPeriodicFetching() async {
    timer?.cancel();
    _fetchInbox();
    timer = Timer.periodic(
      const Duration(seconds: 15),
      (timer) async {
        _fetchInbox();
      },
    );
  }

  void _stopPeriodicFetching() async {
    if (timer != null) {
      timer!.cancel();
      timer = null;
    }
  }

  Future<void> _fetchInbox() async {
    final transaction = _loggingDb.startTransaction('_fetchInbox()', 'task');
    ImapClient? imapClient;

    _loggingDb.captureEvent('_fetchInbox()', domain: 'INBOX_CUBIT');

    if (!fetchMutex.isLocked) {
      await fetchMutex.acquire();

      try {
        imapClient = await createImapClient();

        String? lastReadUidValue = await _storage.read(key: lastReadUidKey);
        int lastReadUid =
            lastReadUidValue != null ? int.parse(lastReadUidValue) : 0;

        var sequence = MessageSequence(isUidSequence: true);
        sequence.addRangeToLast(lastReadUid + 1);
        debugPrint('_fetchInbox sequence: $sequence');

        if (imapClient != null) {
          final fetchResult =
              await imapClient.uidFetchMessages(sequence, 'ENVELOPE');

          for (MimeMessage msg in fetchResult.messages) {
            String? lastReadUidValue = await _storage.read(key: lastReadUidKey);
            int lastReadUid =
                lastReadUidValue != null ? int.parse(lastReadUidValue) : 0;
            int? current = msg.uid;
            String subject = '${msg.decodeSubject()}';
            if (lastReadUid != current) {
              _loggingDb.captureEvent(
                '_fetchInbox lastReadUid $lastReadUid current $current',
                domain: 'INBOX_CUBIT',
                subDomain: '_fetchInbox',
              );
              if (subject.contains(await _vectorClockService.getHostHash())) {
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
        await _loggingDb.captureException(
          e,
          domain: 'INBOX_SERVICE',
          subDomain: '_fetchInbox',
          stackTrace: stackTrace,
        );
      } catch (e, stackTrace) {
        debugPrint('Exception $e');
        await _loggingDb.captureException(
          e,
          domain: 'INBOX_SERVICE',
          subDomain: '_fetchInbox',
          stackTrace: stackTrace,
        );
      } finally {
        imapClient?.disconnect();
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
          FetchImapResult res =
              await imapClient.uidFetchMessage(uid, 'BODY.PEEK[]');

          for (final message in res.messages) {
            await processMessage(message);
          }
          await _setLastReadUid(uid);
        }
      } on MailException catch (e) {
        debugPrint('High level API failed with $e');
        await _loggingDb.captureException(
          e,
          domain: 'INBOX_SERVICE',
          subDomain: '_fetchByUid',
        );
      } catch (e, stackTrace) {
        await _loggingDb.captureException(
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
      SyncConfig? syncConfig = await _syncConfigService.getSyncConfig();

      if (syncConfig != null) {
        _observingClient?.disconnect();
        _observingClient = null;

        ImapConfig imapConfig = syncConfig.imapConfig;
        final account = MailAccount.fromManualSettings(
          'sync',
          imapConfig.userName,
          imapConfig.host,
          imapConfig.host,
          imapConfig.password,
        );

        _observingClient = MailClient(account, isLogEnabled: false);

        await _observingClient!.connect();
        await _observingClient!.selectInbox();

        _observingClient!.eventBus
            .on<MailLoadEvent>()
            .listen((MailLoadEvent event) async {
          if (!fetchMutex.isLocked) {
            _fetchInbox();
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
            _observingClient?.disconnect();
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

        _observingClient!.startPolling();
      }
    } on MailException catch (e) {
      debugPrint('High level API failed with $e');
      await _loggingDb.captureException(
        e,
        domain: 'INBOX_SERVICE',
      );
    } catch (e, stackTrace) {
      await _loggingDb.captureException(
        e,
        domain: 'INBOX_SERVICE',
        subDomain: '_observeInbox',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> resetOffset() async {
    await _storage.delete(key: lastReadUidKey);
    await _vectorClockService.setNewHost();
  }
}
