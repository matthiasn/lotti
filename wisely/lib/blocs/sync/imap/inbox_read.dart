import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/sync/encryption.dart';

Future<SyncMessage?> decryptMessage(
    String? encryptedMessage, MimeMessage message, String? b64Secret) async {
  if (encryptedMessage != null) {
    if (b64Secret != null) {
      String decryptedJson = await decryptString(encryptedMessage, b64Secret);
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
