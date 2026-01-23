import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

class MockLoggingService extends Mock implements LoggingService {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockJournalDb extends Mock implements JournalDb {}

class FakeJournalImage extends Fake implements JournalImage {}

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
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(DateTime.now());
  });

  setUp(() async {
    mockLoggingService = MockLoggingService();
    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();

    tempDir = await Directory.systemTemp.createTemp('image_import_test_');

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

    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<Directory>(tempDir);

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
  });

  Future<File> createTestImageFile(String filename, int sizeBytes) async {
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

  group('ImageImportConstants', () {
    test('defines supported extensions', () {
      expect(
        ImageImportConstants.supportedExtensions,
        containsAll(['jpg', 'jpeg', 'png']),
      );
      expect(ImageImportConstants.supportedExtensions, hasLength(3));
    });

    test('defines reasonable file size limit', () {
      expect(
        ImageImportConstants.maxFileSizeBytes,
        equals(50 * 1024 * 1024),
      );
    });

    test('defines directory prefix', () {
      expect(ImageImportConstants.directoryPrefix, equals('/images/'));
    });

    test('defines logging domain', () {
      expect(ImageImportConstants.loggingDomain, equals('image_import'));
    });
  });

  group('importPastedImages', () {
    test('rejects images exceeding size limit', () async {
      final oversizedData = Uint8List(
        ImageImportConstants.maxFileSizeBytes + 1,
      );

      await importPastedImages(
        data: oversizedData,
        fileExtension: 'png',
        linkedId: 'test-id',
        categoryId: 'category-id',
      );

      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: ImageImportConstants.loggingDomain,
          subDomain: 'importPastedImages',
        ),
      ).called(1);
    });

    test('accepts images within size limit', () async {
      final validData = Uint8List(1000);

      try {
        await importPastedImages(
          data: validData,
          fileExtension: 'png',
          linkedId: 'test-id',
          categoryId: 'category-id',
        );
      } catch (e) {
        // Expected to fail due to missing file system setup
      }

      verifyNever(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: ImageImportConstants.loggingDomain,
          subDomain: 'importPastedImages',
        ),
      );
    });
  });

  group('importDroppedImages', () {
    test('successfully imports valid JPG file', () async {
      final testFile = await createTestImageFile('test.jpg', 1024);
      final dropDetails = createDropDetails([XFile(testFile.path)]);

      await importDroppedImages(data: dropDetails);

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

    test('successfully imports valid PNG file', () async {
      final testFile = await createTestImageFile('test.png', 1024);
      final dropDetails = createDropDetails([XFile(testFile.path)]);

      await importDroppedImages(data: dropDetails);

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

    test('skips non-image file silently', () async {
      final testFile = await createTestImageFile('test.txt', 1024);
      final dropDetails = createDropDetails([XFile(testFile.path)]);

      await importDroppedImages(data: dropDetails);

      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      );
    });

    test('logs error for file exceeding size limit', () async {
      const largeSize = ImageImportConstants.maxFileSizeBytes + 1;
      final testFile = await createTestImageFile('large.jpg', largeSize);
      final dropDetails = createDropDetails([XFile(testFile.path)]);

      await importDroppedImages(data: dropDetails);

      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: ImageImportConstants.loggingDomain,
          subDomain: 'importDroppedImages',
        ),
      ).called(1);
    });

    test('passes linkedId and categoryId', () async {
      final testFile = await createTestImageFile('test.jpg', 1024);
      final dropDetails = createDropDetails([XFile(testFile.path)]);

      await importDroppedImages(
        data: dropDetails,
        linkedId: 'parent-123',
        categoryId: 'cat-456',
      );

      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: 'parent-123',
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(1);
    });

    test('imports multiple files', () async {
      final file1 = await createTestImageFile('photo1.jpg', 1024);
      final file2 = await createTestImageFile('photo2.png', 2048);
      final dropDetails = createDropDetails([
        XFile(file1.path),
        XFile(file2.path),
      ]);

      await importDroppedImages(data: dropDetails);

      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(2);
    });
  });

  group('importGeneratedImageBytes', () {
    test('rejects images exceeding size limit', () async {
      final oversizedData = Uint8List(
        ImageImportConstants.maxFileSizeBytes + 1,
      );

      final result = await importGeneratedImageBytes(
        data: oversizedData,
        fileExtension: 'png',
        linkedId: 'test-id',
      );

      expect(result, isNull);
      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: ImageImportConstants.loggingDomain,
          subDomain: 'importGeneratedImageBytes',
        ),
      ).called(1);
    });
  });

  group('parseRational', () {
    test('parses fraction format', () {
      expect(parseRational('37/1'), equals(37.0));
      expect(parseRational('122/1'), equals(122.0));
    });

    test('parses decimal format', () {
      expect(parseRational('37.7749'), closeTo(37.7749, 0.0001));
    });

    test('returns null for invalid input', () {
      expect(parseRational('invalid'), isNull);
      expect(parseRational(''), isNull);
    });

    test('handles division by zero', () {
      expect(parseRational('37/0'), isNull);
    });
  });

  group('parseGpsCoordinate', () {
    test('returns null for null data', () {
      expect(parseGpsCoordinate(null, 'N'), isNull);
    });

    test('returns null for invalid coordinate format', () {
      // Only 2 parts instead of 3 (degrees, minutes, seconds)
      expect(parseGpsCoordinate('[37, 0]', 'N'), isNull);
    });
  });

  group('extractGpsCoordinates', () {
    test('returns null for empty data', () async {
      final result = await extractGpsCoordinates(
        Uint8List(0),
        DateTime.now(),
      );
      expect(result, isNull);
    });

    test('returns null for non-image data', () async {
      final result = await extractGpsCoordinates(
        Uint8List.fromList([0, 1, 2, 3, 4]),
        DateTime.now(),
      );
      expect(result, isNull);
    });
  });
}
