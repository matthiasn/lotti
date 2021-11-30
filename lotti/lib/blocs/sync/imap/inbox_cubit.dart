import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/imap/message_sequence.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/mail/mail_account.dart';
import 'package:enough_mail/mail/mail_client.dart';
import 'package:enough_mail/mail/mail_events.dart';
import 'package:enough_mail/mail/mail_exception.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/sync/config_classes.dart';
import 'package:lotti/blocs/sync/encryption_cubit.dart';
import 'package:lotti/blocs/sync/imap/imap_client.dart';
import 'package:lotti/blocs/sync/imap/imap_state.dart';
import 'package:lotti/blocs/sync/imap/inbox_read.dart';
import 'package:lotti/blocs/sync/imap/inbox_save_attachments.dart';
import 'package:lotti/blocs/sync/vector_clock_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mutex/mutex.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class InboxImapCubit extends Cubit<ImapState> {
  late final EncryptionCubit _encryptionCubit;
  late final PersistenceCubit _persistenceCubit;
  late final VectorClockCubit _vectorClockCubit;
  MailClient? _observingClient;
  late final StreamSubscription<FGBGType> fgBgSubscription;
  Timer? timer;
  final fetchMutex = Mutex();

  final _storage = const FlutterSecureStorage();
  final String sharedSecretKey = 'sharedSecret';
  final String imapConfigKey = 'imapConfig';
  final String lastReadUidKey = 'lastReadUid';

  InboxImapCubit({
    required EncryptionCubit encryptionCubit,
    required PersistenceCubit persistenceCubit,
    required VectorClockCubit vectorClockCubit,
  }) : super(ImapState.initial()) {
    _encryptionCubit = encryptionCubit;
    _persistenceCubit = persistenceCubit;
    _vectorClockCubit = vectorClockCubit;

    if (!Platform.isMacOS) {
      fgBgSubscription = FGBGEvents.stream.listen((event) {
        Sentry.captureEvent(
            SentryEvent(
              message: SentryMessage(event.toString()),
            ),
            withScope: (Scope scope) => scope.level = SentryLevel.info);
        if (event == FGBGType.foreground) {
          _startPeriodicFetching();
          _observeInbox();
        }
        if (event == FGBGType.background) {
          _stopPeriodicFetching();
        }
      });
    }
    _startPeriodicFetching();
    _observeInbox();
  }

  Future<void> processMessage(MimeMessage message) async {
    final transaction = Sentry.startTransaction('processMessage()', 'task');
    try {
      String? encryptedMessage = readMessage(message);
      SyncConfig? syncConfig = await _encryptionCubit.loadSyncConfig();

      if (syncConfig != null) {
        String b64Secret = syncConfig.sharedSecret;

        SyncMessage? syncMessage =
            await decryptMessage(encryptedMessage, message, b64Secret);

        syncMessage?.when(
          journalDbEntity:
              (JournalEntity journalEntity, SyncEntryStatus status) async {
            await saveJournalEntityJson(journalEntity);

            journalEntity.maybeMap(
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
        );
      } else {
        throw Exception('missing IMAP config');
      }
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
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
    final transaction = Sentry.startTransaction('_fetchInbox()', 'task');
    ImapClient? imapClient;

    if (!fetchMutex.isLocked) {
      await fetchMutex.acquire();

      try {
        imapClient = await createImapClient(_encryptionCubit);

        String? lastReadUidValue = await _storage.read(key: lastReadUidKey);
        int lastReadUid =
            lastReadUidValue != null ? int.parse(lastReadUidValue) : 0;

        var sequence = MessageSequence(isUidSequence: true);
        sequence.addRangeToLast(lastReadUid + 1);
        debugPrint('_fetchInbox sequence: $sequence');

        if (imapClient != null) {
          final fetchResult =
              await imapClient.uidFetchMessages(sequence, 'ENVELOPE');

          List<MimeMessage> messages = fetchResult.messages;

          if (messages.isNotEmpty) {
            int? oldest = fetchResult.messages.first.uid;
            String subject = '${fetchResult.messages.first.decodeSubject()}';
            if (lastReadUid != oldest) {
              debugPrint('_fetchInbox lastReadUid $lastReadUid oldest $oldest');

              if (subject.contains(await _vectorClockCubit.getHostHash())) {
                debugPrint('_fetchInbox ignoring from same host: $oldest');
                await _setLastReadUid(oldest);
              } else {
                await _fetchByUid(oldest);
              }
              fetchMutex.release();

              if (messages.length > 1) {
                await _fetchInbox();
              }
            }
          }
          emit(ImapState.online(lastUpdate: DateTime.now()));
        }
      } on MailException catch (e) {
        debugPrint('High level API failed with $e');
        emit(ImapState.failed(error: 'failed: $e ${e.details} ${e.message}'));
        await Sentry.captureException(e);
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

  Future<void> _fetchByUid(int? uid) async {
    final transaction = Sentry.startTransaction('_fetchByUid()', 'task');
    if (uid != null) {
      ImapClient? imapClient;

      try {
        imapClient = await createImapClient(_encryptionCubit);

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
        await Sentry.captureException(e);
        emit(ImapState.failed(error: 'failed: $e ${e.details}'));
      } catch (e, stackTrace) {
        await Sentry.captureException(e, stackTrace: stackTrace);
        emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
      } finally {
        imapClient?.disconnect();
      }
    }
    await transaction.finish();
  }

  Future<void> _observeInbox() async {
    try {
      SyncConfig? syncConfig = await _encryptionCubit.loadSyncConfig();

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
          await Sentry.captureEvent(
              SentryEvent(message: SentryMessage(event.toString())),
              withScope: (Scope scope) => scope.level = SentryLevel.warning);
          await _observingClient!.resume();

          await Sentry.captureEvent(
              SentryEvent(
                message: SentryMessage(
                  'isConnected: ${_observingClient!.isConnected} '
                  'isPolling: ${_observingClient!.isPolling()}',
                ),
              ),
              withScope: (Scope scope) => scope.level = SentryLevel.info);
        });

        _observingClient!.startPolling();
      }
    } on MailException catch (e) {
      debugPrint('High level API failed with $e');
      await Sentry.captureException(e);
      emit(ImapState.failed(error: 'failed: $e ${e.details}'));
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
    }
  }

  Future<void> resetOffset() async {
    await _storage.delete(key: lastReadUidKey);
  }
}
