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
  });

  group('getRelativeImagePath', () {
    test('should return the correct relative image path', () {
      final now = DateTime.now();
      final imageData = ImageData(
        imageId: '123',
        imageFile: 'image.jpg',
        imageDirectory: '/images/',
        capturedAt: now,
      );
      final metadata = Metadata(
        id: '1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      );
      final journalImage = JournalImage(meta: metadata, data: imageData);
      const expectedPath = '/images/image.jpg';
      expect(getRelativeImagePath(journalImage), expectedPath);
    });
  });

  group('getFullImagePath', () {
    test('should return the correct full image path', () {
      final now = DateTime.now();
      final imageData = ImageData(
        imageId: '123',
        imageFile: 'image.jpg',
        imageDirectory: '/images/',
        capturedAt: now,
      );
      final metadata = Metadata(
        id: '1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
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
