import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/insights_db.dart';
import 'package:lotti/main.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';

Future<void> saveAudioAttachment(
  MimeMessage message,
  JournalAudio? journalAudio,
  String? b64Secret,
) async {
  final InsightsDb _insightsDb = getIt<InsightsDb>();

  final transaction =
      _insightsDb.startTransaction('saveAudioAttachment()', 'task');
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
    }
  }
  await transaction.finish();
}

Future<void> saveImageAttachment(
  MimeMessage message,
  JournalImage? journalImage,
  String? b64Secret,
) async {
  final InsightsDb _insightsDb = getIt<InsightsDb>();
  final transaction =
      _insightsDb.startTransaction('saveImageAttachment()', 'task');
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
