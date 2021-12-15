import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<GenericImapResult> saveImapMessage(
  ImapClient imapClient,
  String subject,
  String encryptedMessage, {
  File? file,
}) async {
  try {
    final transaction = Sentry.startTransaction('saveImapMessage()', 'task');
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
    await transaction.finish();
    return res;
  } catch (exception, stackTrace) {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
