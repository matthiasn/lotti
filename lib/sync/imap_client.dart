import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';

Future<ImapClient?> createImapClient(SyncConfig? syncConfig) async {
  final loggingDb = getIt<LoggingDb>();
  final transaction = loggingDb.startTransaction('createImapClient()', 'task');

  try {
    if (syncConfig != null) {
      final imapConfig = syncConfig.imapConfig;
      final imapClient = ImapClient();

      await imapClient.connectToServer(
        imapConfig.host,
        imapConfig.port,
      );
      await imapClient.login(imapConfig.userName, imapConfig.password);

      // Create folder if it doesn't exist yet
      try {
        await imapClient.selectMailboxByPath(imapConfig.folder);
      } catch (ex) {
        debugPrint('Attempting to create folder ${imapConfig.folder}');
        final syncFolder = await imapClient.createMailbox(imapConfig.folder);
        loggingDb.captureEvent(
          'Folder created: $syncFolder',
          domain: 'IMAP_CLIENT',
        );
        await imapClient.selectMailboxByPath(imapConfig.folder);
      }

      imapClient.eventBus.on<ImapEvent>().listen((ImapEvent imapEvent) async {
        loggingDb.captureEvent(imapEvent, domain: 'IMAP_CLIENT');
      });

      return imapClient;
    } else {
      throw Exception('missing IMAP config');
    }
  } catch (e, stackTrace) {
    loggingDb.captureException(
      e,
      domain: 'IMAP_CLIENT',
      subDomain: 'createImapClient',
      stackTrace: stackTrace,
    );
  }
  await transaction.finish();
  return null;
}
