import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:flutter/foundation.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/sync/encryption.dart';
import 'package:wisely/sync/encryption_salsa.dart';
import 'package:wisely/utils/audio_utils.dart';
import 'package:wisely/utils/image_utils.dart';

Future<void> saveAudioAttachment(
  MimeMessage message,
  AudioNote? audioNote,
  String? b64Secret,
) async {
  final attachments =
      message.findContentInfo(disposition: ContentDisposition.attachment);

  for (final attachment in attachments) {
    final MimePart? attachmentMimePart = message.getPart(attachment.fetchId);
    if (attachmentMimePart != null && audioNote != null && b64Secret != null) {
      Uint8List? bytes = attachmentMimePart.decodeContentBinary();
      String filePath = await AudioUtils.getFullAudioPath(audioNote);
      await File(filePath).parent.create(recursive: true);
      File encrypted = File('$filePath.aes');
      debugPrint('saveAttachment $filePath');
      await writeToFile(bytes, encrypted.path);
      await decryptFile(encrypted, File(filePath), b64Secret);
      await AudioUtils.saveAudioNoteJson(audioNote);
    }
  }
}

Future<void> saveImageAttachment(
  MimeMessage message,
  JournalImage journalImage,
  String? b64Secret,
) async {
  final attachments =
      message.findContentInfo(disposition: ContentDisposition.attachment);

  for (final attachment in attachments) {
    final MimePart? attachmentMimePart = message.getPart(attachment.fetchId);
    if (attachmentMimePart != null &&
        journalImage != null &&
        b64Secret != null) {
      Uint8List? bytes = attachmentMimePart.decodeContentBinary();
      String filePath = await getFullImagePath(journalImage);
      await File(filePath).parent.create(recursive: true);
      File encrypted = File('$filePath.aes');
      debugPrint('saveAttachment $filePath');
      await writeToFile(bytes, encrypted.path);
      await decryptFile(encrypted, File(filePath), b64Secret);
      await saveJournalImageJson(journalImage);
    }
  }
}

Future<SyncMessage?> decryptMessage(
    String? encryptedMessage, MimeMessage message, String? b64Secret) async {
  if (encryptedMessage != null) {
    if (b64Secret != null) {
      String decryptedJson = decryptSalsa(encryptedMessage, b64Secret);
      return SyncMessage.fromJson(json.decode(decryptedJson));
    }
  }
}

String? readMessage(MimeMessage message) {
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
    return concatenated.trim();
  }
}

Future<void> writeToFile(Uint8List? data, String filePath) async {
  if (data != null) {
    await File(filePath).writeAsBytes(data);
  } else {
    debugPrint('No bytes for $filePath');
  }
}

Future<GenericImapResult> saveImapMessage(
  ImapClient imapClient,
  String subject,
  String encryptedMessage, {
  File? file,
}) async {
  Mailbox inbox = await imapClient.selectInbox();
  final builder = MessageBuilder.prepareMultipartAlternativeMessage();
  builder.from = [MailAddress('Sync', 'sender@domain.com')];
  builder.to = [MailAddress('Sync', 'recipient@domain.com')];
  builder.subject = subject;
  builder.addTextPlain(encryptedMessage);

  if (file != null) {
    int fileLength = file.lengthSync();
    if (fileLength > 0) {
      await builder.addFile(
          file, MediaType.fromText('application/octet-stream'));
    }
  }

  final MimeMessage message = builder.buildMimeMessage();
  GenericImapResult res =
      await imapClient.appendMessage(message, targetMailbox: inbox);
  debugPrint(
      'saveImapMessage responseCode ${res.responseCode} details ${res.details}');
  return res;
}
