import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/sync/encryption.dart';
import 'package:wisely/utils/audio_utils.dart';
import 'package:wisely/utils/image_utils.dart';

Future<void> saveAudioAttachment(
  MimeMessage message,
  JournalAudio? journalAudio,
  String? b64Secret,
) async {
  final transaction = Sentry.startTransaction('saveAudioAttachment()', 'task');
  final attachments =
      message.findContentInfo(disposition: ContentDisposition.attachment);

  for (final attachment in attachments) {
    final MimePart? attachmentMimePart = message.getPart(attachment.fetchId);
    if (attachmentMimePart != null &&
        journalAudio != null &&
        b64Secret != null) {
      Uint8List? bytes = attachmentMimePart.decodeContentBinary();
      String filePath = await AudioUtils.getFullAudioPath(journalAudio);
      await File(filePath).parent.create(recursive: true);
      File encrypted = File('$filePath.aes');
      debugPrint('saveAttachment $filePath');
      await writeToFile(bytes, encrypted.path);
      await decryptFile(encrypted, File(filePath), b64Secret);
      await AudioUtils.saveAudioNoteJson(journalAudio);
    }
  }
  await transaction.finish();
}

Future<void> saveImageAttachment(
  MimeMessage message,
  JournalImage? journalImage,
  String? b64Secret,
) async {
  final transaction = Sentry.startTransaction('saveImageAttachment()', 'task');
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
  await transaction.finish();
}

Future<void> writeToFile(Uint8List? data, String filePath) async {
  if (data != null) {
    await File(filePath).writeAsBytes(data);
  } else {
    debugPrint('No bytes for $filePath');
  }
}
