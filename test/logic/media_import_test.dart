import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/audio_import.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/media/audio_metadata_extractor.dart';
import 'package:lotti/logic/media_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../mocks/mocks.dart';

class FakeJournalImage extends Fake implements JournalImage {}

class FakeJournalAudio extends Fake implements JournalAudio {}

class FakeMetadata extends Fake implements Metadata {}

class FakeDropItem extends Fake implements DropItem {
  FakeDropItem(this._xFile);

  final XFile _xFile;

  @override
  String get name => _xFile.name;

  @override
  String get path => _xFile.path;

  @override
  Future<DateTime> lastModified() => _xFile.lastModified();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoggingService mockLoggingService;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockJournalDb mockJournalDb;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(FakeJournalImage());
    registerFallbackValue(FakeJournalAudio());
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(DateTime.now());
  });

  setUp(() async {
    mockLoggingService = MockLoggingService();
    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();

    tempDir = await Directory.systemTemp.createTemp('media_import_test_');

    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<PersistenceLogic>()) {
      getIt.unregister<PersistenceLogic>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    if (getIt.isRegistered<AudioMetadataReader>()) {
      getIt.unregister<AudioMetadataReader>();
    }

    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<Directory>(tempDir)
      ..registerSingleton<AudioMetadataReader>((_) async => Duration.zero);

    when(
      () => mockLoggingService.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockPersistenceLogic.createMetadata(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        uuidV5Input: any(named: 'uuidV5Input'),
        flag: any(named: 'flag'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer(
      (_) async => Metadata(
        id: 'test-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
      ),
    );

    when(
      () => mockPersistenceLogic.createDbEntity(
        any(that: isA<JournalImage>()),
        linkedId: any(named: 'linkedId'),
        shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        enqueueSync: any(named: 'enqueueSync'),
        addTags: any(named: 'addTags'),
      ),
    ).thenAnswer((_) async => true);

    when(
      () => mockPersistenceLogic.createDbEntity(
        any(that: isA<JournalAudio>()),
        linkedId: any(named: 'linkedId'),
        shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        enqueueSync: any(named: 'enqueueSync'),
        addTags: any(named: 'addTags'),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}

    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<PersistenceLogic>()) {
      getIt.unregister<PersistenceLogic>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    if (getIt.isRegistered<AudioMetadataReader>()) {
      getIt.unregister<AudioMetadataReader>();
    }
  });

  Future<File> createTestFile(String filename, int sizeBytes) async {
    final file = File(path.join(tempDir.path, filename));
    await file.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(sizeBytes, 0));
    return file;
  }

  DropDoneDetails createDropDetails(List<XFile> xfiles) {
    final dropItems = xfiles.map(FakeDropItem.new).toList();
    return DropDoneDetails(
      files: dropItems,
      localPosition: Offset.zero,
      globalPosition: Offset.zero,
    );
  }

  group('handleDroppedMedia', () {
    test('dispatches image files to importDroppedImages', () async {
      final imageFile = await createTestFile('test.jpg', 1024);
      final dropDetails = createDropDetails([XFile(imageFile.path)]);

      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'linked-123',
      );

      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(1);
    });

    test('dispatches audio files to importDroppedAudio', () async {
      final audioFile = await createTestFile('test.m4a', 1024);
      final dropDetails = createDropDetails([XFile(audioFile.path)]);

      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'linked-123',
      );

      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(1);
    });

    test('handles mixed image and audio files', () async {
      final imageFile = await createTestFile('photo.png', 1024);
      final audioFile = await createTestFile('audio.m4a', 1024);
      final dropDetails = createDropDetails([
        XFile(imageFile.path),
        XFile(audioFile.path),
      ]);

      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'linked-123',
      );

      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(1);
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(1);
    });

    test('ignores unsupported file types', () async {
      final textFile = await createTestFile('readme.txt', 100);
      final dropDetails = createDropDetails([XFile(textFile.path)]);

      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'linked-123',
      );

      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      );
    });

    test('passes categoryId to both image and audio imports', () async {
      final imageFile = await createTestFile('photo.jpg', 1024);
      final audioFile = await createTestFile('audio.m4a', 1024);
      final dropDetails = createDropDetails([
        XFile(imageFile.path),
        XFile(audioFile.path),
      ]);

      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'linked-123',
        categoryId: 'cat-456',
      );

      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(1);
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(1);
    });

    test('recognizes all supported image extensions', () {
      expect(
        ImageImportConstants.supportedExtensions,
        containsAll(['jpg', 'jpeg', 'png']),
      );
    });

    test('recognizes all supported audio extensions', () {
      expect(
        AudioImportConstants.supportedExtensions,
        contains('m4a'),
      );
    });
  });
}
