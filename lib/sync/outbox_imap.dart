import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/sync/imap_client.dart';

Future<GenericImapResult> saveImapMessage(
  ImapClient imapClient,
  String subject,
  String encryptedMessage, {
  File? file,
}) async {
  final LoggingDb loggingDb = getIt<LoggingDb>();
  final SyncConfigService syncConfigService = getIt<SyncConfigService>();
  final SyncConfig? syncConfig = await syncConfigService.getSyncConfig();

  try {
    final transaction = loggingDb.startTransaction('saveImapMessage()', 'task');

    Mailbox inbox = await imapClient
        .selectMailboxByPath(syncConfig?.imapConfig.folder ?? 'INBOX');

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
    GenericImapResult res = await imapClient.appendMessage(
      message,
      targetMailbox: inbox,
      flags: ['\\Seen'],
    );
    debugPrint(
        'saveImapMessage responseCode ${res.responseCode} details ${res.details}');
    await transaction.finish();
    return res;
  } catch (exception, stackTrace) {
    await loggingDb.captureException(
      exception,
      domain: 'OUTBOX_IMAP',
      subDomain: 'saveImapMessage',
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

const String sharedSecretKey = 'sharedSecret';
const String imapConfigKey = 'imapConfig';
const String lastReadUidKey = 'lastReadUid';
final LoggingDb _loggingDb = getIt<LoggingDb>();

Future<ImapClient?> persistImap({
  required String encryptedMessage,
  required String subject,
  String? encryptedFilePath,
  ImapClient? prevImapClient,
}) async {
  ImapClient? imapClient;
  try {
    final transaction = _loggingDb.startTransaction('saveImap()', 'task');
    if (prevImapClient != null) {
      imapClient = prevImapClient;
    } else {
      final SyncConfigService syncConfigService = getIt<SyncConfigService>();
      SyncConfig? syncConfig = await syncConfigService.getSyncConfig();
      imapClient = await createImapClient(syncConfig);
    }

    GenericImapResult? res;
    if (imapClient != null) {
      if (encryptedFilePath != null && encryptedFilePath.isNotEmpty) {
        File encryptedFile = File(encryptedFilePath);
        int fileLength = encryptedFile.lengthSync();
        if (fileLength > 0) {
          res = await saveImapMessage(
            imapClient,
            subject,
            encryptedMessage,
            file: encryptedFile,
          );
        }
      } else {
        res = await saveImapMessage(
          imapClient,
          subject,
          encryptedMessage,
        );
      }
    }
    await transaction.finish();

    String? resDetails = res?.details;
    _loggingDb.captureEvent(
      resDetails ?? 'no result details',
      domain: 'OUTBOX_IMAP',
    );

    if (resDetails != null && resDetails.contains('completed')) {
      return imapClient;
    } else {
      await imapClient?.disconnect();
      return null;
    }
  } catch (exception, stackTrace) {
    await _loggingDb.captureException(
      exception,
      domain: 'OUTBOX_IMAP persistImap',
      stackTrace: stackTrace,
    );
    rethrow;
  } finally {}
}
