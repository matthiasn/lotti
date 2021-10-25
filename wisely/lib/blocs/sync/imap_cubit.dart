import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/mail/mail_account.dart';
import 'package:enough_mail/mail/mail_client.dart';
import 'package:enough_mail/mail/mail_events.dart';
import 'package:enough_mail/mail/mail_exception.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';
import 'package:wisely/blocs/sync/imap_state.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/sync/encryption.dart';
import 'package:wisely/sync/encryption_salsa.dart';

import '../journal_entities_cubit.dart';
import 'imap_tools.dart';

class ImapCubit extends Cubit<ImapState> {
  late final EncryptionCubit _encryptionCubit;
  late final JournalEntitiesCubit _journalEntitiesCubit;
  late final ImapClient _imapClient;
  late final MailClient _mailClient;
  late SyncConfig? _syncConfig;
  late String _b64Secret;

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
                print('processMessage journalImage $journalImage');
                await saveImageAttachment(message, journalImage, _b64Secret);
                _journalEntitiesCubit.save(journalImage);
              },
              journalEntry: (JournalEntry journalEntry) async {});
        },
      );
    } else {
      print('Ignoring message');
    }
  }

  Future<void> imapClientInit() async {
    SyncConfig? syncConfig = await _encryptionCubit.loadSyncConfig();

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
      await _imapClient.login(imapConfig.userName, imapConfig.password);
      await _imapClient.selectInbox();

      final fetchResult = await _imapClient.fetchRecentMessages(
          messageCount: 10, criteria: 'BODY.PEEK[]');

      for (final message in fetchResult.messages) {
        await processMessage(message);
      }
      emit(ImapState.online());
      pollInbox();
    }
  }

  Future<void> pollInbox() async {
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

      try {
        await _mailClient.connect();
        final mailboxes =
            await _mailClient.listMailboxesAsTree(createIntermediate: false);
        print(mailboxes);
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
            } on MailException catch (e) {
              print('High level API failed with $e');
            }
          }
        });
        await _mailClient.startPolling();
      } on MailException catch (e) {
        print('High level API failed with $e');
      }
    }
  }

  Future<void> saveEncryptedImap(
    SyncMessage syncMessage, {
    File? attachment,
  }) async {
    String jsonString = json.encode(syncMessage);
    String subject = syncMessage.vectorClock.toString();

    if (_b64Secret != null) {
      String encryptedMessage = encryptSalsa(jsonString, _b64Secret);
      if (attachment != null) {
        int fileLength = attachment.lengthSync();
        if (fileLength > 0) {
          File encryptedFile = File('${attachment.path}.aes');
          await encryptFile(attachment, encryptedFile, _b64Secret);
          saveImapMessage(
              _imapClient, subject, encryptedMessage, encryptedFile);
        }
      } else {
        saveImapMessage(_imapClient, subject, encryptedMessage, null);
      }
    }
  }
}
