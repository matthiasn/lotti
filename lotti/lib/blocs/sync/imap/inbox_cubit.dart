import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/sync/imap/imap_client.dart';
import 'package:lotti/blocs/sync/imap/imap_state.dart';
import 'package:lotti/blocs/sync/imap/inbox_read.dart';
import 'package:lotti/blocs/sync/imap/inbox_save_attachments.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/insights_db.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mutex/mutex.dart';

class InboxImapCubit extends Cubit<ImapState> {
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  late final PersistenceCubit _persistenceCubit;
  late final VectorClockService _vectorClockService;
  MailClient? _observingClient;
  late final StreamSubscription<FGBGType> fgBgSubscription;
  Timer? timer;
  final fetchMutex = Mutex();
  final _storage = const FlutterSecureStorage();
  final JournalDb _journalDb = getIt<JournalDb>();
  final InsightsDb _insightsDb = getIt<InsightsDb>();

  final String sharedSecretKey = 'sharedSecret';
  final String imapConfigKey = 'imapConfig';
  final String lastReadUidKey = 'lastReadUid';

  InboxImapCubit({
    required PersistenceCubit persistenceCubit,
  }) : super(ImapState.initial()) {
    _persistenceCubit = persistenceCubit;
    _vectorClockService = getIt<VectorClockService>();

    if (!Platform.isMacOS && !Platform.isLinux && !Platform.isWindows) {
      fgBgSubscription = FGBGEvents.stream.listen((event) {
        _insightsDb.captureEvent(event, domain: 'INBOX_CUBIT');

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
      _insightsDb
          .captureEvent('INBOX: Connectivity onConnectivityChanged $result');

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
    final transaction =
        _insightsDb.startTransaction('processMessage()', 'task');
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
              await _persistenceCubit.updateDbEntity(journalEntity,
                  enqueueSync: false);
            } else {
              await _persistenceCubit.createDbEntity(journalEntity,
                  enqueueSync: false);
            }
          },
          entityDefinition: (
            EntityDefinition entityDefinition,
            SyncEntryStatus status,
          ) {
            _journalDb.upsertEntityDefinition(entityDefinition);
          },
        );
      } else {
        throw Exception('missing IMAP config');
      }
    } catch (e, stackTrace) {
      await _insightsDb.captureException(e, stackTrace: stackTrace);
      emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
    }

    await transaction.finish();
  }

  void _startPeriodicFetching() async {
    timer?.cancel();
    _fetchInbox();
    timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      _fetchInbox();
      emit(ImapState.online(lastUpdate: DateTime.now()));
    });
  }

  void _stopPeriodicFetching() async {
    if (timer != null) {
      timer!.cancel();
      timer = null;
    }
  }

  Future<void> _fetchInbox() async {
    final transaction = _insightsDb.startTransaction('_fetchInbox()', 'task');
    ImapClient? imapClient;

    _insightsDb.captureEvent('_fetchInbox()', domain: 'INBOX_CUBIT');

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
              debugPrint(
                  '_fetchInbox lastReadUid $lastReadUid current $current');
              if (subject.contains(await _vectorClockService.getHostHash())) {
                debugPrint('_fetchInbox ignoring from same host: $current');
                _insightsDb.captureEvent(
                    '_fetchInbox ignoring from same host: $current',
                    domain: 'INBOX_CUBIT');

                await _setLastReadUid(current);
              } else {
                await _fetchByUid(uid: current, imapClient: imapClient);
              }
            }
          }
          fetchMutex.release();

          emit(ImapState.online(lastUpdate: DateTime.now()));
        }
      } on MailException catch (e) {
        debugPrint('High level API failed with $e');

        emit(ImapState.failed(error: 'failed: $e ${e.details} ${e.message}'));
        await _insightsDb.captureException(e);
      } catch (e) {
        debugPrint('Exception $e');
        emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
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
    final transaction = _insightsDb.startTransaction('_fetchByUid()', 'task');
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
          emit(ImapState.online(lastUpdate: DateTime.now()));
        }
      } on MailException catch (e) {
        debugPrint('High level API failed with $e');
        await _insightsDb.captureException(e);
        emit(ImapState.failed(error: 'failed: $e ${e.details}'));
      } catch (e, stackTrace) {
        await _insightsDb.captureException(e, stackTrace: stackTrace);
        emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
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
          _fetchInbox();
        });

        _observingClient!.eventBus
            .on<MailConnectionLostEvent>()
            .listen((MailConnectionLostEvent event) async {
          _insightsDb.captureEvent(event);

          await _observingClient!.resume();

          _insightsDb.captureEvent(
            'isConnected: ${_observingClient!.isConnected} '
            'isPolling: ${_observingClient!.isPolling()}',
          );
        });

        _observingClient!.startPolling();
      }
    } on MailException catch (e) {
      debugPrint('High level API failed with $e');
      await _insightsDb.captureException(e);
      emit(ImapState.failed(error: 'failed: $e ${e.details}'));
    } catch (e, stackTrace) {
      await _insightsDb.captureException(e, stackTrace: stackTrace);
      emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
    }
  }

  Future<void> resetOffset() async {
    await _storage.delete(key: lastReadUidKey);
    await _vectorClockService.setNewHost();
  }
}
