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
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wisely/blocs/journal/persistence_cubit.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/blocs/sync/imap_state.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/utils/file_utils.dart';

import 'imap_tools.dart';

class ImapCubit extends Cubit<ImapState> {
  late final EncryptionCubit _encryptionCubit;
  late final PersistenceCubit _persistenceCubit;
  late final VectorClockCubit _vectorClockCubit;
  late final ImapClient _imapClient;
  MailClient? _observingClient;
  late SyncConfig? _syncConfig;
  late String? _b64Secret;
  late final StreamSubscription<FGBGType> fgBgSubscription;
  Timer? timer;

  final _storage = const FlutterSecureStorage();
  final String sharedSecretKey = 'sharedSecret';
  final String imapConfigKey = 'imapConfig';
  final String lastReadUidKey = 'lastReadUid';

  ImapCubit({
    required EncryptionCubit encryptionCubit,
    required PersistenceCubit persistenceCubit,
    required VectorClockCubit vectorClockCubit,
  }) : super(ImapState.initial()) {
    _encryptionCubit = encryptionCubit;
    _persistenceCubit = persistenceCubit;
    _vectorClockCubit = vectorClockCubit;
    _imapClient = ImapClient(isLogEnabled: false);
    imapClientInit();

    if (!Platform.isMacOS) {
      fgBgSubscription = FGBGEvents.stream.listen((event) {
        Sentry.captureEvent(
            SentryEvent(
              message: SentryMessage(event.toString()),
            ),
            withScope: (Scope scope) => scope.level = SentryLevel.info);
        if (event == FGBGType.foreground) {
          _startPolling();
          _observingClient?.resume();
        }
        if (event == FGBGType.background) {
          _stopPolling();
        }
      });
    }
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
          journalDbEntity:
              (JournalEntity journalEntity, SyncEntryStatus status) async {
            journalEntity.maybeMap(
              journalAudio: (JournalAudio journalAudio) async {
                await saveAudioAttachment(message, journalAudio, _b64Secret);
              },
              journalImage: (JournalImage journalImage) async {
                await saveImageAttachment(message, journalImage, _b64Secret);
              },
              journalEntry: (JournalEntry journalEntry) async {
                await saveJournalEntryJson(journalEntry);
              },
              orElse: () {},
            );

            if (status == SyncEntryStatus.update) {
              debugPrint(
                  'processMessage updating ${journalEntity.runtimeType}');
              _persistenceCubit.updateDbEntity(journalEntity,
                  enqueueSync: false);
            } else {
              debugPrint(
                  'processMessage inserting ${journalEntity.runtimeType}');
              _persistenceCubit.createDbEntity(journalEntity,
                  enqueueSync: false);
            }
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
    timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      _pollInbox();
    });
  }

  void _stopPolling() async {
    if (timer != null) {
      timer!.cancel();
    }
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
          String subject = '${fetchResult.messages.first.decodeSubject()}';
          if (lastReadUid != oldest) {
            debugPrint('_pollInbox lastReadUid $lastReadUid oldest $oldest');

            if (subject.contains(_vectorClockCubit.getHostHash())) {
              debugPrint('_pollInbox ignoring from same host: $oldest');
              _setLastReadUid(oldest);
            } else {
              await _fetchByUid(oldest);
            }

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

  Future<void> _setLastReadUid(int? uid) async {
    await _storage.write(key: lastReadUidKey, value: '$uid');
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
        await _setLastReadUid(uid);
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
        ImapConfig imapConfig = _syncConfig!.imapConfig;
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
          _pollInbox();
        });

        _observingClient!.eventBus
            .on<MailConnectionLostEvent>()
            .listen((MailConnectionLostEvent event) async {
          await Sentry.captureEvent(
              SentryEvent(
                message: SentryMessage(event.toString()),
              ),
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
