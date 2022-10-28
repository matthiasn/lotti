import 'dart:convert';
import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/sync/inbox/process_message.dart';
import 'package:lotti/sync/outbox/outbox_imap.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';
import '../../test_data/sync_config_test_data.dart';
import '../../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Process Message Tests', () {
    final mockJournalDb = MockJournalDb();

    setUp(() async {
      setFakeDocumentsPath();

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => true);

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<Future<DriftIsolate>>(
          createDriftIsolate(journalDbFileName, inMemory: true),
          instanceName: journalDbFileName,
        )
        ..registerSingleton<JournalDb>(getJournalDb())
        ..registerSingleton<Future<DriftIsolate>>(
          createDriftIsolate(loggingDbFileName, inMemory: true),
          instanceName: loggingDbFileName,
        )
        ..registerSingleton<LoggingDb>(getLoggingDb());

      await initConfigFlags(getIt<JournalDb>());
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('Process encrypted message, valid update is inserted', () async {
      final b64Secret = encrypt.Key.fromSecureRandom(32).base64;
      const testSubject = 'foo:123';

      final testSyncMsg = SyncMessage.journalEntity(
        journalEntity: testTextEntryWithTags,
        status: SyncEntryStatus.initial,
      );

      await processMessage(
        testSyncConfigConfigured.copyWith(sharedSecret: b64Secret),
        await createImapMessage(
          subject: testSubject,
          encryptedMessage: await encryptString(
            b64Secret: b64Secret,
            plainText: jsonEncode(testSyncMsg),
          ),
        ),
      );

      expect(
        await getIt<JournalDb>()
            .watchEntityById(testTextEntryWithTags.meta.id)
            .first,
        testTextEntryWithTags,
      );

      final updatedEntity = testTextEntryWithTags.copyWith(
        meta: testTextEntryWithTags.meta.copyWith(
          vectorClock: const VectorClock({'a': 12}),
        ),
      );

      final testSyncMsg2 = SyncMessage.journalEntity(
        journalEntity: updatedEntity,
        status: SyncEntryStatus.update,
      );

      await processMessage(
        testSyncConfigConfigured.copyWith(sharedSecret: b64Secret),
        await createImapMessage(
          subject: testSubject,
          encryptedMessage: await encryptString(
            b64Secret: b64Secret,
            plainText: jsonEncode(testSyncMsg2),
          ),
        ),
      );

      expect(
        await getIt<JournalDb>()
            .watchEntityById(testTextEntryWithTags.meta.id)
            .first,
        updatedEntity,
      );
    });

    test(
        'Process encrypted message, invalid update with concurrent vc is rejected',
        () async {
      final b64Secret = encrypt.Key.fromSecureRandom(32).base64;
      const testSubject = 'foo:123';

      final testSyncMsg = SyncMessage.journalEntity(
        journalEntity: testTextEntryWithTags,
        status: SyncEntryStatus.initial,
      );

      await processMessage(
        testSyncConfigConfigured.copyWith(sharedSecret: b64Secret),
        await createImapMessage(
          subject: testSubject,
          encryptedMessage: await encryptString(
            b64Secret: b64Secret,
            plainText: jsonEncode(testSyncMsg),
          ),
        ),
      );

      expect(
        await getIt<JournalDb>()
            .watchEntityById(testTextEntryWithTags.meta.id)
            .first,
        testTextEntryWithTags,
      );

      final updatedEntity = testTextEntryWithTags.copyWith(
        meta: testTextEntryWithTags.meta.copyWith(
          vectorClock: const VectorClock({'a': 2}),
        ),
      );

      final testSyncMsg2 = SyncMessage.journalEntity(
        journalEntity: updatedEntity,
        status: SyncEntryStatus.update,
      );

      await processMessage(
        testSyncConfigConfigured.copyWith(sharedSecret: b64Secret),
        await createImapMessage(
          subject: testSubject,
          encryptedMessage: await encryptString(
            b64Secret: b64Secret,
            plainText: jsonEncode(testSyncMsg2),
          ),
        ),
      );

      expect(
        await getIt<JournalDb>()
            .watchEntityById(testTextEntryWithTags.meta.id)
            .first,
        testTextEntryWithTags,
      );
    });
  });
}
