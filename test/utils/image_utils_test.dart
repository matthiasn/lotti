import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/image_utils.dart';

void main() {
  group('getRelativeAssetPath', () {
    test('should return the relative path on Android', () {
      const absolutePath = '/data/user/0/com.example.app/app_flutter/image.jpg';
      const expectedPath = '/image.jpg';
      expect(getRelativeAssetPath(absolutePath, isAndroid: true), expectedPath);
    });

    test('should return the relative path on other platforms', () {
      const absolutePath = '/Users/test/Documents/image.jpg';
      const expectedPath = '/image.jpg';
      expect(getRelativeAssetPath(absolutePath), expectedPath);
    });

    test('returns null when absolutePath is null', () {
      expect(getRelativeAssetPath(null), isNull);
    });

    test('returns null when absolutePath is null on Android', () {
      expect(getRelativeAssetPath(null, isAndroid: true), isNull);
    });

    test('handles path with nested Documents directory', () {
      const path = '/Users/test/Documents/Lotti/Documents/image.jpg';
      // split('Documents') returns 3 parts; .last is '/image.jpg'
      expect(getRelativeAssetPath(path), '/image.jpg');
    });

    test('handles Android path with nested app_flutter directory', () {
      const path =
          '/data/user/0/com.example.app/app_flutter/sub/app_flutter/img.jpg';
      expect(getRelativeAssetPath(path, isAndroid: true), '/img.jpg');
    });

    test('handles path with subdirectories after Documents', () {
      const path = '/Users/test/Documents/images/2024/photo.jpg';
      expect(getRelativeAssetPath(path), '/images/2024/photo.jpg');
    });
  });

  group('getRelativeImagePath', () {
    test('should return the correct relative image path', () {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final imageData = ImageData(
        imageId: '123',
        imageFile: 'image.jpg',
        imageDirectory: '/images/',
        capturedAt: testDate,
      );
      final metadata = Metadata(
        id: '1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      );
      final journalImage = JournalImage(meta: metadata, data: imageData);
      const expectedPath = '/images/image.jpg';
      expect(getRelativeImagePath(journalImage), expectedPath);
    });
  });

  group('getFullImagePath', () {
    test('should return the correct full image path', () {
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final imageData = ImageData(
        imageId: '123',
        imageFile: 'image.jpg',
        imageDirectory: '/images/',
        capturedAt: testDate,
      );
      final metadata = Metadata(
        id: '1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      );
      final journalImage = JournalImage(meta: metadata, data: imageData);
      const documentsDirectory = '/Users/test/Documents';
      const expectedPath = '/Users/test/Documents/images/image.jpg';
      expect(
        getFullImagePath(
          journalImage,
          documentsDirectory: documentsDirectory,
        ),
        expectedPath,
      );
    });
  });
}
