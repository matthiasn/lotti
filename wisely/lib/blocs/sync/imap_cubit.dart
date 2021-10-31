import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/mail/mail_account.dart';
import 'package:enough_mail/mail/mail_client.dart';
import 'package:enough_mail/mail/mail_events.dart';
import 'package:enough_mail/mail/mail_exception.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/blocs/sync/imap_state.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/utils/image_utils.dart';

import '../journal_entities_cubit.dart';
import 'imap_tools.dart';

class ImapCubit extends Cubit<ImapState> {
  late final EncryptionCubit _encryptionCubit;
  late final JournalEntitiesCubit _journalEntitiesCubit;
  late final ImapClient _imapClient;
  late final MailClient _mailClient;
  late SyncConfig? _syncConfig;
  late String? _b64Secret;

  ImapCubit({
    required EncryptionCubit encryptionCubit,
    required JournalEntitiesCubit journalEntitiesCubit,
  }) : super(ImapState.initial()) {
    _encryptionCubit = encryptionCubit;
    _journalEntitiesCubit = journalEntitiesCubit;
    _imapClient = ImapClient(isLogEnabled: false);
    imapClientInit();
  }

  Future<void> processMessage(MimeMessage message) async {
    if (Platform.isMacOS) {
      String? encryptedMessage = readMessage(message);
      SyncMessage? syncMessage =
          await decryptMessage(encryptedMessage, message, _b64Secret);
      syncMessage?.when(
        journalEntity: (JournalEntity entity, _) async {
          entity.map(
              audioNote: (AudioNote audioNote) async {
                await saveAudioAttachment(message, audioNote, _b64Secret);
                _journalEntitiesCubit.save(audioNote);
              },
              journalImage: (JournalImage journalImage) async {
                debugPrint('processMessage journalImage $journalImage');
                await saveImageAttachment(message, journalImage, _b64Secret);
                _journalEntitiesCubit.save(journalImage);
              },
              journalEntry: (JournalEntry journalEntry) async {});
        },
      );
    } else {
      debugPrint('Ignoring message');
    }
  }

  Future<void> imapClientInit() async {
    SyncConfig? syncConfig = await _encryptionCubit.loadSyncConfig();

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
        Mailbox mb = await _imapClient.selectInbox();
        debugPrint(mb.toString());
        await _pollInbox();
        emit(ImapState.online(lastUpdate: DateTime.now()));
        _startPolling();
        _observeInbox();
      }
    } catch (e) {
      emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
    }
  }

  void _startPolling() async {
    debugPrint('_startPolling');
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      _pollInbox();
    });
  }

  Future<void> _pollInbox() async {
    try {
      debugPrint('_pollInbox');
      if (_syncConfig != null) {
        final fetchResult = await _imapClient.fetchRecentMessages(
            messageCount: 100, criteria: 'BODY.PEEK[]');
        for (final message in fetchResult.messages) {
          await processMessage(message);
        }
        emit(ImapState.online(lastUpdate: DateTime.now()));
      }
    } on MailException catch (e) {
      debugPrint('High level API failed with $e');
      emit(ImapState.failed(error: 'failed: $e ${e.details} ${e.message}'));
    } catch (e) {
      emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
    }
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

        _mailClient = MailClient(account, isLogEnabled: false);
        await _mailClient.connect();
        final mailboxes =
            await _mailClient.listMailboxesAsTree(createIntermediate: false);
        debugPrint('mailboxes: $mailboxes');
        await _mailClient.selectInbox();
        final messages = await _mailClient.fetchMessages(count: 20);
        for (final message in messages) {
          processMessage(message);
        }
        _mailClient.eventBus
            .on<MailLoadEvent>()
            .listen((MailLoadEvent event) async {
          if (event.message.uid != null) {
            try {
              // odd workaround, prevents intermittent failures on Mac when
              // awaiting this twice
              await _imapClient.uidFetchMessage(
                  event.message.uid!, 'BODY.PEEK[]');
              FetchImapResult res = await _imapClient.uidFetchMessage(
                  event.message.uid!, 'BODY.PEEK[]');

              for (final message in res.messages) {
                processMessage(message);
              }
              emit(ImapState.online(lastUpdate: DateTime.now()));
            } on MailException catch (e) {
              debugPrint('High level API failed with $e');
              emit(ImapState.failed(error: 'failed: $e ${e.details}'));
            }
          }
        });
        await _mailClient.startPolling();
      }
    } on MailException catch (e) {
      debugPrint('High level API failed with $e');
      emit(ImapState.failed(error: 'failed: $e ${e.details}'));
    } catch (e) {
      emit(ImapState.failed(error: 'failed: $e ${e.toString()}'));
    }
  }

  Future<bool> saveImap(
    String encryptedMessage,
    String subject, {
    String? encryptedFilePath,
  }) async {
    GenericImapResult? res;
    if (_b64Secret != null) {
      if (encryptedFilePath != null && encryptedFilePath.isNotEmpty) {
        File encryptedFile = File(await getFullAssetPath(encryptedFilePath));
        int fileLength = encryptedFile.lengthSync();
        if (fileLength > 0) {
          res = await saveImapMessage(_imapClient, subject, encryptedMessage,
              file: encryptedFile);
        }
      } else {
        res = await saveImapMessage(_imapClient, subject, encryptedMessage);
      }
    }
    if (res?.details != null && res!.details!.contains('completed')) {
      return true;
    } else {
      return false;
    }
  }
}
