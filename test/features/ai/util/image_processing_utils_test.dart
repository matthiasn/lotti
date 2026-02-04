import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';

void main() {
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
  });

  group('Constants', () {
    test('kMaxReferenceDimension is 2000', () {
      expect(kMaxReferenceDimension, 2000);
    });

    test('kMaxReferenceImages is 3', () {
      expect(kMaxReferenceImages, 3);
    });
  });

  group('processReferenceImage', () {
    test('returns null for non-existent file', () async {
      final result = await processReferenceImage(
        filePath: '/non/existent/path/image.jpg',
        imageId: 'test-id',
      );

      expect(result, isNull);
    });
  });
}
