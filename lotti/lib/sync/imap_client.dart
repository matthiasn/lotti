import 'package:enough_mail/enough_mail.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';

Future<ImapClient?> createImapClient() async {
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  SyncConfig? syncConfig = await _syncConfigService.getSyncConfig();
  final transaction = _loggingDb.startTransaction('createImapClient()', 'task');

  try {
    if (syncConfig != null) {
      ImapConfig imapConfig = syncConfig.imapConfig;
      ImapClient imapClient = ImapClient(isLogEnabled: false);

      await imapClient.connectToServer(
        imapConfig.host,
        imapConfig.port,
        isSecure: true,
      );
      await imapClient.login(imapConfig.userName, imapConfig.password);
      await imapClient.selectInbox();

      imapClient.eventBus.on<ImapEvent>().listen((ImapEvent imapEvent) async {
        _loggingDb.captureEvent(imapEvent, domain: 'IMAP_CLIENT');
      });

      return imapClient;
    } else {
      throw Exception('missing IMAP config');
    }
  } catch (e, stackTrace) {
    await _loggingDb.captureException(
      e,
      domain: 'IMAP_CLIENT',
      subDomain: 'createImapClient',
      stackTrace: stackTrace,
    );
  }
  await transaction.finish();
  return null;
}
