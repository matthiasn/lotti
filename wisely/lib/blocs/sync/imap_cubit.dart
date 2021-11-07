import 'dart:async';

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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wisely/blocs/journal/persistence_cubit.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/blocs/sync/imap_state.dart';
import 'package:wisely/classes/journal_db_entities.dart';
import 'package:wisely/classes/sync_message.dart';

import 'imap_tools.dart';

class ImapCubit extends Cubit<ImapState> {
  late final EncryptionCubit _encryptionCubit;
  late final PersistenceCubit _persistenceCubit;
  late final ImapClient _imapClient;
  late final MailClient _mailClient;
  late SyncConfig? _syncConfig;
  late String? _b64Secret;

  final _storage = const FlutterSecureStorage();
  final String sharedSecretKey = 'sharedSecret';
  final String imapConfigKey = 'imapConfig';
  final String lastReadUidKey = 'lastReadUid';

  ImapCubit({
    required EncryptionCubit encryptionCubit,
    required PersistenceCubit persistenceCubit,
  }) : super(ImapState.initial()) {
    _encryptionCubit = encryptionCubit;
    _persistenceCubit = persistenceCubit;
    _imapClient = ImapClient(isLogEnabled: false);
    imapClientInit();
  }

  Future<void> processMessage(MimeMessage message) async {
    final transaction = Sentry.startTransaction('processMessage()', 'task');
    try {
      // TODO: check that message is from different host
      if (true) {
        String? encryptedMessage = readMessage(message);
        SyncMessage? syncMessage =
            await decryptMessage(encryptedMessage, message, _b64Secret);

        syncMessage?.when(
          journalDbEntity: (JournalDbEntity journalDbEntity) async {
            debugPrint(
                'processMessage inserting ${journalDbEntity.runtimeType}');
            journalDbEntity.data.maybeMap(
              journalDbAudio: (JournalDbAudio journalDbAudio) async {
                await saveAudioAttachment(
                    message, journalDbAudio, journalDbEntity, _b64Secret);
              },
              journalDbImage: (JournalDbImage journalDbImage) async {
                await saveImageAttachment(
                    message, journalDbImage, journalDbEntity, _b64Secret);
              },
              orElse: () {},
            );

            _persistenceCubit.createDbEntity(journalDbEntity,
                enqueueSync: false);
          },
        );
      } else {
        debugPrint('Ignoring message');
      }
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
    }

    await transaction.finish();
  }

  Future<void> imapClientInit() async {
    SyncConfig? syncConfig = await _encryptionCubit.loadSyncConfig();
    final transaction = Sentry.startTransaction('imapClientInit()', 'task');

    try {
      if (syncConfig != null) {
        _syncConfig = syncConfig;
        _b64Secret = syncConfig.sharedSecret;
        emit(ImapState.loading());
        ImapConfig imapConfig = syncConfig.imapConfig;

        await _imapClient.connectToServer(
          imapConfig.host,
          imapConfig.port,
          isSecure: true,
        );
        emit(ImapState.connected());
        await _imapClient.login(imapConfig.userName, imapConfig.password);
        emit(ImapState.loggedIn());
        await _imapClient.selectInbox();
        await _pollInbox();
        emit(ImapState.online(lastUpdate: DateTime.now()));
        _startPolling();
        _observeInbox();
      }
    } catch (e, stackTrace) {
      await Sentry.captureException(e, stackTrace: stackTrace);
      emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
    }
    await transaction.finish();
  }

  void _startPolling() async {
    debugPrint('_startPolling');
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      _pollInbox();
      _observeInbox();
    });
  }

  Future<void> _pollInbox() async {
    final transaction = Sentry.startTransaction('_pollInbox()', 'task');
    try {
      if (_syncConfig != null) {
        String? lastReadUidValue = await _storage.read(key: lastReadUidKey);
        int lastReadUid =
            lastReadUidValue != null ? int.parse(lastReadUidValue) : 0;

        var sequence = MessageSequence(isUidSequence: true);
        sequence.addRangeToLast(lastReadUid + 1);
        debugPrint('_pollInbox sequence: $sequence');

        final fetchResult =
            await _imapClient.uidFetchMessages(sequence, 'ENVELOPE');

        List<MimeMessage> messages = fetchResult.messages;

        if (messages.isNotEmpty) {
          int? oldest = fetchResult.messages.first.uid;
          if (lastReadUid != oldest) {
            debugPrint('_pollInbox lastReadUid $lastReadUid oldest $oldest');
            await _fetchByUid(oldest);
            if (messages.length > 1) {
              await _pollInbox();
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
    }
    await transaction.finish();
  }

  Future<void> _fetchByUid(int? uid) async {
    final transaction = Sentry.startTransaction('_fetchByUid()', 'task');
    if (uid != null) {
      try {
        // odd workaround, prevents intermittent failures on macOS
        await _imapClient.uidFetchMessage(uid, 'BODY.PEEK[]');
        FetchImapResult res =
            await _imapClient.uidFetchMessage(uid, 'BODY.PEEK[]');

        for (final message in res.messages) {
          await processMessage(message);
        }
        await _storage.write(key: lastReadUidKey, value: '$uid');
        emit(ImapState.online(lastUpdate: DateTime.now()));
      } on MailException catch (e) {
        debugPrint('High level API failed with $e');
        await Sentry.captureException(e);
        emit(ImapState.failed(error: 'failed: $e ${e.details}'));
      } catch (e, stackTrace) {
        await Sentry.captureException(e, stackTrace: stackTrace);
        emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
      }
    }
    await transaction.finish();
  }

  Future<void> _observeInbox() async {
    try {
      if (_syncConfig != null) {
        _mailClient.stopPollingIfNeeded();
        ImapConfig imapConfig = _syncConfig!.imapConfig;
        final account = MailAccount.fromManualSettings(
          'sync',
          imapConfig.userName,
          imapConfig.host,
          imapConfig.host,
          imapConfig.password,
        );

        _mailClient = MailClient(account, isLogEnabled: false);
        await _mailClient.connect();
        await _mailClient.selectInbox();
        debugPrint('_observeInbox inbox selected');

        _mailClient.eventBus
            .on<MailLoadEvent>()
            .listen((MailLoadEvent event) async {
          _pollInbox();
        });

        _mailClient.eventBus
            .on<MailConnectionLostEvent>()
            .listen((MailConnectionLostEvent event) async {
          await Sentry.captureEvent(
              SentryEvent(
                message: SentryMessage(event.toString()),
              ),
              withScope: (Scope scope) => scope.level = SentryLevel.warning);
          _observeInbox();
        });

        _mailClient.startPolling();
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
