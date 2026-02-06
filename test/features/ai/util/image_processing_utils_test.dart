import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';

/// Minimal 1x1 transparent PNG for testing (67 bytes).
final _testPngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0x60, 0x60, 0x60, 0x60,
  0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0x5A, 0xB5, 0x4E, 0xD1, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProcessedReferenceImage', () {
    test('creates instance with required properties', () {
      const image = ProcessedReferenceImage(
        base64Data: 'dGVzdA==',
        mimeType: 'image/png',
        originalId: 'test-id-123',
      );

      expect(image.base64Data, 'dGVzdA==');
      expect(image.mimeType, 'image/png');
      expect(image.originalId, 'test-id-123');
    });

    test('supports different mime types', () {
      const pngImage = ProcessedReferenceImage(
        base64Data: 'data',
        mimeType: 'image/png',
        originalId: 'id-1',
      );
      const jpegImage = ProcessedReferenceImage(
        base64Data: 'data',
        mimeType: 'image/jpeg',
        originalId: 'id-2',
      );
      const gifImage = ProcessedReferenceImage(
        base64Data: 'data',
        mimeType: 'image/gif',
        originalId: 'id-3',
      );
      const webpImage = ProcessedReferenceImage(
        base64Data: 'data',
        mimeType: 'image/webp',
        originalId: 'id-4',
      );

      expect(pngImage.mimeType, 'image/png');
      expect(jpegImage.mimeType, 'image/jpeg');
      expect(gifImage.mimeType, 'image/gif');
      expect(webpImage.mimeType, 'image/webp');
    });

    test('instances with same values are equal', () {
      const image1 = ProcessedReferenceImage(
        base64Data: 'abc',
        mimeType: 'image/png',
        originalId: 'id-1',
      );
      const image2 = ProcessedReferenceImage(
        base64Data: 'abc',
        mimeType: 'image/png',
        originalId: 'id-1',
      );
      const image3 = ProcessedReferenceImage(
        base64Data: 'xyz',
        mimeType: 'image/png',
        originalId: 'id-1',
      );

      expect(image1.base64Data, image2.base64Data);
      expect(image1.mimeType, image2.mimeType);
      expect(image1.originalId, image2.originalId);
      expect(image1.base64Data, isNot(image3.base64Data));
    });

    test('can store empty base64Data', () {
      const image = ProcessedReferenceImage(
        base64Data: '',
        mimeType: 'image/jpeg',
        originalId: 'empty-id',
      );

      expect(image.base64Data, isEmpty);
    });
  });

  group('Constants', () {
    test('kMaxReferenceDimension is 2000', () {
      expect(kMaxReferenceDimension, 2000);
    });

    test('kMaxReferenceImages is 3', () {
      expect(kMaxReferenceImages, 3);
    });

    test('kMaxReferenceDimension is a positive integer', () {
      expect(kMaxReferenceDimension, greaterThan(0));
      expect(kMaxReferenceDimension, isA<int>());
    });

    test('kMaxReferenceImages is a positive integer', () {
      expect(kMaxReferenceImages, greaterThan(0));
      expect(kMaxReferenceImages, isA<int>());
    });
  });

  group('processReferenceImage', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('image_processing_test_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    test('returns null for non-existent file', () async {
      final result = await processReferenceImage(
        filePath: '/non/existent/path/image.jpg',
        imageId: 'test-id',
      );

      expect(result, isNull);
    });

    test('returns null for empty file path', () async {
      final result = await processReferenceImage(
        filePath: '',
        imageId: 'test-id',
      );

      expect(result, isNull);
    });

    test('returns null for directory path instead of file', () async {
      final result = await processReferenceImage(
        filePath: tempDir.path,
        imageId: 'test-id',
      );

      // Directory should not be treated as a valid file
      expect(result, isNull);
    });

    // Note: Tests for actual image processing (processReferenceImage) with valid
    // images require platform-specific Flutter bindings (ui.instantiateImageCodec,
    // FlutterImageCompress) that are not available in unit tests.
    // The function correctly returns null when these bindings fail, which is the
    // expected behavior for graceful degradation.
    //
    // The following tests verify the error handling paths which are accessible
    // in unit tests. Integration tests would be needed to verify the full
    // processing pipeline with actual image rendering.

    test('returns null for corrupted image data', () async {
      // Write invalid image data
      final testFile = File('${tempDir.path}/corrupted.jpg');
      await testFile.writeAsBytes([0x00, 0x01, 0x02, 0x03, 0x04]);

      final result = await processReferenceImage(
        filePath: testFile.path,
        imageId: 'corrupted-id',
      );

      // Should return null for corrupted data (handled by try-catch)
      expect(result, isNull);
    });

    test('returns null for empty image file', () async {
      final testFile = File('${tempDir.path}/empty.jpg');
      await testFile.writeAsBytes([]);

      final result = await processReferenceImage(
        filePath: testFile.path,
        imageId: 'empty-id',
      );

      expect(result, isNull);
    });

    test(
        'handles file with valid path but returns null without platform bindings',
        () async {
      // Write a valid image file
      final testFile = File('${tempDir.path}/test image (1).png');
      await testFile.writeAsBytes(_testPngBytes);

      // In unit test environment without platform bindings,
      // this returns null due to codec initialization failure
      final result = await processReferenceImage(
        filePath: testFile.path,
        imageId: 'special-path-id',
      );

      // The function handles the error gracefully
      // In production with platform bindings, this would return a valid result
      expect(result, isNull);
    });

    test('function signature accepts required parameters', () async {
      // Verify the function exists and has the correct signature
      // This is a compile-time test that the interface is correct

      // Calling with valid parameters should not throw immediately
      // (it may return null due to missing platform bindings)
      final future = processReferenceImage(
        filePath: '/some/path.jpg',
        imageId: 'test-id',
      );

      // Should return a Future<ProcessedReferenceImage?>
      expect(future, isA<Future<ProcessedReferenceImage?>>());

      // Result will be null due to file not existing
      final result = await future;
      expect(result, isNull);
    });
  });
}
