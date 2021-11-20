import 'package:enough_mail/enough_mail.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wisely/blocs/sync/config_classes.dart';
import 'package:wisely/blocs/sync/encryption_cubit.dart';

Future<ImapClient?> createImapClient(EncryptionCubit encryptionCubit) async {
  SyncConfig? syncConfig = await encryptionCubit.loadSyncConfig();
  final transaction = Sentry.startTransaction('createImapClient()', 'task');

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
        await Sentry.captureEvent(
            SentryEvent(message: SentryMessage(imapEvent.toString())),
            withScope: (Scope scope) => scope.level = SentryLevel.info);
      });

      return imapClient;
    } else {
      throw Exception('missing IMAP config');
    }
  } catch (e, stackTrace) {
    await Sentry.captureException(e, stackTrace: stackTrace);
  }
  await transaction.finish();
}
