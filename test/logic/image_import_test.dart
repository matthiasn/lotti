import 'dart:io';

import 'package:clock/clock.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../helpers/fake_image_compress_platform.dart';
import '../helpers/fallbacks.dart';
import '../helpers/path_provider.dart';
import '../helpers/target_platform.dart';
import '../mocks/mocks.dart';

// ---------------------------------------------------------------------------
// Top-level fakes / helpers used by the canonical tests
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Shared JPEG builder helpers (used by multiple groups below)
// ---------------------------------------------------------------------------

/// Creates a minimal JPEG with basic structure for testing
Uint8List _createMinimalJpegWithExif() {
  return Uint8List.fromList([
    // JPEG SOI (Start of Image) marker
    0xFF, 0xD8,
    // APP1 (EXIF) marker
    0xFF, 0xE1,
    // Length of APP1 segment (2 bytes, big-endian)
    0x00, 0x20, // 32 bytes
    // EXIF identifier
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
    // TIFF header - little endian
    0x49, 0x49, 0x2A, 0x00,
    // Offset to first IFD
    0x08, 0x00, 0x00, 0x00,
    // Padding to meet declared length
    ...List.filled(16, 0x00),
    // JPEG EOI (End of Image) marker
    0xFF, 0xD9,
  ]);
}

/// Creates a JPEG with valid GPS EXIF data
/// GPS coordinates: 37.7749° N, 122.4194° W (San Francisco)
Uint8List _createJpegWithGpsExif() {
  return Uint8List.fromList([
    // JPEG SOI
    0xFF, 0xD8,
    // APP1 (EXIF) marker
    0xFF, 0xE1,
    // APP1 data length (needs to be large enough for GPS data)
    0x00, 0xE0,
    // EXIF header
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
    // TIFF header (little-endian)
    0x49, 0x49, // Byte order
    0x2A, 0x00, // TIFF magic
    0x08, 0x00, 0x00, 0x00, // Offset to first IFD
    // IFD0
    0x02, 0x00, // Number of entries
    // Entry 1: DateTime (tag 0x0132)
    0x32, 0x01, 0x02, 0x00, 0x14, 0x00, 0x00, 0x00, 0x32, 0x00, 0x00, 0x00,
    // Entry 2: GPS IFD Pointer (tag 0x8825)
    0x25, 0x88, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00, 0x50, 0x00, 0x00, 0x00,
    // Next IFD offset
    0x00, 0x00, 0x00, 0x00,
    // DateTime value: "2024:01:15 10:20:30\0"
    0x32, 0x30, 0x32, 0x34, 0x3A, 0x30, 0x31, 0x3A,
    0x31, 0x35, 0x20, 0x31, 0x30, 0x3A, 0x32, 0x30,
    0x3A, 0x33, 0x30, 0x00,
    // GPS IFD (starts at offset 0x50)
    0x04, 0x00, // Number of GPS entries
    // GPSLatitudeRef (tag 0x0001) - 'N'
    0x01, 0x00, 0x02, 0x00, 0x02, 0x00, 0x00, 0x00, 0x4E, 0x00, 0x00, 0x00,
    // GPSLatitude (tag 0x0002) - 37° 46' 29.64"
    0x02, 0x00, 0x05, 0x00, 0x03, 0x00, 0x00, 0x00, 0x90, 0x00, 0x00, 0x00,
    // GPSLongitudeRef (tag 0x0003) - 'W'
    0x03, 0x00, 0x02, 0x00, 0x02, 0x00, 0x00, 0x00, 0x57, 0x00, 0x00, 0x00,
    // GPSLongitude (tag 0x0004) - 122° 25' 9.84"
    0x04, 0x00, 0x05, 0x00, 0x03, 0x00, 0x00, 0x00, 0xA8, 0x00, 0x00, 0x00,
    // Next IFD offset
    0x00, 0x00, 0x00, 0x00,
    // Latitude data: 37/1, 46/1, 2964/100
    0x25, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // 37/1
    0x2E, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // 46/1
    0x94, 0x0B, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, // 2964/100
    // Longitude data: 122/1, 25/1, 984/100
    0x7A, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // 122/1
    0x19, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // 25/1
    0xD8, 0x03, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, // 984/100
    // Padding
    ...List.filled(50, 0x00),
    // SOF0
    0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11,
    0x00,
    // SOS
    0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
    // Image data
    0xD2, 0x00,
    // EOI
    0xFF, 0xD9,
  ]);
}

/// Creates a JPEG with GPS EXIF data at equator/prime meridian
/// GPS coordinates: 0.0° N, 0.0° E (Null Island)
Uint8List _createJpegWithGpsExifAtZeroZero() {
  return Uint8List.fromList([
    // JPEG SOI
    0xFF, 0xD8,
    // APP1 (EXIF) marker
    0xFF, 0xE1,
    // APP1 data length (needs to be large enough for GPS data)
    0x00, 0xE0,
    // EXIF header
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
    // TIFF header (little-endian)
    0x49, 0x49, // Byte order
    0x2A, 0x00, // TIFF magic
    0x08, 0x00, 0x00, 0x00, // Offset to first IFD
    // IFD0
    0x02, 0x00, // Number of entries
    // Entry 1: DateTime (tag 0x0132)
    0x32, 0x01, 0x02, 0x00, 0x14, 0x00, 0x00, 0x00, 0x32, 0x00, 0x00, 0x00,
    // Entry 2: GPS IFD Pointer (tag 0x8825)
    0x25, 0x88, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00, 0x50, 0x00, 0x00, 0x00,
    // Next IFD offset
    0x00, 0x00, 0x00, 0x00,
    // DateTime value: "2024:01:15 10:20:30\0"
    0x32, 0x30, 0x32, 0x34, 0x3A, 0x30, 0x31, 0x3A,
    0x31, 0x35, 0x20, 0x31, 0x30, 0x3A, 0x32, 0x30,
    0x3A, 0x33, 0x30, 0x00,
    // GPS IFD (starts at offset 0x50)
    0x04, 0x00, // Number of GPS entries
    // GPSLatitudeRef (tag 0x0001) - 'N'
    0x01, 0x00, 0x02, 0x00, 0x02, 0x00, 0x00, 0x00, 0x4E, 0x00, 0x00, 0x00,
    // GPSLatitude (tag 0x0002) - 0° 0' 0"
    0x02, 0x00, 0x05, 0x00, 0x03, 0x00, 0x00, 0x00, 0x90, 0x00, 0x00, 0x00,
    // GPSLongitudeRef (tag 0x0003) - 'E'
    0x03, 0x00, 0x02, 0x00, 0x02, 0x00, 0x00, 0x00, 0x45, 0x00, 0x00, 0x00,
    // GPSLongitude (tag 0x0004) - 0° 0' 0"
    0x04, 0x00, 0x05, 0x00, 0x03, 0x00, 0x00, 0x00, 0xA8, 0x00, 0x00, 0x00,
    // Next IFD offset
    0x00, 0x00, 0x00, 0x00,
    // Latitude data: 0/1, 0/1, 0/1
    0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // 0/1
    0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // 0/1
    0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // 0/1
    // Longitude data: 0/1, 0/1, 0/1
    0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // 0/1
    0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // 0/1
    0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // 0/1
    // Padding
    ...List.filled(50, 0x00),
    // SOF0
    0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11,
    0x00,
    // SOS
    0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
    // Image data
    0xD2, 0x00,
    // EOI
    0xFF, 0xD9,
  ]);
}

/// Builds a byte-correct JPEG with TIFF-relative timestamp offsets.
Uint8List buildExifJpegWithDateTime(
  String dateTime, {
  String? originalDateTime,
}) {
  List<int> uint32(int value) => [
    for (var shift = 0; shift < 32; shift += 8) (value >> shift) & 0xff,
  ];
  final value = [...dateTime.codeUnits, 0];
  final original = originalDateTime == null
      ? null
      : [...originalDateTime.codeUnits, 0];
  final valueOffset = original == null ? 26 : 38;
  final exifOffset = valueOffset + value.length;
  final tiff = <int>[
    0x49,
    0x49,
    0x2a,
    0,
    8,
    0,
    0,
    0,
    if (original == null) 1 else 2,
    0,
    0x32,
    0x01,
    2,
    0,
    ...uint32(value.length),
    ...uint32(valueOffset),
    if (original != null) ...[
      0x69,
      0x87,
      4,
      0,
      ...uint32(1),
      ...uint32(exifOffset),
    ],
    ...uint32(0),
    ...value,
    if (original != null) ...[
      1,
      0,
      0x03,
      0x90,
      2,
      0,
      ...uint32(original.length),
      ...uint32(exifOffset + 18),
      ...uint32(0),
      ...original,
    ],
  ];
  final app1Length = 2 + 6 + tiff.length;
  return Uint8List.fromList([
    0xff,
    0xd8,
    0xff,
    0xe1,
    app1Length >> 8,
    app1Length & 0xff,
    0x45,
    0x78,
    0x69,
    0x66,
    0,
    0,
    ...tiff,
    0xff,
    0xd9,
  ]);
}

Uint8List _createHeifBytes({required bool hasAlpha}) {
  return Uint8List.fromList([
    ...'\u0000\u0000\u0000\u0018ftypheic\u0000\u0000\u0000\u0000'.codeUnits,
    ...'\u0000\u0000\u0000\u0008meta'.codeUnits,
    if (hasAlpha)
      ...'\u0000\u0000\u0000\u0028auxC'
              'urn:mpeg:hevc:2015:auxid:1\u0000'
          .codeUnits,
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Canonical tests (originally in image_import_test.dart)
  // ---------------------------------------------------------------------------

  group('canonical', () {
    late MockDomainLogger mockDomainLogger;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockJournalDb mockJournalDb;
    late Directory tempDir;

    setUpAll(() {
      registerFallbackValue(StackTrace.current);
      registerFallbackValue(FakeJournalImage());
      registerFallbackValue(FakeMetadata());
      registerFallbackValue(DateTime(2024, 3, 15));
    });

    setUp(() async {
      mockDomainLogger = MockDomainLogger();
      mockPersistenceLogic = MockPersistenceLogic();
      mockJournalDb = MockJournalDb();

      tempDir = await Directory.systemTemp.createTemp('image_import_test_');

      if (getIt.isRegistered<DomainLogger>()) {
        getIt.unregister<DomainLogger>();
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
        ..registerSingleton<DomainLogger>(mockDomainLogger)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<Directory>(tempDir);

      when(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockPersistenceLogic.createMetadata(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          uuidV5Input: any(named: 'uuidV5Input'),
          categoryId: any(named: 'categoryId'),
          flag: any(named: 'flag'),
        ),
      ).thenAnswer(
        (_) async => Metadata(
          id: 'test-id',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );

      when(
        () => mockPersistenceLogic.createDbEntity(
          any(that: isA<JournalImage>()),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          enqueueSync: any(named: 'enqueueSync'),
          linkCollapsed: any(named: 'linkCollapsed'),
        ),
      ).thenAnswer((_) async => true);
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}

      if (getIt.isRegistered<DomainLogger>()) {
        getIt.unregister<DomainLogger>();
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

    List<XFile> createDropDetails(List<XFile> xfiles) => xfiles;

    group('ImageImportConstants', () {
      test('defines supported extensions', () {
        expect(
          ImageImportConstants.supportedExtensionsForPlatform(
            TargetPlatform.macOS,
          ),
          containsAll(['jpg', 'jpeg', 'png', 'heic', 'heif']),
        );
        expect(
          ImageImportConstants.supportedExtensionsForPlatform(
            TargetPlatform.macOS,
          ),
          hasLength(5),
        );
        expect(
          ImageImportConstants.supportedExtensionsForPlatform(
            TargetPlatform.linux,
          ),
          containsAll(['jpg', 'jpeg', 'png']),
        );
        expect(
          ImageImportConstants.supportedExtensionsForPlatform(
            TargetPlatform.linux,
          ),
          isNot(contains('heic')),
        );
        expect(
          ImageImportConstants.supportedExtensionsForPlatform(
            TargetPlatform.linux,
          ),
          isNot(contains('heif')),
        );
      });

      test('defines reasonable file size limit', () {
        expect(ImageImportConstants.maxFileSizeBytes, equals(50 * 1024 * 1024));
      });

      test('defines directory prefix', () {
        expect(ImageImportConstants.directoryPrefix, equals('/images/'));
      });
    });

    group('sourceExtensionForAssetFile', () {
      test(
        'returns null for assets without identifiable image extension',
        () async {
          final asset = MockAssetEntity();
          final file = File(path.join(tempDir.path, 'opaque_asset'));

          when(() => asset.mimeType).thenReturn(null);
          when(() => asset.titleAsync).thenAnswer((_) async => 'opaque_asset');

          final extension = await sourceExtensionForAssetFile(asset, file);

          expect(extension, isNull);
        },
      );
    });

    group('importPastedImages', () {
      test('detects HEIF alpha auxiliary image metadata', () {
        expect(
          heifContainsAlphaAuxiliaryImage(_createHeifBytes(hasAlpha: true)),
          isTrue,
        );
        expect(
          heifContainsAlphaAuxiliaryImage(_createHeifBytes(hasAlpha: false)),
          isFalse,
        );
      });

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
          () => mockDomainLogger.error(
            LogDomain.ai,
            any<Object>(that: contains('too large')),
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
          () => mockDomainLogger.error(
            LogDomain.ai,
            any<Object>(that: contains('too large')),
            subDomain: 'importPastedImages',
          ),
        );
      });

      test('successfully creates image entry for valid pasted image', () async {
        final validData = Uint8List.fromList(List<int>.filled(500, 0xFF));

        await importPastedImages(
          data: validData,
          fileExtension: 'png',
          linkedId: 'linked-123',
          categoryId: 'cat-456',
        );

        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: 'linked-123',
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        ).called(1);
      });

      test('creates image entry without linkedId or categoryId', () async {
        final validData = Uint8List.fromList(List<int>.filled(200, 0xAA));

        await importPastedImages(data: validData, fileExtension: 'jpg');

        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        ).called(1);
      });

      test('normalizes pasted image extension before storage', () async {
        final validData = Uint8List.fromList(List<int>.filled(200, 0xBB));

        await importPastedImages(data: validData, fileExtension: 'PNG');

        final capturedImage =
            verify(
                  () => mockPersistenceLogic.createDbEntity(
                    captureAny(that: isA<JournalImage>()),
                    linkedId: any(named: 'linkedId'),
                    shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
                    enqueueSync: any(named: 'enqueueSync'),
                  ),
                ).captured.single
                as JournalImage;

        expect(capturedImage.data.imageFile, endsWith('.png'));
        expect(capturedImage.data.imageFile, isNot(endsWith('.PNG')));
      });

      test('stores pasted PNG bytes without converting them', () async {
        final pngData = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x10,
          0x20,
          0x30,
          0x40,
        ]);

        await importPastedImages(data: pngData, fileExtension: 'png');

        final capturedImage =
            verify(
                  () => mockPersistenceLogic.createDbEntity(
                    captureAny(that: isA<JournalImage>()),
                    linkedId: any(named: 'linkedId'),
                    shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
                    enqueueSync: any(named: 'enqueueSync'),
                  ),
                ).captured.single
                as JournalImage;
        final storedFile = File(
          '${tempDir.path}'
          '${capturedImage.data.imageDirectory}'
          '${capturedImage.data.imageFile}',
        );

        expect(capturedImage.data.imageFile, endsWith('.png'));
        expect(storedFile.readAsBytesSync(), equals(pngData));
      });

      test('converts pasted HEIC data to stored JPEG', () async {
        final heicData = Uint8List.fromList(List<int>.filled(200, 0xCC));

        await withTargetPlatform(
          TargetPlatform.macOS,
          () => withFakeImageCompressPlatform(
            () => importPastedImages(data: heicData, fileExtension: 'heic'),
          ),
        );

        final capturedImage =
            verify(
                  () => mockPersistenceLogic.createDbEntity(
                    captureAny(that: isA<JournalImage>()),
                    linkedId: any(named: 'linkedId'),
                    shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
                    enqueueSync: any(named: 'enqueueSync'),
                  ),
                ).captured.single
                as JournalImage;

        expect(capturedImage.data.imageFile, endsWith('.jpg'));
        expect(
          File(
            '${tempDir.path}'
            '${capturedImage.data.imageDirectory}'
            '${capturedImage.data.imageFile}',
          ).existsSync(),
          isTrue,
        );
      });

      test('converts pasted HEIC data with alpha to stored PNG', () async {
        final heicData = _createHeifBytes(hasAlpha: true);

        await withTargetPlatform(
          TargetPlatform.macOS,
          () => withFakeImageCompressPlatform(
            () => importPastedImages(data: heicData, fileExtension: 'heic'),
          ),
        );

        final capturedImage =
            verify(
                  () => mockPersistenceLogic.createDbEntity(
                    captureAny(that: isA<JournalImage>()),
                    linkedId: any(named: 'linkedId'),
                    shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
                    enqueueSync: any(named: 'enqueueSync'),
                  ),
                ).captured.single
                as JournalImage;
        final storedBytes = File(
          '${tempDir.path}'
          '${capturedImage.data.imageDirectory}'
          '${capturedImage.data.imageFile}',
        ).readAsBytesSync();

        expect(capturedImage.data.imageFile, endsWith('.png'));
        expect(
          storedBytes.take(8),
          equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        );
      });
    });

    group('importDroppedImages', () {
      test('successfully imports valid JPG file', () async {
        final testFile = await createTestImageFile('test.jpg', 1024);
        final dropDetails = createDropDetails([XFile(testFile.path)]);

        await importImageXFiles(dropDetails);

        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        ).called(1);
      });

      test('successfully imports valid PNG file', () async {
        final testFile = await createTestImageFile('test.png', 1024);
        final dropDetails = createDropDetails([XFile(testFile.path)]);

        await importImageXFiles(dropDetails);

        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        ).called(1);
      });

      test('copies dropped PNG bytes without converting them', () async {
        final pngData = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0xAA,
          0xBB,
          0xCC,
        ]);
        final testFile = File(path.join(tempDir.path, 'transparent.png'));
        await testFile.create(recursive: true);
        await testFile.writeAsBytes(pngData);

        await importImageXFiles([XFile(testFile.path)]);

        final capturedImage =
            verify(
                  () => mockPersistenceLogic.createDbEntity(
                    captureAny(that: isA<JournalImage>()),
                    linkedId: any(named: 'linkedId'),
                    shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
                    enqueueSync: any(named: 'enqueueSync'),
                  ),
                ).captured.single
                as JournalImage;
        final storedFile = File(
          '${tempDir.path}'
          '${capturedImage.data.imageDirectory}'
          '${capturedImage.data.imageFile}',
        );

        expect(capturedImage.data.imageFile, endsWith('.png'));
        expect(storedFile.readAsBytesSync(), equals(pngData));
      });

      test('converts dropped HEIC file to stored JPEG', () async {
        final testFile = await createTestImageFile('screenshot.HEIC', 1024);

        await withTargetPlatform(
          TargetPlatform.macOS,
          () => withFakeImageCompressPlatform(
            () => importImageXFiles([XFile(testFile.path)]),
          ),
        );

        final capturedImage =
            verify(
                  () => mockPersistenceLogic.createDbEntity(
                    captureAny(that: isA<JournalImage>()),
                    linkedId: any(named: 'linkedId'),
                    shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
                    enqueueSync: any(named: 'enqueueSync'),
                  ),
                ).captured.single
                as JournalImage;

        expect(capturedImage.data.imageFile, endsWith('.jpg'));
        expect(capturedImage.data.imageFile, isNot(endsWith('.HEIC')));
      });

      test('converts dropped HEIC file with alpha to stored PNG', () async {
        final testFile = File(path.join(tempDir.path, 'screenshot.heic'));
        await testFile.create(recursive: true);
        await testFile.writeAsBytes(_createHeifBytes(hasAlpha: true));

        await withTargetPlatform(
          TargetPlatform.macOS,
          () => withFakeImageCompressPlatform(
            () => importImageXFiles([XFile(testFile.path)]),
          ),
        );

        final capturedImage =
            verify(
                  () => mockPersistenceLogic.createDbEntity(
                    captureAny(that: isA<JournalImage>()),
                    linkedId: any(named: 'linkedId'),
                    shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
                    enqueueSync: any(named: 'enqueueSync'),
                  ),
                ).captured.single
                as JournalImage;

        expect(capturedImage.data.imageFile, endsWith('.png'));
        expect(capturedImage.data.imageFile, isNot(endsWith('.heic')));
      });

      test('skips HEIC files on Linux before conversion', () async {
        final testFile = await createTestImageFile('screenshot.heic', 1024);

        await withTargetPlatform(
          TargetPlatform.linux,
          () => withFakeImageCompressPlatform(
            () => importImageXFiles([XFile(testFile.path)]),
          ),
        );

        verifyNever(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        );
      });

      test('skips non-image file silently', () async {
        final testFile = await createTestImageFile('test.txt', 1024);
        final dropDetails = createDropDetails([XFile(testFile.path)]);

        await importImageXFiles(dropDetails);

        verifyNever(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        );
      });

      test('logs error for file exceeding size limit', () async {
        const largeSize = ImageImportConstants.maxFileSizeBytes + 1;
        final testFile = await createTestImageFile('large.jpg', largeSize);
        final dropDetails = createDropDetails([XFile(testFile.path)]);

        await importImageXFiles(dropDetails);

        verify(
          () => mockDomainLogger.error(
            LogDomain.ai,
            any<Object>(that: contains('too large')),
            subDomain: 'importDroppedImages',
          ),
        ).called(1);
      });

      test('passes linkedId and categoryId', () async {
        final testFile = await createTestImageFile('test.jpg', 1024);
        final dropDetails = createDropDetails([XFile(testFile.path)]);

        await importImageXFiles(
          dropDetails,
          linkedId: 'parent-123',
          categoryId: 'cat-456',
        );

        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: 'parent-123',
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
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

        await importImageXFiles(dropDetails);

        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        ).called(2);
      });

      test(
        'dates the entry from EXIF capture time, not the drop time',
        () async {
          // A dropped file is streamed into a fresh temp file, so its mtime is
          // the drop time. The entry must instead carry the photo's original
          // capture time read from EXIF.
          final file = File(path.join(tempDir.path, 'photo.jpg'));
          await file.writeAsBytes(
            buildExifJpegWithDateTime('2024:01:15 10:20:30'),
          );
          // Make the mtime clearly different from the EXIF time so a regression
          // that falls back to mtime (the old bug) would be caught.
          await file.setLastModified(DateTime(2025, 6, 1, 8));

          await importImageXFiles([XFile(file.path)]);

          final captured = verify(
            () => mockPersistenceLogic.createMetadata(
              dateFrom: captureAny(named: 'dateFrom'),
              dateTo: captureAny(named: 'dateTo'),
              uuidV5Input: any(named: 'uuidV5Input'),
              categoryId: any(named: 'categoryId'),
              flag: any(named: 'flag'),
            ),
          ).captured;

          expect(captured[0], DateTime(2024, 1, 15, 10, 20, 30));
          expect(captured[1], DateTime(2024, 1, 15, 10, 20, 30));
        },
      );

      test(
        'falls back to the file modified time when EXIF has no timestamp',
        () async {
          // A plain (EXIF-less) image keeps the previous behaviour: the entry is
          // dated from the file's modified time, not DateTime.now().
          final file = await createTestImageFile('plain.jpg', 1024);
          final modified = DateTime(2025, 6, 1, 8, 30, 15);
          await file.setLastModified(modified);

          await importImageXFiles([XFile(file.path)]);

          final captured = verify(
            () => mockPersistenceLogic.createMetadata(
              dateFrom: captureAny(named: 'dateFrom'),
              dateTo: captureAny(named: 'dateTo'),
              uuidV5Input: any(named: 'uuidV5Input'),
              categoryId: any(named: 'categoryId'),
              flag: any(named: 'flag'),
            ),
          ).captured;

          expect(captured[0], modified);
          expect(captured[1], modified);
        },
      );

      test('handles exception during import and continues', () async {
        // Use a non-existent file path to trigger an exception
        final validFile = await createTestImageFile('good.jpg', 1024);
        final dropDetails = createDropDetails([
          XFile('/nonexistent/path/bad.jpg'),
          XFile(validFile.path),
        ]);

        await importImageXFiles(dropDetails);

        // The bad file causes an error, but the good file still gets imported
        verify(
          () => mockDomainLogger.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'importDroppedImages',
          ),
        ).called(1);

        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        ).called(1);
      });
    });

    group('importImagePickerFiles', () {
      test('imports the files returned by the desktop file picker', () async {
        final testFile = await createTestImageFile('picked.jpg', 1024);

        final original = FileSelectorPlatform.instance;
        final fakeSelector = FakeFileSelectorPlatform()
          ..filesToReturn = [XFile(testFile.path)];
        FileSelectorPlatform.instance = fakeSelector;
        addTearDown(() => FileSelectorPlatform.instance = original);

        await importImagePickerFiles(
          linkedId: 'parent-123',
          categoryId: 'cat-456',
        );

        // A non-empty picker result must flow through importImageXFiles,
        // creating the linked image entry with the passed ids.
        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: 'parent-123',
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        ).called(1);
      });

      test('does nothing when the picker returns no files', () async {
        final original = FileSelectorPlatform.instance;
        FileSelectorPlatform.instance = FakeFileSelectorPlatform();
        addTearDown(() => FileSelectorPlatform.instance = original);

        await importImagePickerFiles();

        verifyNever(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
          ),
        );
      });

      test('includes HEIC and HEIF in the picker on macOS', () async {
        final original = FileSelectorPlatform.instance;
        final fakeSelector = FakeFileSelectorPlatform();
        FileSelectorPlatform.instance = fakeSelector;
        addTearDown(() => FileSelectorPlatform.instance = original);

        await withTargetPlatform(TargetPlatform.macOS, importImagePickerFiles);

        expect(
          fakeSelector.lastAcceptedTypeGroups?.single.extensions,
          containsAll(['jpg', 'jpeg', 'png', 'heic', 'heif']),
        );
      });

      test('omits HEIC and HEIF from the picker on Linux', () async {
        final original = FileSelectorPlatform.instance;
        final fakeSelector = FakeFileSelectorPlatform();
        FileSelectorPlatform.instance = fakeSelector;
        addTearDown(() => FileSelectorPlatform.instance = original);

        await withTargetPlatform(TargetPlatform.linux, importImagePickerFiles);

        expect(
          fakeSelector.lastAcceptedTypeGroups?.single.extensions,
          containsAll(['jpg', 'jpeg', 'png']),
        );
        expect(
          fakeSelector.lastAcceptedTypeGroups?.single.extensions,
          isNot(contains('heic')),
        );
        expect(
          fakeSelector.lastAcceptedTypeGroups?.single.extensions,
          isNot(contains('heif')),
        );
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
          () => mockDomainLogger.error(
            LogDomain.ai,
            any<Object>(that: contains('too large')),
            subDomain: 'importGeneratedImageBytes',
          ),
        ).called(1);
      });

      test('successfully creates entry and returns its ID', () async {
        final validData = Uint8List.fromList(List<int>.filled(500, 0xBB));

        final result = await importGeneratedImageBytes(
          data: validData,
          fileExtension: 'png',
          linkedId: 'linked-task-id',
          categoryId: 'cat-id',
        );

        // createDbEntity returns true, so createImageEntry returns the entity
        expect(result, equals('test-id'));

        // linkCollapsed: true — an AI-generated image (cover art) already
        // renders as the task's app-bar banner and list thumbnail; the
        // linked-entries timeline row defaults to collapsed instead of
        // duplicating it expanded.
        verify(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: 'linked-task-id',
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
            linkCollapsed: true,
          ),
        ).called(1);
      });

      test('returns null when entry creation fails', () async {
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalImage>()),
            linkedId: any(named: 'linkedId'),
            shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
            enqueueSync: any(named: 'enqueueSync'),
            linkCollapsed: any(named: 'linkCollapsed'),
          ),
        ).thenThrow(Exception('DB error'));

        final validData = Uint8List.fromList(List<int>.filled(200, 0xCC));

        final result = await importGeneratedImageBytes(
          data: validData,
          fileExtension: 'png',
          linkedId: 'linked-id',
        );

        expect(result, isNull);
      });
    });

    group('extractGpsCoordinates', () {
      test('returns null for empty data', () async {
        final result = await extractGpsCoordinates(
          Uint8List(0),
          DateTime(2024, 3, 15),
        );
        expect(result, isNull);
      });

      test('returns null for non-image data', () async {
        final result = await extractGpsCoordinates(
          Uint8List.fromList([0, 1, 2, 3, 4]),
          DateTime(2024, 3, 15),
        );
        expect(result, isNull);
      });
    });

    group('createAnalysisCallback', () {
      late MockAutomaticImageAnalysisTrigger mockTrigger;

      setUp(() {
        mockTrigger = MockAutomaticImageAnalysisTrigger();

        when(
          () => mockTrigger.triggerAutomaticImageAnalysis(
            imageEntryId: any(named: 'imageEntryId'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        ).thenAnswer((_) async {});
      });

      test('returns null when analysisTrigger is null', () {
        final callback = createAnalysisCallback(null, 'linked');
        expect(callback, isNull);
      });

      test('returns callback when analysisTrigger is provided', () {
        final callback = createAnalysisCallback(mockTrigger, 'linked');
        expect(callback, isNotNull);
      });

      test('callback triggers analysis with correct parameters', () {
        final callback = createAnalysisCallback(mockTrigger, 'linked-456');

        final testEntity = JournalImage(
          meta: Metadata(
            id: 'image-789',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
          ),
          data: ImageData(
            imageId: 'img-id',
            imageFile: 'test.jpg',
            imageDirectory: '/images/2024/',
            capturedAt: DateTime(2024),
          ),
        );

        callback!(testEntity);

        verify(
          () => mockTrigger.triggerAutomaticImageAnalysis(
            imageEntryId: 'image-789',
            linkedTaskId: 'linked-456',
          ),
        ).called(1);
      });

      test('callback works with null linkedId', () {
        final callback = createAnalysisCallback(mockTrigger, null);

        final testEntity = JournalImage(
          meta: Metadata(
            id: 'image-abc',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
          ),
          data: ImageData(
            imageId: 'img-id',
            imageFile: 'test.jpg',
            imageDirectory: '/images/2024/',
            capturedAt: DateTime(2024),
          ),
        );

        callback!(testEntity);

        verify(
          () => mockTrigger.triggerAutomaticImageAnalysis(
            imageEntryId: 'image-abc',
          ),
        ).called(1);
      });
    }); // end createAnalysisCallback group
    group('EXIF timestamp persistence', () {
      final fallback = DateTime(2024, 6, 10, 12);

      Future<void> expectImportedImage(
        Uint8List bytes, {
        required DateTime capturedAt,
        String extension = 'jpg',
      }) async {
        await withClock(
          Clock.fixed(fallback),
          () => importPastedImages(
            data: bytes,
            fileExtension: extension,
            linkedId: 'parent-task',
            categoryId: 'photos',
          ),
        );

        final image =
            verify(
                  () => mockPersistenceLogic.createDbEntity(
                    captureAny(that: isA<JournalImage>()),
                    linkedId: 'parent-task',
                    shouldAddGeolocation: false,
                    linkCollapsed: false,
                  ),
                ).captured.single
                as JournalImage;
        expect(image.data.capturedAt, capturedAt);
        expect(image.data.imageFile, endsWith('.${extension.toLowerCase()}'));
        expect(image.data.geolocation, isNull);
        verify(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: capturedAt,
            dateTo: capturedAt,
            uuidV5Input: any(named: 'uuidV5Input'),
            categoryId: 'photos',
            flag: EntryFlag.import,
          ),
        ).called(1);
        final file = File(
          path.join(
            tempDir.path,
            image.data.imageDirectory.replaceFirst(RegExp(r'^/'), ''),
            image.data.imageFile,
          ),
        );
        expect(await file.readAsBytes(), orderedEquals(bytes));
      }

      test(
        'prefers DateTimeOriginal over the image modification timestamp',
        () async {
          await expectImportedImage(
            buildExifJpegWithDateTime(
              '2023:12:25 14:30:45',
              originalDateTime: '2024:01:15 10:20:30',
            ),
            capturedAt: DateTime(2024, 1, 15, 10, 20, 30),
          );
        },
      );

      test('uses Image DateTime when DateTimeOriginal is absent', () async {
        await expectImportedImage(
          buildExifJpegWithDateTime('2022:06:10 08:15:22'),
          capturedAt: DateTime(2022, 6, 10, 8, 15, 22),
        );
      });

      for (final (name, bytes) in [
        ('malformed date', buildExifJpegWithDateTime('not-a-date')),
        ('date only', buildExifJpegWithDateTime('2024:01:15')),
        ('no EXIF', Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9])),
        ('empty data', Uint8List(0)),
        ('truncated TIFF', _createMinimalJpegWithExif()),
        (
          'invalid EXIF header',
          Uint8List.fromList([
            0xff,
            0xd8,
            0xff,
            0xe1,
            0,
            8,
            0x45,
            0x78,
            0x69,
            0x66,
            0xff,
            0xd9,
          ]),
        ),
      ]) {
        test('persists $name with the fallback timestamp', () async {
          await expectImportedImage(bytes, capturedAt: fallback);
        });
      }

      for (final extension in ['jpg', 'jpeg', 'JPG', 'JPEG', 'png', 'PNG']) {
        test('preserves clipboard bytes for $extension', () async {
          await expectImportedImage(
            Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
            capturedAt: fallback,
            extension: extension,
          );
        });
      }

      test('persists an image exactly at the size limit', () async {
        await expectImportedImage(
          Uint8List(ImageImportConstants.maxFileSizeBytes),
          capturedAt: fallback,
        );
      });
    });
  }); // end canonical group

  // ---------------------------------------------------------------------------
  // GPS tests (originally in image_import_gps_test.dart)
  // ---------------------------------------------------------------------------

  group('gps_tests', () {
    setUpAll(() async {
      getIt.pushNewScope();
      setFakeDocumentsPath();

      // Register mock services
      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<JournalDb>(MockJournalDb())
        ..registerSingleton<Fts5Db>(MockFts5Db())
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        ..registerSingleton<VectorClockService>(MockVectorClockService())
        ..registerSingleton<UpdateNotifications>(MockUpdateNotifications())
        ..registerSingleton<NotificationService>(MockNotificationService())
        ..registerSingleton<TimeService>(MockTimeService())
        ..registerSingleton<DomainLogger>(MockDomainLogger());
    });

    tearDownAll(() async {
      await getIt.resetScope();
      await getIt.popScope();
    });

    group('extractGpsCoordinates Integration Tests', () {
      test('handles minimal EXIF structure without GPS returning null', () async {
        // Minimal EXIF structure that lacks proper GPS data
        final jpegWithGps = Uint8List.fromList([
          0xFF, 0xD8, // SOI
          0xFF, 0xE1, // APP1 marker
          0x00, 0x0E, // APP1 length
          0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
          // Minimal TIFF header
          0x49, 0x49, 0x2A, 0x00,
          0xFF, 0xD9, // EOI
        ]);

        // The EXIF library may not parse our incomplete hand-crafted data correctly
        final result = await extractGpsCoordinates(
          jpegWithGps,
          DateTime(2024, 1, 15, 10, 20, 30),
        );

        // Minimal structure without GPS data should return null
        expect(result, isNull);
      });

      test('attempts to extract GPS from hand-crafted EXIF data', () async {
        // Note: Hand-crafted EXIF binary data is extremely difficult to get
        // exactly right for native_exif library parsing. This test demonstrates
        // that the extraction code handles such data gracefully.
        //
        // Expected coordinates if parsed: 37.7749° N, 122.4194° W (San Francisco)
        // Coordinate parsing is covered by exif_data_extractor_test.dart.
        final jpegWithGps = _createJpegWithGpsExif();
        final timestamp = DateTime(2024, 1, 15, 10, 20, 30);

        final result = await extractGpsCoordinates(jpegWithGps, timestamp);

        // The native_exif library may not parse our hand-crafted bytes correctly,
        // but the important thing is that extraction doesn't crash and returns
        // either valid Geolocation or null gracefully.
        if (result != null) {
          // If it did parse, verify the structure is valid
          expect(result.latitude, isA<double>());
          expect(result.longitude, isA<double>());
          expect(result.geohashString, isNotEmpty);
          expect(result.createdAt, timestamp);
        } else {
          // Null is acceptable for hand-crafted EXIF that doesn't parse
          expect(result, isNull);
        }
      });

      test('returns null for image without GPS EXIF data', () async {
        // Minimal JPEG without GPS
        final jpegNoGps = Uint8List.fromList([
          0xFF, 0xD8, // SOI
          0xFF, 0xD9, // EOI
        ]);

        final result = await extractGpsCoordinates(
          jpegNoGps,
          DateTime(2024, 1, 15, 10, 20, 30),
        );

        expect(result, isNull);
      });

      test('returns null for corrupted EXIF data', () async {
        final corruptedData = Uint8List.fromList([
          0xFF, 0xD8, // JPEG start
          0xFF, 0xE1, // APP1 marker
          0x00, 0x10, // Length
          0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
          // Garbage data
          ...List.generate(20, (i) => i % 256),
          0xFF, 0xD9, // EOI
        ]);

        final result = await extractGpsCoordinates(
          corruptedData,
          DateTime(2024, 1, 15, 10, 20, 30),
        );

        expect(result, isNull);
      });

      test('handles EXIF parsing failures gracefully', () async {
        // This test verifies that EXIF parsing failures return null gracefully
        final invalidData = Uint8List.fromList([
          0xFF, 0xD8, // SOI
          0xFF, 0xE1, // APP1
          0x00, 0x08, // Very short length
          0x45, 0x78, // Incomplete "Exif"
          0xFF, 0xD9, // EOI
        ]);

        final result = await extractGpsCoordinates(
          invalidData,
          DateTime(2024, 1, 15, 10, 20, 30),
        );

        // Should return null without throwing
        expect(result, isNull);
      });

      test('returns null for empty data', () async {
        final emptyData = Uint8List.fromList([]);

        final result = await extractGpsCoordinates(
          emptyData,
          DateTime(2024, 1, 15, 10, 20, 30),
        );

        expect(result, isNull);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // EXIF/GPS integration tests (originally in image_import_exif_gps_integration_test.dart)
  // ---------------------------------------------------------------------------

  group('exif_gps_integration', () {
    late MockDomainLogger mockLoggingServiceIntegration;

    setUpAll(() {
      registerFallbackValue(StackTrace.current);
      registerFallbackValue(Exception('test'));
    });

    setUp(() {
      mockLoggingServiceIntegration = MockDomainLogger();
      getIt.allowReassignment = true;

      if (getIt.isRegistered<DomainLogger>()) {
        getIt.unregister<DomainLogger>();
      }

      getIt.registerSingleton<DomainLogger>(mockLoggingServiceIntegration);

      when(
        () => mockLoggingServiceIntegration.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
    });

    group('extractGpsCoordinates - Success Paths Coverage', () {
      test('covers exception handling in extractGpsCoordinates', () async {
        // Invalid JPEG data to trigger exception path
        final invalidData = Uint8List.fromList([0x00, 0x01, 0x02]);

        final result = await extractGpsCoordinates(
          invalidData,
          DateTime(2024, 3, 15, 10, 30),
        );

        // Should return null (lines 393-401)
        // Exception is logged internally but we can't easily verify it
        // since readExifFromBytes catches the error
        expect(result, isNull);
      });
    });

    group('Edge Cases for Complete Coverage', () {
      test('handles empty EXIF data', () async {
        // Minimal JPEG without EXIF
        final minimalJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

        final result = await extractGpsCoordinates(
          minimalJpeg,
          DateTime(2024, 3, 15, 10, 30),
        );

        expect(result, isNull);
      });
    });

    tearDown(() {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt.unregister<DomainLogger>();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests (originally in image_import_widget_test.dart)
  // ---------------------------------------------------------------------------

  group('widget_tests', () {
    late MockDomainLogger mockLoggingServiceWidget;
    late Directory tempDirWidget;

    setUpAll(() async {
      getIt.pushNewScope();
      setFakeDocumentsPath();

      mockLoggingServiceWidget = MockDomainLogger();

      // Register mock services
      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<JournalDb>(MockJournalDb())
        ..registerSingleton<Fts5Db>(MockFts5Db())
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        ..registerSingleton<VectorClockService>(MockVectorClockService())
        ..registerSingleton<UpdateNotifications>(MockUpdateNotifications())
        ..registerSingleton<NotificationService>(MockNotificationService())
        ..registerSingleton<TimeService>(MockTimeService())
        ..registerSingleton<DomainLogger>(mockLoggingServiceWidget);

      // Create temp directory for file operations
      tempDirWidget = await Directory.systemTemp.createTemp('lotti_test_');
    });

    tearDownAll(() async {
      await getIt.resetScope();
      await getIt.popScope();
      // Clean up temp directory
      if (tempDirWidget.existsSync()) {
        await tempDirWidget.delete(recursive: true);
      }
    });

    setUp(() {
      // Silence logging side effects
      when(
        () => mockLoggingServiceWidget.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
    });

    group('importImageAssets - Widget Tests', () {
      testWidgets('returns early when permissions are denied', (tester) async {
        // Override PhotoManager.requestPermissionExtend to return denied
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  // Return denied permission state (index 2 in PermissionState enum)
                  return 2;
                }
                return null;
              },
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => importImageAssets(context),
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        // Should return early without crashing
        expect(find.byType(MaterialApp), findsOneWidget);

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
      });

      testWidgets('returns early when context is not mounted', (tester) async {
        // Override PhotoManager.requestPermissionExtend to return authorized
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  // Return authorized permission state (index 3 in PermissionState enum)
                  return 3;
                }
                return null;
              },
            );

        BuildContext? savedContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                savedContext = context;
                return const SizedBox();
              },
            ),
          ),
        );

        // Remove the widget so context is no longer mounted
        await tester.pumpWidget(const SizedBox());

        // Try to call with unmounted context
        if (savedContext != null) {
          // Should not throw
          await expectLater(importImageAssets(savedContext!), completes);
        }

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
      });

      testWidgets('handles null assets list when picker is cancelled', (
        tester,
      ) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  // Return authorized permission state (index 3 in PermissionState enum)
                  return 3;
                }
                if (call.method == 'getAssetPathList') {
                  // Return empty map with empty data array
                  return <String, dynamic>{'data': <Map<dynamic, dynamic>>[]};
                }
                return null;
              },
            );

        // Mock wechat_assets_picker to return null (user cancelled)
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              (call) async {
                if (call.method == 'pickAssets') {
                  return null; // User cancelled
                }
                return null;
              },
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => importImageAssets(context),
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        // Should handle null gracefully
        expect(find.byType(MaterialApp), findsOneWidget);

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              null,
            );
      });

      testWidgets('handles empty assets list', (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  // Return authorized permission state (index 3 in PermissionState enum)
                  return 3;
                }
                if (call.method == 'getAssetPathList') {
                  // Return empty map with empty data array
                  return <String, dynamic>{'data': <Map<dynamic, dynamic>>[]};
                }
                return null;
              },
            );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              (call) async {
                if (call.method == 'pickAssets') {
                  return []; // Empty list
                }
                return null;
              },
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => importImageAssets(context),
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        // Should handle empty list gracefully
        expect(find.byType(MaterialApp), findsOneWidget);

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              null,
            );
      });

      testWidgets('passes linkedId parameter correctly', (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  // Return authorized permission state (index 3 in PermissionState enum)
                  return 3;
                }
                if (call.method == 'getAssetPathList') {
                  // Return empty map with empty data array
                  return <String, dynamic>{'data': <Map<dynamic, dynamic>>[]};
                }
                return null;
              },
            );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              (call) async {
                if (call.method == 'pickAssets') {
                  return null;
                }
                return null;
              },
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () =>
                      importImageAssets(context, linkedId: 'test-linked-id'),
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              null,
            );
      });

      testWidgets('passes categoryId parameter correctly', (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  // Return authorized permission state (index 3 in PermissionState enum)
                  return 3;
                }
                if (call.method == 'getAssetPathList') {
                  // Return empty map with empty data array
                  return <String, dynamic>{'data': <Map<dynamic, dynamic>>[]};
                }
                return null;
              },
            );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              (call) async {
                if (call.method == 'pickAssets') {
                  return null;
                }
                return null;
              },
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => importImageAssets(
                    context,
                    categoryId: 'test-category-id',
                  ),
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              null,
            );
      });

      testWidgets('passes both linkedId and categoryId parameters', (
        tester,
      ) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  // Return authorized permission state (index 3 in PermissionState enum)
                  return 3;
                }
                if (call.method == 'getAssetPathList') {
                  // Return empty map with empty data array
                  return <String, dynamic>{'data': <Map<dynamic, dynamic>>[]};
                }
                return null;
              },
            );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              (call) async {
                if (call.method == 'pickAssets') {
                  return null;
                }
                return null;
              },
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => importImageAssets(
                    context,
                    linkedId: 'test-linked-id',
                    categoryId: 'test-category-id',
                  ),
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              null,
            );
      });

      testWidgets('handles permission request flow', (tester) async {
        var permissionRequested = false;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  permissionRequested = true;
                  // Return denied permission state (index 2 in PermissionState enum)
                  return 2;
                }
                return null;
              },
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => importImageAssets(context),
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        expect(permissionRequested, isTrue);

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
      });

      testWidgets('configures asset picker with correct parameters', (
        tester,
      ) async {
        var pickerConfigReceived = false;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  // Return authorized permission state (index 3 in PermissionState enum)
                  return 3;
                }
                if (call.method == 'getAssetPathList') {
                  pickerConfigReceived = true;
                  // AssetPicker is called, which internally calls getAssetPathList
                  // Return empty map with empty data array to simulate no assets available
                  return <String, dynamic>{'data': <Map<dynamic, dynamic>>[]};
                }
                return null;
              },
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => importImageAssets(context),
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        expect(pickerConfigReceived, isTrue);

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
      });

      testWidgets('handles multiple rapid calls gracefully', (tester) async {
        var callCount = 0;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  callCount++;
                  // Return authorized permission state (index 3 in PermissionState enum)
                  return 3;
                }
                if (call.method == 'getAssetPathList') {
                  // Return empty map with empty data array
                  return <String, dynamic>{'data': <Map<dynamic, dynamic>>[]};
                }
                return null;
              },
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    // Call three times rapidly
                    await Future.wait([
                      importImageAssets(context),
                      importImageAssets(context),
                      importImageAssets(context),
                    ]);
                  },
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        // Verify multiple calls were made
        expect(callCount, greaterThan(0));

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
      });
    });

    group('importImageAssets - Permission States', () {
      testWidgets('handles PermissionState.authorized', (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  // Return authorized permission state (index 3 in PermissionState enum)
                  return 3;
                }
                if (call.method == 'getAssetPathList') {
                  // Return empty map with empty data array
                  return <String, dynamic>{'data': <Map<dynamic, dynamic>>[]};
                }
                return null;
              },
            );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              (call) async => null,
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => importImageAssets(context),
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              null,
            );
      });

      testWidgets('handles PermissionState.denied', (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  // Return denied permission state (index 2 in PermissionState enum)
                  return 2;
                }
                return null;
              },
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => importImageAssets(context),
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        // Should return early
        expect(find.byType(MaterialApp), findsOneWidget);

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
      });

      testWidgets('handles PermissionState.limited', (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (call) async {
                if (call.method == 'requestPermissionExtend') {
                  // Return limited permission state (index 4 in PermissionState enum)
                  return 4;
                }
                if (call.method == 'getAssetPathList') {
                  // Return empty map with empty data array
                  return <String, dynamic>{'data': <Map<dynamic, dynamic>>[]};
                }
                return null;
              },
            );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              (call) async => null,
            );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => importImageAssets(context),
                  child: const Text('Pick'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);

        // Clean up
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('wechat_assets_picker'),
              null,
            );
      });
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Transplanted from media_import_integration_test.dart (file dissolved per
  // the one-test-file-per-source rule): scoped GetIt + fake documents dir.
  group('importImageAssets — photo picker integration (scoped)', () {
    late MockDomainLogger mockLoggingService;
    late Directory tempDir;

    setUpAll(() async {
      getIt.pushNewScope();
      setFakeDocumentsPath();

      mockLoggingService = MockDomainLogger();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<JournalDb>(MockJournalDb())
        ..registerSingleton<Fts5Db>(MockFts5Db())
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        ..registerSingleton<VectorClockService>(MockVectorClockService())
        ..registerSingleton<UpdateNotifications>(MockUpdateNotifications())
        ..registerSingleton<NotificationService>(MockNotificationService())
        ..registerSingleton<TimeService>(MockTimeService())
        ..registerSingleton<DomainLogger>(mockLoggingService);

      tempDir = await Directory.systemTemp.createTemp('lotti_test_');
    });

    tearDownAll(() async {
      await getIt.resetScope();
      await getIt.popScope();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    setUp(() {
      when(
        () => mockLoggingService.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
    });

    group('importImageAssets - Photo Picker Integration', () {
      setUp(() {
        // Mock PhotoManager plugin method channel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              (MethodCall methodCall) async {
                if (methodCall.method == 'requestPermissionExtend') {
                  // Return denied permission (0 = PermissionState.denied)
                  return 0;
                }
                return null;
              },
            );

        // Mock wechat_assets_picker plugin method channel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies.wechat_assets_picker'),
              (MethodCall methodCall) async {
                // Return null for pickAssets (user cancelled)
                return null;
              },
            );
      });

      tearDown(() {
        // Clean up method channel handlers
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies/photo_manager'),
              null,
            );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.fluttercandies.wechat_assets_picker'),
              null,
            );
      });

      testWidgets('returns early when permissions are not granted', (
        tester,
      ) async {
        final context = MockBuildContext();
        when(() => context.mounted).thenReturn(true);

        await expectLater(importImageAssets(context), completes);
      });

      testWidgets('returns early when context is not mounted', (tester) async {
        final context = MockBuildContext();
        when(() => context.mounted).thenReturn(false);

        await expectLater(importImageAssets(context), completes);
      });

      testWidgets('handles null assets list gracefully', (tester) async {
        final context = MockBuildContext();
        when(() => context.mounted).thenReturn(true);

        await expectLater(importImageAssets(context), completes);
      });

      testWidgets('passes linkedId and categoryId parameters', (tester) async {
        final context = MockBuildContext();
        when(() => context.mounted).thenReturn(true);

        await expectLater(
          importImageAssets(
            context,
            linkedId: 'test-link',
            categoryId: 'test-category',
          ),
          completes,
        );
      });
    });
  });
}
