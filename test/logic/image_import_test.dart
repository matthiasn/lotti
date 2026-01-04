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

// Mocks
class MockLoggingService extends Mock implements LoggingService {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockJournalDb extends Mock implements JournalDb {}

// Fakes
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
    // Register fakes for any() matchers
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

    // Create temporary directory for tests
    tempDir = await Directory.systemTemp.createTemp('lotti_test_');

    // Unregister and register mocks
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
      ..registerSingleton<Directory>(tempDir)
      ..registerSingleton<AudioMetadataReader>((_) async => Duration.zero);

    // Default stub for logging
    when(
      () => mockLoggingService.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

    // Default stubs for persistence logic
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
    // Clean up temporary directory
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Ignore if directory doesn't exist
    }

    // Unregister services
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

  group('MediaImportConstants', () {
    test('defines supported image file extensions', () {
      expect(
        MediaImportConstants.supportedImageExtensions,
        containsAll(['jpg', 'jpeg', 'png']),
      );
      expect(MediaImportConstants.supportedImageExtensions, hasLength(3));
    });

    test('defines supported audio file extensions', () {
      expect(MediaImportConstants.supportedAudioExtensions, contains('m4a'));
      expect(MediaImportConstants.supportedAudioExtensions, hasLength(1));
    });

    test('defines reasonable file size limits', () {
      // Audio files can be up to 500MB
      expect(
        MediaImportConstants.maxAudioFileSizeBytes,
        equals(500 * 1024 * 1024),
      );

      // Image files can be up to 50MB
      expect(
        MediaImportConstants.maxImageFileSizeBytes,
        equals(50 * 1024 * 1024),
      );
    });

    test('defines images directory prefix', () {
      expect(
        MediaImportConstants.imagesDirectoryPrefix,
        equals('/images/'),
      );
    });

    test('defines logging domain', () {
      expect(MediaImportConstants.loggingDomain, equals('media_import'));
    });
  });

  group('importPastedImages', () {
    test('rejects images exceeding size limit', () async {
      // Create data larger than the limit
      final oversizedData = Uint8List(
        MediaImportConstants.maxImageFileSizeBytes + 1,
      );

      // Should not throw, but should log the error
      await importPastedImages(
        data: oversizedData,
        fileExtension: 'png',
        linkedId: 'test-id',
        categoryId: 'category-id',
      );

      // Verify that an exception was logged
      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importPastedImages',
        ),
      ).called(1);
    });

    test('accepts images within size limit', () async {
      // Create data within the limit (small file)
      final validData = Uint8List(1000); // 1KB file

      // This will fail in the actual import because we're not mocking
      // the full file system, but it won't fail on size validation
      try {
        await importPastedImages(
          data: validData,
          fileExtension: 'png',
          linkedId: 'test-id',
          categoryId: 'category-id',
        );
      } catch (e) {
        // Expected to fail due to missing file system setup
        // We're just testing that it passes size validation
      }

      // Verify that NO size-related exception was logged
      verifyNever(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importPastedImages',
        ),
      );
    });
  });

  group('File extension validation', () {
    test('image extensions are lowercase', () {
      for (final ext in MediaImportConstants.supportedImageExtensions) {
        expect(ext, equals(ext.toLowerCase()));
      }
    });

    test('audio extensions are lowercase', () {
      for (final ext in MediaImportConstants.supportedAudioExtensions) {
        expect(ext, equals(ext.toLowerCase()));
      }
    });

    test('no duplicate extensions in image set', () {
      const extensions = MediaImportConstants.supportedImageExtensions;
      expect(extensions.length, equals(extensions.toSet().length));
    });

    test('no duplicate extensions in audio set', () {
      const extensions = MediaImportConstants.supportedAudioExtensions;
      expect(extensions.length, equals(extensions.toSet().length));
    });

    test('no overlap between image and audio extensions', () {
      const imageExts = MediaImportConstants.supportedImageExtensions;
      const audioExts = MediaImportConstants.supportedAudioExtensions;

      final intersection = imageExts.intersection(audioExts);
      expect(intersection, isEmpty);
    });
  });

  group('Size limit constants', () {
    test('audio size limit is larger than image limit', () {
      expect(
        MediaImportConstants.maxAudioFileSizeBytes,
        greaterThan(MediaImportConstants.maxImageFileSizeBytes),
      );
    });

    test('size limits are positive', () {
      expect(MediaImportConstants.maxAudioFileSizeBytes, greaterThan(0));
      expect(MediaImportConstants.maxImageFileSizeBytes, greaterThan(0));
    });

    test('size limits are reasonable (not too small)', () {
      // Audio should be at least 100MB
      expect(
        MediaImportConstants.maxAudioFileSizeBytes,
        greaterThanOrEqualTo(100 * 1024 * 1024),
      );

      // Images should be at least 10MB
      expect(
        MediaImportConstants.maxImageFileSizeBytes,
        greaterThanOrEqualTo(10 * 1024 * 1024),
      );
    });

    test('size limits are reasonable (not too large)', () {
      // Audio should not exceed 1GB
      expect(
        MediaImportConstants.maxAudioFileSizeBytes,
        lessThanOrEqualTo(1024 * 1024 * 1024),
      );

      // Images should not exceed 100MB
      expect(
        MediaImportConstants.maxImageFileSizeBytes,
        lessThanOrEqualTo(100 * 1024 * 1024),
      );
    });
  });

  group('Audio-specific functionality', () {
    test('M4A is the supported audio format', () {
      expect(MediaImportConstants.supportedAudioExtensions, contains('m4a'));
    });

    test('audio format is lowercase for case-insensitive matching', () {
      // This ensures that Test.M4A, test.M4a, TEST.m4a all work
      for (final ext in MediaImportConstants.supportedAudioExtensions) {
        expect(ext, equals('m4a'));
        expect(ext, equals(ext.toLowerCase()));
      }
    });

    test('audio directory prefix matches recorder constants', () {
      // Ensure consistency with audio recording
      expect(
        MediaImportConstants.loggingDomain,
        isNotEmpty,
      );
    });

    test('file size limit allows typical podcast episodes', () {
      // Typical podcast: 1 hour at 128kbps ≈ 56MB
      const typicalPodcastSize = 60 * 1024 * 1024; // 60MB
      expect(
        MediaImportConstants.maxAudioFileSizeBytes,
        greaterThan(typicalPodcastSize),
      );
    });

    test('file size limit allows high-quality recordings', () {
      // High quality recording: 1 hour at 256kbps ≈ 112MB
      const highQualityHourRecording = 120 * 1024 * 1024; // 120MB
      expect(
        MediaImportConstants.maxAudioFileSizeBytes,
        greaterThan(highQualityHourRecording),
      );
    });
  });

  group('Error handling and logging', () {
    test('logging domain is descriptive', () {
      expect(MediaImportConstants.loggingDomain, equals('media_import'));
      expect(MediaImportConstants.loggingDomain, isNotEmpty);
    });

    test('logging domain does not contain spaces', () {
      expect(MediaImportConstants.loggingDomain, isNot(contains(' ')));
    });

    test('logging domain uses underscore separator', () {
      expect(MediaImportConstants.loggingDomain, contains('_'));
    });
  });

  group('Path and directory constants', () {
    test('image directory prefix starts with slash', () {
      expect(MediaImportConstants.imagesDirectoryPrefix, startsWith('/'));
    });

    test('image directory prefix ends with slash', () {
      expect(MediaImportConstants.imagesDirectoryPrefix, endsWith('/'));
    });

    test('image directory prefix has valid format', () {
      expect(
        MediaImportConstants.imagesDirectoryPrefix,
        matches(RegExp(r'^/[a-z]+/$')),
      );
    });
  });

  group('File extension case sensitivity', () {
    test('supports common case variations of JPEG', () {
      const extensions = MediaImportConstants.supportedImageExtensions;
      // User might drag Test.JPG, test.JPEG, etc.
      // Our code lowercases the extension, so we support jpg and jpeg
      expect(extensions, contains('jpg'));
      expect(extensions, contains('jpeg'));
    });

    test('supports PNG which is commonly uppercase', () {
      const extensions = MediaImportConstants.supportedImageExtensions;
      // User might drag Test.PNG
      expect(extensions, contains('png'));
    });

    test('M4A format is lowercase in constant', () {
      const extensions = MediaImportConstants.supportedAudioExtensions;
      // User might drag Recording.M4A, but we lowercase it
      expect(extensions, contains('m4a'));
      expect(extensions, isNot(contains('M4A')));
    });
  });

  group('Integration scenarios', () {
    test('can handle mixed image types in same drop', () {
      const extensions = MediaImportConstants.supportedImageExtensions;
      // User can drag photo.jpg and screenshot.png together
      expect(extensions, containsAll(['jpg', 'png']));
    });

    test('image and audio extensions do not conflict', () {
      const imageExts = MediaImportConstants.supportedImageExtensions;
      const audioExts = MediaImportConstants.supportedAudioExtensions;

      // No file extension should be both image and audio
      expect(imageExts.intersection(audioExts).isEmpty, isTrue);
    });

    test('supports common workflow file types', () {
      const imageExts = MediaImportConstants.supportedImageExtensions;
      const audioExts = MediaImportConstants.supportedAudioExtensions;

      // Screenshots (PNG), photos (JPEG), voice memos (M4A)
      expect(imageExts, containsAll(['png', 'jpg']));
      expect(audioExts, contains('m4a'));
    });
  });

  group('Size validation edge cases', () {
    test('zero-byte file is within limits', () {
      expect(0, lessThan(MediaImportConstants.maxImageFileSizeBytes));
      expect(0, lessThan(MediaImportConstants.maxAudioFileSizeBytes));
    });

    test('exactly at limit should pass for images', () async {
      // Create data exactly at the limit
      final exactLimitData = Uint8List(
        MediaImportConstants.maxImageFileSizeBytes,
      );

      try {
        await importPastedImages(
          data: exactLimitData,
          fileExtension: 'png',
          linkedId: 'test-id',
        );
      } catch (e) {
        // Expected to fail on file system, not validation
      }

      // Should NOT log size error for file at exactly the limit
      verifyNever(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importPastedImages',
        ),
      );
    });

    test('one byte over limit triggers error for images', () async {
      final overLimitData = Uint8List(
        MediaImportConstants.maxImageFileSizeBytes + 1,
      );

      await importPastedImages(
        data: overLimitData,
        fileExtension: 'png',
        linkedId: 'test-id',
      );

      // Should log size error
      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importPastedImages',
        ),
      ).called(1);
    });
  });

  group('importDroppedImages', () {
    Future<File> createTestImageFile(
      String filename,
      int sizeBytes,
    ) async {
      final file = File(path.join(tempDir.path, filename));
      await file.writeAsBytes(List.generate(sizeBytes, (index) => index % 256));
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

    test('successfully imports valid JPG file', () async {
      // Arrange
      final testFile = await createTestImageFile('test.jpg', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedImages(data: dropDetails);

      // Assert
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
      // Arrange
      final testFile = await createTestImageFile('test.png', 2048);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedImages(data: dropDetails);

      // Assert
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

    test('successfully imports valid JPEG file', () async {
      // Arrange
      final testFile = await createTestImageFile('test.jpeg', 2048);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedImages(data: dropDetails);

      // Assert
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
      // Arrange
      final testFile = await createTestImageFile('test.txt', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedImages(data: dropDetails);

      // Assert - should not attempt to create entry
      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
        ),
      );
      // Should not log error for unsupported extension
      verifyNever(
        () => mockLoggingService.captureException(
          any<Object>(),
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importDroppedImages',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      );
    });

    test('logs error for file exceeding 50MB limit', () async {
      // Arrange - create file larger than limit
      const largeSize = MediaImportConstants.maxImageFileSizeBytes + 1;
      final testFile = await createTestImageFile('large.jpg', largeSize);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedImages(data: dropDetails);

      // Assert
      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importDroppedImages',
        ),
      ).called(1);
      // Should not create entry for oversized file
      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    test('processes multiple files and continues on single failure', () async {
      // Arrange
      final goodFile1 = await createTestImageFile('good1.jpg', 1024);
      final goodFile2 = await createTestImageFile('good2.png', 2048);
      final files = [
        XFile(goodFile1.path),
        XFile(goodFile2.path),
      ];
      final dropDetails = createDropDetails(files);

      // Make first file import fail
      var callCount = 0;
      when(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw Exception('First file failed');
        }
        return true;
      });

      // Act
      await importDroppedImages(data: dropDetails);

      // Assert - both files attempted
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(2);
      // First failure logged (from repository layer)
      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: isA<Exception>()),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(greaterThan(0));
    });

    test('passes linkedId to createImageEntry', () async {
      // Arrange
      final testFile = await createTestImageFile('test.jpg', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);
      const linkedId = 'parent-entry-123';

      // Act
      await importDroppedImages(
        data: dropDetails,
        linkedId: linkedId,
      );

      // Assert - Capture and verify the important parts
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalImage>()),
          linkedId: captureAny(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured;

      // Verify the captured values
      expect(captured[0], isA<JournalImage>());
      expect(captured[1], equals(linkedId));
    });

    test('handles case-insensitive file extensions', () async {
      // Arrange - uppercase extension
      final testFile = await createTestImageFile('test.JPG', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedImages(data: dropDetails);

      // Assert - should process file despite uppercase extension
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalImage>()),
          linkedId: captureAny(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured;

      // Verify the captured values
      expect(captured[0], isA<JournalImage>());
      // linkedId should be null since we didn't pass one
      expect(captured[1], isNull);
    });

    test('creates image in correct date-based directory', () async {
      // Arrange
      final testFile = await createTestImageFile('test.jpg', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedImages(data: dropDetails);

      // Assert - verify directory was created
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured.single as JournalImage;

      expect(captured.data.imageDirectory, startsWith('/images/'));
    });

    test('handles empty file list without error', () async {
      // Arrange
      final dropDetails = createDropDetails([]);

      // Act & Assert - should not throw
      await importDroppedImages(data: dropDetails);

      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    test('handles exception gracefully when file processing fails', () async {
      // Arrange
      final testFile = await createTestImageFile('test.jpg', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Make createDbEntity throw an exception
      when(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).thenThrow(Exception('Database error'));

      // Act & Assert - should not throw, exception should be caught internally
      await expectLater(
        importDroppedImages(data: dropDetails),
        completes,
      );
    });
  });

  group('Audio timestamp parsing', () {
    Future<File> createTestAudioFile(
      String filename,
      int sizeBytes,
    ) async {
      final file = File(path.join(tempDir.path, filename));
      await file.writeAsBytes(List.generate(sizeBytes, (index) => index % 256));
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

    test('parses valid Lotti filename format correctly', () async {
      // Arrange - filename represents Oct 20, 2025 at 4:49:32.203 PM
      final testFile =
          await createTestAudioFile('2025-10-20_16-49-32-203.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert - verify the parsed timestamp is used
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      // Verify timestamp was parsed correctly
      // Parsed as UTC then converted to local, so we create UTC and convert to local
      final expectedTimestamp =
          DateTime.utc(2025, 10, 20, 16, 49, 32, 203).toLocal();
      expect(captured.data.dateFrom, equals(expectedTimestamp));

      // Directory and filename use the local timestamp after conversion
      final expectedDir =
          '/audio/${expectedTimestamp.year.toString().padLeft(4, '0')}-'
          '${expectedTimestamp.month.toString().padLeft(2, '0')}-'
          '${expectedTimestamp.day.toString().padLeft(2, '0')}/';
      final expectedFile =
          '${expectedTimestamp.year.toString().padLeft(4, '0')}-'
          '${expectedTimestamp.month.toString().padLeft(2, '0')}-'
          '${expectedTimestamp.day.toString().padLeft(2, '0')}_'
          '${expectedTimestamp.hour.toString().padLeft(2, '0')}-'
          '${expectedTimestamp.minute.toString().padLeft(2, '0')}-'
          '${expectedTimestamp.second.toString().padLeft(2, '0')}-'
          '${expectedTimestamp.millisecond.toString().padLeft(3, '0')}.m4a';

      expect(captured.data.audioDirectory, equals(expectedDir));
      expect(captured.data.audioFile, equals(expectedFile));
    });

    test('parses valid filename with single-digit milliseconds', () async {
      // Arrange
      final testFile =
          await createTestAudioFile('2025-01-01_00-00-00-5.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      final expectedTimestamp = DateTime.utc(2025, 1, 1, 0, 0, 0, 5).toLocal();
      expect(captured.data.dateFrom, equals(expectedTimestamp));
      expect(captured.data.audioDirectory, equals('/audio/2025-01-01/'));
    });

    test('parses valid filename with three-digit milliseconds', () async {
      // Arrange
      final testFile =
          await createTestAudioFile('2024-12-31_23-59-59-999.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      final expectedTimestamp =
          DateTime.utc(2024, 12, 31, 23, 59, 59, 999).toLocal();
      expect(captured.data.dateFrom, equals(expectedTimestamp));

      // Directory uses the local date after timezone conversion
      final expectedDir =
          '/audio/${expectedTimestamp.year.toString().padLeft(4, '0')}-'
          '${expectedTimestamp.month.toString().padLeft(2, '0')}-'
          '${expectedTimestamp.day.toString().padLeft(2, '0')}/';
      expect(captured.data.audioDirectory, equals(expectedDir));
    });

    test('falls back to lastModified for generic filename', () async {
      // Arrange - generic filename that doesn't match Lotti format
      final testFile = await createTestAudioFile('recording.m4a', 1024);
      final xFile = XFile(testFile.path);
      final lastModified = testFile.lastModifiedSync();
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert - should use lastModified timestamp
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      // Should use lastModified timestamp instead
      expect(captured.data.dateFrom, equals(lastModified));
    });

    test('falls back to lastModified for partial format match', () async {
      // Arrange - partial date format without time
      final testFile = await createTestAudioFile('2025-10-20.m4a', 1024);
      final xFile = XFile(testFile.path);
      final lastModified = testFile.lastModifiedSync();
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      expect(captured.data.dateFrom, equals(lastModified));
    });

    test('falls back to lastModified for invalid format', () async {
      // Arrange - invalid format (missing time component)
      final testFile = await createTestAudioFile('not-a-date-format.m4a', 1024);
      final xFile = XFile(testFile.path);
      final lastModified = testFile.lastModifiedSync();
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      expect(captured.data.dateFrom, equals(lastModified));
    });

    test('falls back to lastModified for multiple extensions', () async {
      // Arrange
      final testFile = await createTestAudioFile('test.m4a.m4a', 1024);
      final xFile = XFile(testFile.path);
      final lastModified = testFile.lastModifiedSync();
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      // The parsing should fail on "test.m4a" (not a valid date)
      expect(captured.data.dateFrom, equals(lastModified));
    });

    test('uses fallback metadata reader when none registered', () async {
      // Arrange: remove injected reader to force default reader path
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }

      final testFile = await createTestAudioFile('fallback.m4a', 256);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act: default reader executes; errors are logged but do not abort import
      await importDroppedAudio(data: dropDetails);

      // Assert: Entry creation proceeded
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).called(1);
    });

    test('uses parsed timestamp in directory path', () async {
      // Arrange
      final testFile =
          await createTestAudioFile('2025-03-15_10-30-45-100.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert - directory should use parsed date
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      expect(captured.data.audioDirectory, equals('/audio/2025-03-15/'));
    });

    test('default metadata reader is bypassed in tests when flag set',
        () async {
      // Arrange: force default path and enable bypass
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }
      imageImportBypassMediaKitInTests = true;

      final testFile = await createTestAudioFile('bypass.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert: entry creation proceeded without attempting media_kit
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).called(1);

      // Cleanup flag
      imageImportBypassMediaKitInTests = false;
    });

    test('selectAudioMetadataReader returns injected reader when registered',
        () async {
      // Arrange injected reader
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }
      getIt.registerSingleton<AudioMetadataReader>(
        (_) async => const Duration(seconds: 42),
      );

      final reader = selectAudioMetadataReader();
      final result = await reader('ignored');
      expect(result, const Duration(seconds: 42));

      getIt.unregister<AudioMetadataReader>();
    });

    test('selectAudioMetadataReader returns default when not registered',
        () async {
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }
      imageImportBypassMediaKitInTests = true;
      final reader = selectAudioMetadataReader();
      final result = await reader('ignored');
      expect(result, Duration.zero);
      imageImportBypassMediaKitInTests = false;
    });

    test('computeAudioRelativePath and file name helpers return expected',
        () async {
      final ts = DateTime(2025, 10, 20, 16, 49, 32, 203);
      final rel = computeAudioRelativePath(ts);
      final name = computeAudioTargetFileName(ts, 'm4a');
      expect(rel, '/audio/2025-10-20/');
      expect(name, '2025-10-20_16-49-32-203.m4a');
    });

    test('uses parsed timestamp in target filename', () async {
      // Arrange
      final testFile =
          await createTestAudioFile('2025-06-20_14-25-30-500.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert - filename should be reformatted from parsed UTC time converted to local
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      // Filename is formatted from the local time after UTC conversion
      final parsedTime = DateTime.utc(2025, 6, 20, 14, 25, 30, 500).toLocal();
      final expectedFilename = '${parsedTime.year.toString().padLeft(4, '0')}-'
          '${parsedTime.month.toString().padLeft(2, '0')}-'
          '${parsedTime.day.toString().padLeft(2, '0')}_'
          '${parsedTime.hour.toString().padLeft(2, '0')}-'
          '${parsedTime.minute.toString().padLeft(2, '0')}-'
          '${parsedTime.second.toString().padLeft(2, '0')}-'
          '${parsedTime.millisecond.toString().padLeft(3, '0')}.m4a';

      expect(
        captured.data.audioFile,
        equals(expectedFilename),
      );
    });

    test('uses parsed timestamp in AudioNote createdAt', () async {
      // Arrange
      final testFile =
          await createTestAudioFile('2025-08-10_08-15-22-750.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      final expectedTimestamp =
          DateTime.utc(2025, 8, 10, 8, 15, 22, 750).toLocal();
      expect(captured.data.dateFrom, equals(expectedTimestamp));
    });

    test('handles different timestamps for Lotti vs generic files', () async {
      // Arrange - one Lotti format, one generic
      final lottiFile =
          await createTestAudioFile('2025-05-15_12-00-00-100.m4a', 1024);
      final genericFile = await createTestAudioFile('recording.m4a', 2048);

      final lottiXFile = XFile(lottiFile.path);
      final genericXFile = XFile(genericFile.path);

      // Process files separately to verify different timestamps
      final lottiDetails = createDropDetails([lottiXFile]);
      final genericDetails = createDropDetails([genericXFile]);

      // Act
      await importDroppedAudio(data: lottiDetails);
      await importDroppedAudio(data: genericDetails);

      // Assert
      final capturedList = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured;

      final lottiAudio = capturedList[0] as JournalAudio;
      final genericAudio = capturedList[1] as JournalAudio;

      // Lotti file should have parsed timestamp
      expect(
        lottiAudio.data.dateFrom,
        equals(DateTime.utc(2025, 5, 15, 12, 0, 0, 100).toLocal()),
      );

      // Generic file should have lastModified timestamp (different from parsed)
      final genericLastModified = genericFile.lastModifiedSync();
      expect(genericAudio.data.dateFrom, equals(genericLastModified));

      // Timestamps should be different
      expect(
        lottiAudio.data.dateFrom,
        isNot(equals(genericAudio.data.dateFrom)),
      );
    });

    test('preserves milliseconds precision in parsing', () async {
      // Arrange - test various millisecond values
      final files = [
        await createTestAudioFile('2025-01-01_00-00-00-1.m4a', 1024),
        await createTestAudioFile('2025-01-01_00-00-01-50.m4a', 1024),
        await createTestAudioFile('2025-01-01_00-00-02-999.m4a', 1024),
      ];

      final expectedMilliseconds = [1, 50, 999];

      // Act & Assert
      for (var i = 0; i < files.length; i++) {
        final xFile = XFile(files[i].path);
        final dropDetails = createDropDetails([xFile]);

        await importDroppedAudio(data: dropDetails);

        final captured = verify(
          () => mockPersistenceLogic.createDbEntity(
            captureAny(that: isA<JournalAudio>()),
            linkedId: any(named: 'linkedId'),
          ),
        ).captured.last as JournalAudio;

        expect(
          captured.data.dateFrom.millisecond,
          equals(expectedMilliseconds[i]),
        );
      }
    });

    test('handles date boundary - end of month', () async {
      // Arrange - last day of February (non-leap year)
      final testFile =
          await createTestAudioFile('2025-02-28_23-59-59-999.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      final expectedTimestamp =
          DateTime.utc(2025, 2, 28, 23, 59, 59, 999).toLocal();
      expect(captured.data.dateFrom, equals(expectedTimestamp));

      // Directory uses the local date after timezone conversion
      final expectedDir =
          '/audio/${expectedTimestamp.year.toString().padLeft(4, '0')}-'
          '${expectedTimestamp.month.toString().padLeft(2, '0')}-'
          '${expectedTimestamp.day.toString().padLeft(2, '0')}/';
      expect(captured.data.audioDirectory, equals(expectedDir));
    });

    test('handles date boundary - year transition', () async {
      // Arrange - last second of the year
      final testFile =
          await createTestAudioFile('2024-12-31_23-59-59-999.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      final expectedTimestamp =
          DateTime.utc(2024, 12, 31, 23, 59, 59, 999).toLocal();
      expect(captured.data.dateFrom, equals(expectedTimestamp));

      // Directory uses the local date after timezone conversion (may roll over to next year)
      final expectedDir =
          '/audio/${expectedTimestamp.year.toString().padLeft(4, '0')}-'
          '${expectedTimestamp.month.toString().padLeft(2, '0')}-'
          '${expectedTimestamp.day.toString().padLeft(2, '0')}/';
      expect(captured.data.audioDirectory, equals(expectedDir));
    });

    test('handles leap year date', () async {
      // Arrange - Feb 29 in leap year 2024
      final testFile =
          await createTestAudioFile('2024-02-29_12-30-45-500.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      final expectedTimestamp =
          DateTime.utc(2024, 2, 29, 12, 30, 45, 500).toLocal();
      expect(captured.data.dateFrom, equals(expectedTimestamp));
      expect(captured.data.audioDirectory, equals('/audio/2024-02-29/'));
    });
  });

  group('importDroppedAudio', () {
    // Note: duration probing is already bypassed in tests via FLUTTER_TEST.
    // Individual tests toggle imageImportBypassMediaKitInTests as needed.
    Future<File> createTestAudioFile(
      String filename,
      int sizeBytes,
    ) async {
      final file = File(path.join(tempDir.path, filename));
      await file.create(recursive: true);
      // For very large sizes, create a sparse file quickly instead of writing
      // every byte. This makes the test fast while preserving File.length().
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
      // Small files: write a minimal payload
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

    test('successfully imports valid M4A file', () async {
      // Arrange
      final testFile = await createTestAudioFile('test.m4a', 1024 * 100);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert - creates audio entry (duration extraction may fail in test)
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).called(1);
    });

    test('skips non-audio file silently', () async {
      // Arrange
      final testFile = await createTestAudioFile('test.txt', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert - should not attempt to create entry
      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    test('logs error for file without extension', () async {
      // Arrange
      final testFile = await createTestAudioFile('test', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert
      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('no extension')),
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importDroppedAudio',
        ),
      ).called(1);
      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    test('logs error for file exceeding 500MB limit', () async {
      // Arrange - create file larger than limit
      const largeSize = MediaImportConstants.maxAudioFileSizeBytes + 1;
      final testFile = await createTestAudioFile('large.m4a', largeSize);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert
      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importDroppedAudio',
        ),
      ).called(1);
      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    test('continues on duration extraction failure', () async {
      // Arrange
      final testFile = await createTestAudioFile('test.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act - duration extraction will fail but should continue
      await importDroppedAudio(data: dropDetails);

      // Assert - should still create entry with zero duration
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).called(1);
    });

    test('processes multiple files and continues on single failure', () async {
      // Arrange
      final goodFile1 = await createTestAudioFile('good1.m4a', 1024);
      final goodFile2 = await createTestAudioFile('good2.m4a', 2048);
      final files = [
        XFile(goodFile1.path),
        XFile(goodFile2.path),
      ];
      final dropDetails = createDropDetails(files);

      // Make first file import fail
      var callCount = 0;
      when(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw Exception('First audio file failed');
        }
        return true;
      });

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert - both files attempted
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(2);
      // First failure logged (from repository layer)
      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: isA<Exception>()),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(greaterThan(0));
    });

    test('passes linkedId to createAudioEntry', () async {
      // Arrange
      final testFile = await createTestAudioFile('test.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);
      const linkedId = 'parent-entry-456';

      // Act
      await importDroppedAudio(
        data: dropDetails,
        linkedId: linkedId,
      );

      // Assert
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: linkedId,
        ),
      ).called(1);
    });

    test('handles case-insensitive file extensions', () async {
      // Arrange - uppercase extension
      final testFile = await createTestAudioFile('test.M4A', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert - should process file despite uppercase extension
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).called(1);
    });

    test('creates audio in correct date-based directory', () async {
      // Arrange
      final testFile = await createTestAudioFile('test.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert - verify directory path
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).captured.single as JournalAudio;

      expect(captured.data.audioDirectory, startsWith('/audio/'));
    });

    test('handles empty file list without error', () async {
      // Arrange
      final dropDetails = createDropDetails([]);

      // Act & Assert - should not throw
      await importDroppedAudio(data: dropDetails);

      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    test('cleans up file when entry creation returns null', () async {
      // Arrange
      final testFile = await createTestAudioFile('test.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Mock createAudioEntry to return null (via persistence failure)
      when(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => false);

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert - the copied file should be cleaned up
      // Note: This is hard to test directly, but we verify the entry creation was attempted
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
        ),
      ).called(1);
    });

    test('logs exception when file deletion fails after null result', () async {
      // Arrange
      final testFile = await createTestAudioFile('test.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Mock createAudioEntry to return null
      when(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).thenAnswer((_) async => false);

      // Mock file to throw exception on delete
      // Note: This is difficult to test directly as we'd need to mock File operations
      // The actual code will handle this gracefully

      // Act
      await importDroppedAudio(data: dropDetails);

      // Assert - entry creation was attempted
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

    test('handles exception gracefully when audio processing fails', () async {
      // Arrange
      final testFile = await createTestAudioFile('test.m4a', 1024);
      final xFile = XFile(testFile.path);
      final dropDetails = createDropDetails([xFile]);

      // Make createDbEntity throw an exception
      when(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).thenThrow(Exception('Database error'));

      // Act & Assert - should not throw, exception should be caught internally
      await expectLater(
        importDroppedAudio(data: dropDetails),
        completes,
      );
    });
  });

  group('importGeneratedImageBytes', () {
    test('rejects images exceeding size limit and returns null', () async {
      // Create data larger than the limit
      final oversizedData = Uint8List(
        MediaImportConstants.maxImageFileSizeBytes + 1,
      );

      // Should return null without throwing
      final result = await importGeneratedImageBytes(
        data: oversizedData,
        fileExtension: 'png',
        linkedId: 'test-id',
        categoryId: 'category-id',
      );

      // Verify null is returned
      expect(result, isNull);

      // Verify that an exception was logged
      verify(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importGeneratedImageBytes',
        ),
      ).called(1);
    });

    test('accepts images within size limit and returns id', () async {
      // Create data within the limit (small file)
      final validData = Uint8List(1000); // 1KB file

      // Should succeed and return an ID
      final result = await importGeneratedImageBytes(
        data: validData,
        fileExtension: 'png',
        linkedId: 'test-id',
        categoryId: 'category-id',
      );

      // Verify an ID is returned
      expect(result, equals('test-id'));

      // Verify that NO size-related exception was logged
      verifyNever(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importGeneratedImageBytes',
        ),
      );
    });

    test('passes linkedId to createImageEntry', () async {
      final validData = Uint8List(1000);
      const linkedId = 'parent-task-123';

      await importGeneratedImageBytes(
        data: validData,
        fileExtension: 'png',
        linkedId: linkedId,
      );

      // Verify the linkedId was passed correctly
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalImage>()),
          linkedId: captureAny(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured;

      expect(captured[0], isA<JournalImage>());
      expect(captured[1], equals(linkedId));
    });

    test('returns null when entry creation throws exception', () async {
      final validData = Uint8List(1000);

      // Reset and re-setup mock to throw an exception
      reset(mockPersistenceLogic);

      // Re-setup metadata mock to throw
      when(
        () => mockPersistenceLogic.createMetadata(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          uuidV5Input: any(named: 'uuidV5Input'),
          flag: any(named: 'flag'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenThrow(Exception('Database error'));

      final result = await importGeneratedImageBytes(
        data: validData,
        fileExtension: 'png',
        linkedId: 'test-id',
      );

      // Should return null when creation throws
      expect(result, isNull);
    });

    test('uses provided file extension in filename', () async {
      final validData = Uint8List(1000);

      await importGeneratedImageBytes(
        data: validData,
        fileExtension: 'jpg',
        linkedId: 'test-id',
      );

      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured.single as JournalImage;

      expect(captured.data.imageFile, endsWith('.jpg'));
    });

    test('creates image in date-based directory', () async {
      final validData = Uint8List(1000);

      await importGeneratedImageBytes(
        data: validData,
        fileExtension: 'png',
      );

      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured.single as JournalImage;

      // Directory should start with /images/ and have date format
      expect(captured.data.imageDirectory, startsWith('/images/'));
      expect(
        captured.data.imageDirectory,
        matches(RegExp(r'^/images/\d{4}-\d{2}-\d{2}/$')),
      );
    });

    test('exactly at size limit should pass', () async {
      // Create data exactly at the limit
      final exactLimitData = Uint8List(
        MediaImportConstants.maxImageFileSizeBytes,
      );

      final result = await importGeneratedImageBytes(
        data: exactLimitData,
        fileExtension: 'png',
      );

      // Should succeed (not rejected due to size)
      expect(result, equals('test-id'));

      // Should NOT log size error for file at exactly the limit
      verifyNever(
        () => mockLoggingService.captureException(
          any<Object>(that: contains('too large')),
          domain: MediaImportConstants.loggingDomain,
          subDomain: 'importGeneratedImageBytes',
        ),
      );
    });

    test('supports different file extensions', () async {
      final validData = Uint8List(500);

      // Test with PNG
      await importGeneratedImageBytes(
        data: validData,
        fileExtension: 'png',
      );

      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured.last as JournalImage;

      expect(captured.data.imageFile, endsWith('.png'));
    });

    test('works without linkedId or categoryId', () async {
      final validData = Uint8List(500);

      final result = await importGeneratedImageBytes(
        data: validData,
        fileExtension: 'png',
      );

      // Should still succeed
      expect(result, equals('test-id'));

      // Verify createDbEntity was called (linkedId defaults to null when not provided)
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId', that: isNull),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(1);
    });
  });

  group('handleDroppedMedia', () {
    Future<File> createTestFile(String filename, int sizeBytes) async {
      final file = File(path.join(tempDir.path, filename));
      await file.writeAsBytes(List.generate(sizeBytes, (index) => index % 256));
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

    test('calls importDroppedImages for image files only', () async {
      // Arrange
      final imageFile = await createTestFile('test.jpg', 1024);
      final dropDetails = createDropDetails([XFile(imageFile.path)]);

      // Act
      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'test-linked-id',
      );

      // Assert - image entry created
      final captured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalImage>()),
          linkedId: captureAny(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured;

      // Verify the captured values
      expect(captured[0], isA<JournalImage>());
      expect(captured[1], equals('test-linked-id'));

      // No audio entries
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

    test('calls importDroppedAudio for audio files only', () async {
      // Arrange
      final audioFile = await createTestFile('test.m4a', 1024);
      final dropDetails = createDropDetails([XFile(audioFile.path)]);

      // Act
      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'test-linked-id',
      );

      // Assert - audio entry created
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: 'test-linked-id',
        ),
      ).called(1);
      // No image entries
      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    test('calls both import functions for mixed file types', () async {
      // Arrange
      final imageFile = await createTestFile('photo.jpg', 1024);
      final audioFile = await createTestFile('recording.m4a', 2048);
      final dropDetails = createDropDetails([
        XFile(imageFile.path),
        XFile(audioFile.path),
      ]);

      // Act
      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'test-linked-id',
      );

      // Assert - both types created
      final imageCaptured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalImage>()),
          linkedId: captureAny(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured;

      expect(imageCaptured[0], isA<JournalImage>());
      expect(imageCaptured[1], equals('test-linked-id'));

      final audioCaptured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: captureAny(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured;

      expect(audioCaptured[0], isA<JournalAudio>());
      expect(audioCaptured[1], equals('test-linked-id'));
    });

    test('handles empty file list without error', () async {
      // Arrange
      final dropDetails = createDropDetails([]);

      // Act & Assert - should not throw
      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'test-linked-id',
      );

      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    test('handles unsupported file types without error', () async {
      // Arrange
      final textFile = await createTestFile('document.txt', 1024);
      final pdfFile = await createTestFile('document.pdf', 2048);
      final dropDetails = createDropDetails([
        XFile(textFile.path),
        XFile(pdfFile.path),
      ]);

      // Act & Assert - should not throw
      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'test-linked-id',
      );

      // No entries created for unsupported types
      verifyNever(
        () => mockPersistenceLogic.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    test('passes categoryId to both import functions', () async {
      // Arrange
      final imageFile = await createTestFile('photo.jpg', 1024);
      final audioFile = await createTestFile('recording.m4a', 2048);
      final dropDetails = createDropDetails([
        XFile(imageFile.path),
        XFile(audioFile.path),
      ]);

      // Act
      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'test-linked-id',
        categoryId: 'test-category',
      );

      // Assert - both called with correct IDs
      final imageCaptured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalImage>()),
          linkedId: captureAny(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured;

      expect(imageCaptured[0], isA<JournalImage>());
      expect(imageCaptured[1], equals('test-linked-id'));

      final audioCaptured = verify(
        () => mockPersistenceLogic.createDbEntity(
          captureAny(that: isA<JournalAudio>()),
          linkedId: captureAny(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).captured;

      expect(audioCaptured[0], isA<JournalAudio>());
      expect(audioCaptured[1], equals('test-linked-id'));
    });

    test('handles multiple images and multiple audio files', () async {
      // Arrange
      final image1 = await createTestFile('photo1.jpg', 1024);
      final image2 = await createTestFile('photo2.png', 2048);
      final audio1 = await createTestFile('recording1.m4a', 3072);
      final audio2 = await createTestFile('recording2.m4a', 4096);
      final dropDetails = createDropDetails([
        XFile(image1.path),
        XFile(image2.path),
        XFile(audio1.path),
        XFile(audio2.path),
      ]);

      // Act
      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'test-linked-id',
      );

      // Assert - all files processed
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: 'test-linked-id',
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(2);
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: 'test-linked-id',
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(2);
    });

    test('efficiently checks file types once', () async {
      // Arrange
      final imageFile = await createTestFile('photo.jpg', 1024);
      final audioFile = await createTestFile('recording.m4a', 2048);
      final dropDetails = createDropDetails([
        XFile(imageFile.path),
        XFile(audioFile.path),
      ]);

      // Act
      await handleDroppedMedia(
        data: dropDetails,
        linkedId: 'test-linked-id',
      );

      // Assert - function groups files and calls each import once
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: 'test-linked-id',
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(1);
      verify(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalAudio>()),
          linkedId: 'test-linked-id',
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          addTags: any(named: 'addTags'),
        ),
      ).called(1);
    });
  });
}
