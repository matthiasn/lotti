import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';

class ImapClientManager {
  ImapClientManager();

  ImapClient? _imapClient;
  DateTime clientStarted = DateTime.now();

  Future<ImapClient> _createImapClient(
    SyncConfig? syncConfig, {
    bool reuseClient = true,
    Duration connectionTimeout = const Duration(minutes: 5),
    Duration responseTimeout = const Duration(minutes: 15),
    Duration writeTimeout = const Duration(minutes: 15),
    required bool allowInvalidCert,
  }) async {
    final clientId = uuid.v1();
    final loggingDb = getIt<LoggingDb>();

    if (reuseClient && _imapClient != null) {
      final client = _imapClient!;
      final connected = client.isConnected && client.isLoggedIn;
      if (connected) {
        await client.check();
        return client;
      }
    }

    try {
      if (syncConfig != null) {
        final imapClient = allowInvalidCert
            ? ImapClient(
                onBadCertificate: (X509Certificate cert) => true,
                defaultResponseTimeout: responseTimeout,
                defaultWriteTimeout: writeTimeout,
              )
            : ImapClient(
                defaultResponseTimeout: responseTimeout,
                defaultWriteTimeout: writeTimeout,
              );

        final imapConfig = syncConfig.imapConfig;
        await imapClient.connectToServer(
          imapConfig.host,
          imapConfig.port,
          timeout: connectionTimeout,
        );

        loggingDb.captureEvent(
          'ImapClient created',
          domain: 'IMAP_CLIENT $clientId',
        );

        await imapClient.login(imapConfig.userName, imapConfig.password);

        debugPrint('ImapClient logged in');

        loggingDb.captureEvent(
          'ImapClient logged in',
          domain: 'IMAP_CLIENT $clientId',
        );

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

        await _imapClient?.disconnect();
        _imapClient = imapClient;
        return imapClient;
      } else {
        throw Exception('missing IMAP config');
      }
    } catch (e, stackTrace) {
      debugPrint('IMAP_CLIENT $clientId createImapClient: $e\n$stackTrace\n');

      loggingDb.captureException(
        e,
        domain: 'IMAP_CLIENT $clientId',
        subDomain: 'createImapClient',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<bool> imapAction(
    Future<bool> Function(ImapClient imapClient) callback, {
    required SyncConfig? syncConfig,
    bool allowInvalidCert = false,
  }) async {
    try {
      final client = await _createImapClient(
        syncConfig,
        allowInvalidCert: allowInvalidCert,
      );
      return await callback(client).timeout(const Duration(seconds: 30));
    } catch (_) {
      final client = await _createImapClient(
        syncConfig,
        allowInvalidCert: allowInvalidCert,
        reuseClient: false,
      );
      return callback(client);
    }
  }
}
