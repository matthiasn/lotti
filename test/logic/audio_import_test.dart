import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/audio_import.dart';
import 'package:lotti/logic/media/audio_metadata_extractor.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

class MockLoggingService extends Mock implements LoggingService {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockJournalDb extends Mock implements JournalDb {}

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
    registerFallbackValue(FakeJournalAudio());
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(DateTime.now());
  });

  setUp(() async {
    mockLoggingService = MockLoggingService();
    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();

    tempDir = await Directory.systemTemp.createTemp('audio_import_test_');

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

  Future<File> createTestAudioFile(String filename, int sizeBytes) async {
    final file = File(path.join(tempDir.path, filename));
    await file.create(recursive: true);
    if (sizeBytes > 1024 * 1024) {
      final raf = await file.open(mode: FileMode.write);
      try {
        await raf.setPosition(sizeBytes - 1);
        await raf.writeFrom(<int>[0]);
      } finally {
        await raf.close();
      }
      return file;
    }
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

  group('AudioImportConstants', () {
    test('defines supported extensions', () {
      expect(AudioImportConstants.supportedExtensions, contains('m4a'));
      expect(AudioImportConstants.supportedExtensions, hasLength(1));
    });

    test('defines reasonable file size limit', () {
      expect(
        AudioImportConstants.maxFileSizeBytes,
        equals(500 * 1024 * 1024),
      );
    });

    test('defines logging domain', () {
      expect(AudioImportConstants.loggingDomain, equals('audio_import'));
    });
  });

  group('importDroppedAudio', () {
    test('successfully imports valid M4A file', () async {
      final testFile = await createTestAudioFile('test.m4a', 1024 * 100);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      await importDroppedAudio(data: dropDetails);

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

    test('skips non-audio file silently', () async {
      final testFile = await createTestAudioFile('test.txt', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      await importDroppedAudio(data: dropDetails);

      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      );
    });

    test('logs error for file without extension', () async {
      final testFile = await createTestAudioFile('test', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      await importDroppedAudio(data: dropDetails);

      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('no extension')),
          domain: AudioImportConstants.loggingDomain,
          subDomain: 'importDroppedAudio',
        ),
      ).called(1);
    });

    test('logs error for file exceeding size limit', () async {
      const largeSize = AudioImportConstants.maxFileSizeBytes + 1;
      final testFile = await createTestAudioFile('large.m4a', largeSize);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      await importDroppedAudio(data: dropDetails);

      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: AudioImportConstants.loggingDomain,
          subDomain: 'importDroppedAudio',
        ),
      ).called(1);
    });

    test('passes linkedId and categoryId', () async {
      final testFile = await createTestAudioFile('test.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      await importDroppedAudio(
        data: dropDetails,
        linkedId: 'parent-123',
        categoryId: 'cat-456',
      );

      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: 'parent-123',
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(1);
    });

    test('parses timestamp from Lotti filename format', () async {
      final testFile =
          await createTestAudioFile('2025-10-20_16-49-32-203.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      await importDroppedAudio(data: dropDetails);

      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      final expectedTimestamp =
          DateTime.utc(2025, 10, 20, 16, 49, 32, 203).toLocal();
      expect(captured.data.dateFrom, equals(expectedTimestamp));
    });
  });
}
