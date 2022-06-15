import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/sync/encryption.dart';

Future<SyncMessage?> decryptMessage(
  String? encryptedMessage,
  MimeMessage message,
  String? b64Secret,
) async {
  if (encryptedMessage != null) {
    if (b64Secret != null) {
      final decryptedJson = await decryptString(encryptedMessage, b64Secret);
      return SyncMessage.fromJson(
        json.decode(decryptedJson) as Map<String, dynamic>,
      );
    }
  }
  return null;
}

String? readMessage(MimeMessage message) {
  message.parse();
  final plainText = message.decodeTextPlainPart();
  final buffer = StringBuffer();
  if (plainText != null) {
    final lines = plainText.split('\r\n');
    for (final line in lines) {
      if (line.startsWith('>')) {
        break;
      }

      buffer.write(line);
    }
    return buffer.toString().trim();
  }
  return null;
}
