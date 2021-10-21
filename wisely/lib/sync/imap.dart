import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/mail/mail_client.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:wisely/blocs/audio_notes_cubit.dart';
import 'package:wisely/blocs/sync/classes.dart';
import 'package:wisely/db/audio_note.dart';
import 'package:wisely/sync/secure_storage.dart';
import 'package:wisely/utils/audio_utils.dart';

import 'encryption_salsa.dart';

class ImapSyncClient {
  late ImapConfig _imapConfig;
  late ImapClient client;
  late AudioNotesCubit _audioNotesCubit;

  ImapSyncClient(
    ImapConfig imapConfig,
    AudioNotesCubit audioNotesCubit,
  ) {
    client = ImapClient(isLogEnabled: true);
    _imapConfig = imapConfig;
    _audioNotesCubit = audioNotesCubit;
    init();
    listen();
  }

  void init() async {
    print('host: ${_imapConfig.host}.host, user: ${_imapConfig.userName}');

    await client.connectToServer(_imapConfig.host, _imapConfig.port,
        isSecure: true);
    await client.login(_imapConfig.userName, _imapConfig.password);

    final mailboxes = await client.listMailboxes();
    print('mailboxes: $mailboxes');
    await client.selectInbox();

    // fetch 10 most recent messages:
    final fetchResult = await client.fetchRecentMessages(
        messageCount: 10, criteria: 'BODY.PEEK[]');

    for (final message in fetchResult.messages) {
      printMessage(message);
    }
  }

  void listen() async {
    print('host: ${_imapConfig.host}.host, user: ${_imapConfig.userName}');

    final account = MailAccount.fromManualSettings(
      'sync',
      _imapConfig.userName,
      _imapConfig.host,
      _imapConfig.host,
      _imapConfig.password,
    );

    final mailClient = MailClient(account, isLogEnabled: true);

    try {
      await mailClient.connect();
      print('connected');
      final mailboxes =
          await mailClient.listMailboxesAsTree(createIntermediate: false);
      print(mailboxes);
      await mailClient.selectInbox();
      final messages = await mailClient.fetchMessages(count: 20);
      for (final msg in messages) {
        printMessage(msg);
      }
      mailClient.eventBus
          .on<MailLoadEvent>()
          .listen((MailLoadEvent event) async {
        print('XXX New message at ${DateTime.now()}: ${event.message}');

        if (event.message.uid != null) {
          try {
            // odd workaround, prevents intermittent failures on Mac when
            // awaiting this twice
            await client.uidFetchMessage(event.message.uid!, 'BODY.PEEK[]');
            FetchImapResult res =
                await client.uidFetchMessage(event.message.uid!, 'BODY.PEEK[]');

            for (final msg in res.messages) {
              printMessage(msg);
            }
          } on MailException catch (e) {
            print('High level API failed with $e');
          }
        }
      });
      await mailClient.startPolling();
    } on MailException catch (e) {
      print('High level API failed with $e');
    }
  }

  void saveAttachment(MimeMessage message, AudioNote audioNote) async {
    final attachments =
        message.findContentInfo(disposition: ContentDisposition.attachment);

    for (final attachment in attachments) {
      final MimePart? attachmentMimePart = message.getPart(attachment.fetchId);
      // do something with the attachment
      print('attachmentMimePart $attachmentMimePart');

      if (attachmentMimePart != null) {
        Uint8List? foo = attachmentMimePart.decodeContentBinary();
        String filePath = await AudioUtils.getFullAudioPath(audioNote);
        print('saveAttachment $filePath');
        writeToFile(foo, filePath);
      }
    }
  }

  void printDecryptedMessage(
      String encryptedMessage, MimeMessage message) async {
    print('printDecryptedMessage: $encryptedMessage');
    String? b64Secret = await SecureStorage.readValue('sharedSecret');
    if (b64Secret != null) {
      String decryptedJson = decryptSalsa(encryptedMessage, b64Secret);
      print('Decrypted from IMAP: $decryptedJson');
      AudioNote audioNote = AudioNote.fromJson(json.decode(decryptedJson));
      if (Platform.isMacOS) {
        _audioNotesCubit.save(audioNote);
        saveAttachment(message, audioNote);
      }
    }
  }

  void printMessage(MimeMessage message) {
    print(
        'from: ${message.from} with subject "${message.decodeSubject()}" and sequenceId ${message.sequenceId} and uid ${message.uid}');
    if (!message.isTextPlainMessage()) {
      print(' content-type: ${message.mediaType}');
    } else {
      message.parse();
      final plainText = message.decodeTextPlainPart();
      String concatenated = '';
      if (plainText != null) {
        final lines = plainText.split('\r\n');
        for (final line in lines) {
          if (line.startsWith('>')) {
            break;
          }
          concatenated = concatenated + line;
        }
        String encrypted = concatenated.trim();
        printDecryptedMessage(encrypted, message);

        final attachments =
            message.findContentInfo(disposition: ContentDisposition.attachment);

        for (final attachment in attachments) {
          final MimePart? attachmentMimePart =
              message.getPart(attachment.fetchId);
          // do something with the attachment
          print('attachmentMimePart $attachmentMimePart');

          if (attachmentMimePart != null) {
            Uint8List? foo = attachmentMimePart.decodeContentBinary();
            print('attachmentMimePart $foo');
            writeToFile(foo, '/tmp/test.aac');
          }
        }
      }
    }
  }

  Future<void> writeToFile(Uint8List? data, String filePath) async {
    if (data != null) {
      File(filePath).writeAsBytes(data);
    }
  }

  void saveImapMessage(
      String subject, String encryptedMessage, File? file) async {
    Mailbox inbox = await client.selectInbox();
    final builder = MessageBuilder.prepareMultipartAlternativeMessage();
    builder.from = [MailAddress('Sync', 'sender@domain.com')];
    builder.to = [MailAddress('Sync', 'recipient@domain.com')];
    builder.subject = subject;
    builder.addTextPlain(encryptedMessage);

    if (file != null) {
      int fileLength = file.lengthSync();
      if (fileLength > 0) {
        await builder.addFile(file, MediaType.fromText('audio/aac'));
      }
    }

    final MimeMessage message = builder.buildMimeMessage();
    client.appendMessage(message, targetMailbox: inbox);
  }
}
