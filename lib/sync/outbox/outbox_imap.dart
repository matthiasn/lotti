import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/imap_client.dart';

Future<MimeMessage> createImapMessage({
  required String subject,
  required String encryptedMessage,
  File? file,
}) async {
  final loggingDb = getIt<LoggingDb>();

  try {
    final builder = MessageBuilder.prepareMultipartAlternativeMessage()
      ..subject = subject
      ..addTextPlain(encryptedMessage);

    if (file != null) {
      final fileLength = file.lengthSync();
      if (fileLength > 0) {
        await builder.addFile(
          file,
          MediaType.fromText('application/octet-stream'),
        );
      }
    }

    return builder.buildMimeMessage();
  } catch (exception, stackTrace) {
    loggingDb.captureException(
      exception,
      domain: 'OUTBOX_IMAP',
      subDomain: 'createImapMessage',
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<GenericImapResult> saveImapMessage({
  required SyncConfig syncConfig,
  required ImapClient imapClient,
  required String subject,
  required String encryptedMessage,
  File? file,
}) async {
  final loggingDb = getIt<LoggingDb>();

  try {
    final inbox = await imapClient.selectMailboxByPath(
      syncConfig.imapConfig.folder,
    );

    final message = await createImapMessage(
      subject: subject,
      encryptedMessage: encryptedMessage,
      file: file,
    );

    final res = await imapClient.appendMessage(
      message,
      targetMailbox: inbox,
      flags: [r'\Seen'],
    );
    debugPrint(
      'saveImapMessage responseCode ${res.responseCode} details ${res.details}',
    );
    return res;
  } catch (exception, stackTrace) {
    loggingDb.captureException(
      exception,
      domain: 'OUTBOX_IMAP',
      subDomain: 'saveImapMessage',
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<bool> persistImap({
  required String encryptedMessage,
  required String subject,
  required SyncConfig syncConfig,
  required bool allowInvalidCert,
  String? encryptedFilePath,
}) async {
  final loggingDb = getIt<LoggingDb>();

  return getIt<ImapClientManager>().imapAction(
    (imapClient) async {
      try {
        GenericImapResult? res;

        if (encryptedFilePath != null && encryptedFilePath.isNotEmpty) {
          final encryptedFile = File(encryptedFilePath);
          final fileLength = encryptedFile.lengthSync();
          if (fileLength > 0) {
            res = await saveImapMessage(
              imapClient: imapClient,
              subject: subject,
              encryptedMessage: encryptedMessage,
              syncConfig: syncConfig,
              file: encryptedFile,
            );
          }
        } else {
          res = await saveImapMessage(
            imapClient: imapClient,
            subject: subject,
            encryptedMessage: encryptedMessage,
            syncConfig: syncConfig,
          );
        }

        final resDetails = res?.details;
        loggingDb.captureEvent(
          resDetails ?? 'no result details',
          domain: 'OUTBOX_IMAP',
        );

        if (resDetails != null && resDetails.contains('completed')) {
          return true;
        } else {
          await imapClient.disconnect();
          return false;
        }
      } catch (exception, stackTrace) {
        loggingDb.captureException(
          exception,
          domain: 'OUTBOX_IMAP persistImap',
          stackTrace: stackTrace,
        );
        rethrow;
      }
    },
    syncConfig: syncConfig,
    allowInvalidCert: allowInvalidCert,
  );
}
