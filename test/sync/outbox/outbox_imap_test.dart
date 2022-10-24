import 'dart:convert';
import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/sync/inbox/process_message.dart';
import 'package:lotti/sync/outbox/outbox_imap.dart';
import 'package:path_provider/path_provider.dart';

import '../../helpers/path_provider.dart';
import '../../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setFakeDocumentsPath();

  group('Outbox IMAP Tests', () {
    setUpAll(() async {
      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<Future<DriftIsolate>>(
          createDriftIsolate(loggingDbFileName, inMemory: true),
          instanceName: loggingDbFileName,
        )
        ..registerSingleton<LoggingDb>(getLoggingDb());
    });

    test('', () async {
      final b64Secret = encrypt.Key.fromSecureRandom(32).base64;
      const testSubject = 'foo:123';

      final testSyncMsg = SyncMessage.journalEntity(
        journalEntity: testTextEntryWithTags,
        status: SyncEntryStatus.initial,
      );

      final encryptedMessage = await encryptString(
        b64Secret: b64Secret,
        plainText: jsonEncode(testSyncMsg),
      );

      final mimeMessage = await createImapMessage(
        subject: testSubject,
        encryptedMessage: encryptedMessage,
      );

      final decodedMessage = await decodeMessage(mimeMessage, b64Secret);
      expect(decodedMessage, testSyncMsg);
    });
  });
}
