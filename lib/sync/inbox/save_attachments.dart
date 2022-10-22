import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';

Future<void> saveAudioAttachment(
  MimeMessage message,
  JournalAudio? journalAudio,
  String? b64Secret,
) async {
  final attachments = message.findContentInfo();

  getIt<LoggingDb>().captureEvent(
    'start',
    domain: 'INBOX',
    subDomain: 'saveAudioAttachment',
  );

  for (final attachment in attachments) {
    final attachmentMimePart = message.getPart(attachment.fetchId);
    if (attachmentMimePart != null &&
        journalAudio != null &&
        b64Secret != null) {
      final bytes = attachmentMimePart.decodeContentBinary();
      final filePath = await AudioUtils.getFullAudioPath(journalAudio);
      await File(filePath).parent.create(recursive: true);
      final encrypted = File('$filePath.aes');
      debugPrint('saveAttachment $filePath');

      getIt<LoggingDb>().captureEvent(
        'saving $filePath',
        domain: 'INBOX',
        subDomain: 'saveAudioAttachment',
      );

      await writeToFile(bytes, encrypted.path);

      getIt<LoggingDb>().captureEvent(
        'wrote $filePath',
        domain: 'INBOX',
        subDomain: 'saveAudioAttachment',
      );

      await decryptFile(encrypted, File(filePath), b64Secret);
    }
  }
}

Future<void> saveImageAttachment(
  MimeMessage message,
  JournalImage? journalImage,
  String? b64Secret,
) async {
  final attachments = message.findContentInfo();

  getIt<LoggingDb>().captureEvent(
    'start',
    domain: 'INBOX',
    subDomain: 'saveImageAttachment',
  );

  for (final attachment in attachments) {
    final attachmentMimePart = message.getPart(attachment.fetchId);
    if (attachmentMimePart != null &&
        journalImage != null &&
        b64Secret != null) {
      final bytes = attachmentMimePart.decodeContentBinary();
      final filePath = getFullImagePath(journalImage);
      await File(filePath).parent.create(recursive: true);
      final encrypted = File('$filePath.aes');
      debugPrint('saveAttachment $filePath');

      getIt<LoggingDb>().captureEvent(
        'saving $filePath',
        domain: 'INBOX',
        subDomain: 'saveImageAttachment',
      );

      await writeToFile(bytes, encrypted.path);

      getIt<LoggingDb>().captureEvent(
        'wrote $filePath',
        domain: 'INBOX',
        subDomain: 'saveImageAttachment',
      );

      await decryptFile(encrypted, File(filePath), b64Secret);
    }
  }
}

Future<void> writeToFile(Uint8List? data, String filePath) async {
  if (data != null) {
    await File(filePath).writeAsBytes(data);
  } else {
    debugPrint('No bytes for $filePath');

    getIt<LoggingDb>().captureEvent(
      'No bytes for $filePath',
      domain: 'INBOX',
      subDomain: 'writeToFile',
    );
  }
}
