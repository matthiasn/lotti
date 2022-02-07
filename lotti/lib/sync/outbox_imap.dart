import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:lotti/blocs/sync/imap/imap_client.dart';
import 'package:lotti/blocs/sync/imap/outbox_save_imap.dart';
import 'package:lotti/database/insights_db.dart';
import 'package:lotti/main.dart';

const String sharedSecretKey = 'sharedSecret';
const String imapConfigKey = 'imapConfig';
const String lastReadUidKey = 'lastReadUid';
final InsightsDb _insightsDb = getIt<InsightsDb>();

Future<ImapClient?> saveImap({
  required String encryptedMessage,
  required String subject,
  String? encryptedFilePath,
  ImapClient? prevImapClient,
}) async {
  ImapClient? imapClient;
  try {
    final transaction = _insightsDb.startTransaction('saveImap()', 'task');
    if (prevImapClient != null) {
      imapClient = prevImapClient;
    } else {
      imapClient = await createImapClient();
    }

    GenericImapResult? res;
    if (imapClient != null) {
      if (encryptedFilePath != null && encryptedFilePath.isNotEmpty) {
        File encryptedFile = File(encryptedFilePath);
        int fileLength = encryptedFile.lengthSync();
        if (fileLength > 0) {
          res = await saveImapMessage(imapClient, subject, encryptedMessage,
              file: encryptedFile);
        }
      } else {
        res = await saveImapMessage(imapClient, subject, encryptedMessage);
      }
    }
    await transaction.finish();

    String? resDetails = res?.details;
    _insightsDb.captureEvent(resDetails ?? 'no result details');

    if (resDetails != null && resDetails.contains('completed')) {
      return imapClient;
    } else {
      await imapClient?.disconnect();
      return null;
    }
  } catch (exception, stackTrace) {
    await _insightsDb.captureException(
      exception,
      stackTrace: stackTrace,
    );
    rethrow;
  } finally {}
}
