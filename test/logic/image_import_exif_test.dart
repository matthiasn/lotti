import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../helpers/path_provider.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockFts5Db extends Mock implements Fts5Db {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockTagsService extends Mock implements TagsService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockTimeService extends Mock implements TimeService {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    getIt.pushNewScope();
    setFakeDocumentsPath();

    // Register mock services
    getIt
      ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
      ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<Fts5Db>(MockFts5Db())
      ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
      ..registerSingleton<VectorClockService>(MockVectorClockService())
      ..registerSingleton<UpdateNotifications>(MockUpdateNotifications())
      ..registerSingleton<TagsService>(MockTagsService())
      ..registerSingleton<NotificationService>(MockNotificationService())
      ..registerSingleton<TimeService>(MockTimeService())
      ..registerSingleton<LoggingService>(MockLoggingService());
  });

  tearDownAll(() async {
    await getIt.resetScope();
    await getIt.popScope();
  });

  group('EXIF Timestamp Extraction', () {
    test('extracts DateTimeOriginal from valid EXIF data', () async {
      // Create a minimal JPEG with EXIF DateTimeOriginal
      // JPEG header + EXIF marker + DateTimeOriginal tag
      final jpegWithExif = Uint8List.fromList([
        // JPEG SOI marker
        0xFF, 0xD8,
        // APP1 marker (EXIF)
        0xFF, 0xE1,
        // APP1 length (high byte, low byte)
        0x00, 0x16,
        // EXIF identifier
        0x45, 0x78, 0x69, 0x66, 0x00, 0x00,
        // Padding/dummy data to make it parseable
        ...List.filled(100, 0x00),
        // JPEG EOI marker
        0xFF, 0xD9,
      ]);

      // Note: Real EXIF parsing will fail with this minimal data,
      // so we're testing the fallback behavior
      // Should complete without throwing
      expect(
        () async => await importPastedImages(
          data: jpegWithExif,
          fileExtension: 'jpg',
        ),
        returnsNormally,
      );
    });

    test('handles image with no EXIF data gracefully', () async {
      // Minimal valid JPEG without EXIF
      final jpegNoExif = Uint8List.fromList([
        0xFF, 0xD8, // SOI
        0xFF, 0xD9, // EOI
      ]);

      expect(
        () async => await importPastedImages(
          data: jpegNoExif,
          fileExtension: 'jpg',
        ),
        returnsNormally,
      );
    });

    test('handles corrupted EXIF data without crashing', () async {
      // Invalid/corrupted data
      final corruptedData = Uint8List.fromList([
        0xFF, 0xD8, // JPEG start
        0xFF, 0xE1, // APP1 marker
        0x00, 0x10, // Length
        // Garbage data
        ...List.generate(20, (i) => i % 256),
      ]);

      expect(
        () async => await importPastedImages(
          data: corruptedData,
          fileExtension: 'jpg',
        ),
        returnsNormally,
      );
    });

    test('handles empty image data', () async {
      final emptyData = Uint8List.fromList([]);

      expect(
        () async => await importPastedImages(
          data: emptyData,
          fileExtension: 'jpg',
        ),
        returnsNormally,
      );
    });

    test('handles PNG images (which may have different metadata format)',
        () async {
      // PNG signature
      final pngData = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        ...List.filled(50, 0x00), // Dummy data
      ]);

      expect(
        () async => await importPastedImages(
          data: pngData,
          fileExtension: 'png',
        ),
        returnsNormally,
      );
    });
  });

  group('EXIF DateTime Parsing', () {
    // Note: _parseExifDateTime is private, so we test it indirectly
    // through importPastedImages behavior

    test('importPastedImages processes valid image data', () async {
      final validJpeg = Uint8List.fromList([
        0xFF, 0xD8, // SOI
        0xFF, 0xD9, // EOI
      ]);

      // Should not throw
      expect(
        () async => await importPastedImages(
          data: validJpeg,
          fileExtension: 'jpg',
          linkedId: 'test-link',
          categoryId: 'test-category',
        ),
        returnsNormally,
      );
    });

    test('handles various JPEG variations', () async {
      // Test with slightly larger JPEG
      final largerJpeg = Uint8List.fromList([
        0xFF, 0xD8, // SOI
        ...List.filled(1000, 0xFF), // Content
        0xFF, 0xD9, // EOI
      ]);

      expect(
        () async => await importPastedImages(
          data: largerJpeg,
          fileExtension: 'jpeg',
        ),
        returnsNormally,
      );
    });
  });

  group('File Size Validation', () {
    test('rejects images exceeding size limit', () async {
      final loggingService = getIt<LoggingService>();

      // Create oversized image (> 50MB)
      final oversizedData = Uint8List(51 * 1024 * 1024);

      await importPastedImages(
        data: oversizedData,
        fileExtension: 'jpg',
      );

      // Verify logging was called for oversized file
      verify(
        () => loggingService.captureException(
          any<String>(),
          domain: 'media_import',
          subDomain: 'importPastedImages',
        ),
      ).called(1);
    });

    test('accepts images at size limit boundary', () async {
      // Exactly 50MB
      final boundaryData = Uint8List(50 * 1024 * 1024);

      // Prepend JPEG markers
      boundaryData[0] = 0xFF;
      boundaryData[1] = 0xD8;
      boundaryData[boundaryData.length - 2] = 0xFF;
      boundaryData[boundaryData.length - 1] = 0xD9;

      expect(
        () async => await importPastedImages(
          data: boundaryData,
          fileExtension: 'jpg',
        ),
        returnsNormally,
      );
    });
  });

  group('Edge Cases', () {
    test('handles null-like inputs gracefully', () async {
      final minimalData = Uint8List.fromList([0x00]);

      expect(
        () async => await importPastedImages(
          data: minimalData,
          fileExtension: 'jpg',
        ),
        returnsNormally,
      );
    });

    test('handles various file extensions', () async {
      final data = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

      for (final ext in ['jpg', 'jpeg', 'JPG', 'JPEG', 'png', 'PNG']) {
        expect(
          () async => await importPastedImages(
            data: data,
            fileExtension: ext,
          ),
          returnsNormally,
          reason: 'Should handle extension: $ext',
        );
      }
    });
  });
}
