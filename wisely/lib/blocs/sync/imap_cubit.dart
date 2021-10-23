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
import 'package:wisely/db/audio_note.dart';
import 'package:wisely/sync/encryption.dart';
import 'package:wisely/sync/encryption_salsa.dart';
import 'package:wisely/utils/audio_utils.dart';

import '../audio_notes_cubit.dart';
import 'imap_tools.dart';

class ImapCubit extends Cubit<ImapState> {
  late final EncryptionCubit _encryptionCubit;
  late final AudioNotesCubit _audioNotesCubit;
  late final ImapClient _imapClient;
  late final MailClient _mailClient;
  late SyncConfig? _syncConfig;
  late String _b64Secret;

  ImapCubit({
    required EncryptionCubit encryptionCubit,
    required AudioNotesCubit audioNotesCubit,
  }) : super(ImapState.initial()) {
    _encryptionCubit = encryptionCubit;
    _audioNotesCubit = audioNotesCubit;
    _imapClient = ImapClient(isLogEnabled: false);
    imapClientInit();
  }

  Future<void> processMessage(MimeMessage message) async {
    if (Platform.isMacOS) {
      String? encryptedMessage = readMessage(message);
      AudioNote? audioNote =
          await decryptMessage(encryptedMessage, message, _b64Secret);
      await saveAttachment(message, audioNote, _b64Secret);
      if (audioNote != null) _audioNotesCubit.save(audioNote);
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

  Future<void> saveEncryptedImap(AudioNote audioNote) async {
    String jsonString = json.encode(audioNote.toJson());
    String subject = audioNote.vectorClock.toString();

    File? audioFile = await AudioUtils.getAudioFile(audioNote);

    if (_b64Secret != null) {
      String encryptedMessage = encryptSalsa(jsonString, _b64Secret);
      saveImapMessage(_imapClient, subject, encryptedMessage, null);

      if (audioFile != null) {
        int fileLength = audioFile.lengthSync();
        if (fileLength > 0) {
          File encryptedFile = File('${audioFile.path}.aes');
          await encryptFile(audioFile, encryptedFile, _b64Secret);
          saveImapMessage(
              _imapClient, subject, encryptedMessage, encryptedFile);
        }
      }
    }
  }
}
