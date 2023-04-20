import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/sync/inbox/process_message.dart';
import 'package:lotti/sync/outbox/outbox_imap.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
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
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true));

      await initConfigFlags(getIt<JournalDb>(), inMemoryDatabase: true);
    });

    tearDown(() async {
      await getIt<JournalDb>().close();
      await getIt<LoggingDb>().close();
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

    test(
        'Process encrypted message with audio attachment, '
        'check identical files', () async {
      final b64Secret = encrypt.Key.fromSecureRandom(32).base64;
      const testSubject = 'foo:123';
      final dt = DateTime.fromMillisecondsSinceEpoch(1638265606966);

      final testMeta = Metadata(
        createdAt: dt,
        id: 'test-id',
        dateTo: dt,
        dateFrom: dt,
        updatedAt: dt,
        vectorClock: const VectorClock({'foobar': 1}),
      );

      final audioEntry = JournalAudio(
        meta: testMeta,
        data: AudioData(
          audioDirectory: '/audio/2021-11-29/',
          dateFrom: dt,
          dateTo: dt,
          duration: const Duration(seconds: 1),
          audioFile: '2021-11-29_20-35-12-957.aac',
        ),
      );

      final testSyncMsg = SyncMessage.journalEntity(
        journalEntity: audioEntry,
        status: SyncEntryStatus.initial,
      );

      final audioFile = File('test_resources/test.aac');
      final encryptedFile = File('${audioFile.path}.aes');

      await encryptFile(audioFile, encryptedFile, b64Secret);

      final mimeMessage = await createImapMessage(
        subject: testSubject,
        encryptedMessage: await encryptString(
          b64Secret: b64Secret,
          plainText: jsonEncode(testSyncMsg),
        ),
        file: encryptedFile,
      );

      await processMessage(
        testSyncConfigConfigured.copyWith(sharedSecret: b64Secret),
        mimeMessage,
      );

      expect(
        await getIt<JournalDb>().watchEntityById(audioEntry.meta.id).first,
        audioEntry,
      );

      expect(
        File(await AudioUtils.getFullAudioPath(audioEntry)).readAsBytesSync(),
        audioFile.readAsBytesSync(),
      );
    });

    test(
        'Process encrypted message with image attachment, '
        'check identical files', () async {
      final b64Secret = encrypt.Key.fromSecureRandom(32).base64;
      const testSubject = 'foo:123';
      final dt = DateTime.fromMillisecondsSinceEpoch(1638265606966);

      final testMeta = Metadata(
        createdAt: dt,
        id: 'test-id2',
        dateTo: dt,
        dateFrom: dt,
        updatedAt: dt,
        vectorClock: const VectorClock({'foobar': 1}),
      );

      final imageEntry = JournalImage(
        meta: testMeta,
        data: ImageData(
          imageId: 'foo',
          imageFile: 'test.png',
          imageDirectory: '/images/2022-10-29/',
          capturedAt: DateTime.now(),
        ),
      );

      final testSyncMsg = SyncMessage.journalEntity(
        journalEntity: imageEntry,
        status: SyncEntryStatus.initial,
      );

      final imageFile = File('test_resources/test.png');
      final encryptedFile = File('${imageFile.path}.aes');

      await encryptFile(imageFile, encryptedFile, b64Secret);

      final mimeMessage = await createImapMessage(
        subject: testSubject,
        encryptedMessage: await encryptString(
          b64Secret: b64Secret,
          plainText: jsonEncode(testSyncMsg),
        ),
        file: encryptedFile,
      );

      await processMessage(
        testSyncConfigConfigured.copyWith(sharedSecret: b64Secret),
        mimeMessage,
      );

      expect(
        await getIt<JournalDb>().watchEntityById(imageEntry.meta.id).first,
        imageEntry,
      );

      expect(
        File(getFullImagePath(imageEntry)).readAsBytesSync(),
        imageFile.readAsBytesSync(),
      );
    });
  });
}
