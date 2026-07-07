import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
import 'package:lotti/features/journal/util/image_export_service.dart';

import '../../../mocks/mocks.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  group('saveImageViaDialog', () {
    late Directory tempDir;
    late File sourceFile;
    late FakeFileSelectorPlatform fakeSelector;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('image_export_dialog_');
      sourceFile = File('${tempDir.path}/photo.png')
        ..writeAsBytesSync([1, 2, 3, 4]);
      fakeSelector = FakeFileSelectorPlatform();
      FileSelectorPlatform.instance = fakeSelector;
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors.
      }
    });

    test(
      'copies the image to the chosen location and returns its name',
      () async {
        final destination = Directory('${tempDir.path}/out')..createSync();
        final target = '${destination.path}/renamed.png';
        fakeSelector.saveLocationToReturn = FileSaveLocation(target);

        final result = await saveImageViaDialog(sourceFile);

        expect(result.status, ImageExportStatus.savedToFile);
        expect(result.savedName, 'renamed.png');
        expect(File(target).readAsBytesSync(), [1, 2, 3, 4]);
        // The panel is seeded with the source name and scoped to its extension.
        expect(fakeSelector.lastSuggestedName, 'photo.png');
        expect(fakeSelector.lastAcceptedTypeGroups, hasLength(1));
        expect(fakeSelector.lastAcceptedTypeGroups!.single.extensions, ['png']);
      },
    );

    test('returns cancelled when the user dismisses the save panel', () async {
      fakeSelector.saveLocationToReturn = null;

      final result = await saveImageViaDialog(sourceFile);

      expect(result.status, ImageExportStatus.cancelled);
      expect(result.savedName, isNull);
    });
  });

  group('saveImageToGallery', () {
    const channel = MethodChannel('gal');
    late Directory tempDir;
    late File sourceFile;
    late List<MethodCall> invocations;
    late bool hasAccessResult;
    late bool requestAccessResult;
    PlatformException? putImageError;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('image_export_gallery_');
      sourceFile = File('${tempDir.path}/photo.png')
        ..writeAsBytesSync([1, 2, 3, 4]);
      invocations = [];
      hasAccessResult = true;
      requestAccessResult = true;
      putImageError = null;

      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        invocations.add(call);
        switch (call.method) {
          case 'hasAccess':
            return hasAccessResult;
          case 'requestAccess':
            return requestAccessResult;
          case 'putImage':
            final error = putImageError;
            if (error != null) {
              throw error;
            }
            return null;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors.
      }
    });

    test('saves to the gallery when access is already granted', () async {
      final result = await saveImageToGallery(sourceFile);

      expect(result.status, ImageExportStatus.savedToGallery);
      final putImage = invocations.firstWhere((c) => c.method == 'putImage');
      expect((putImage.arguments as Map)['path'], sourceFile.path);
    });

    test('requests access first when not yet granted, then saves', () async {
      hasAccessResult = false;

      final result = await saveImageToGallery(sourceFile);

      expect(result.status, ImageExportStatus.savedToGallery);
      expect(invocations.map((c) => c.method), contains('requestAccess'));
      expect(invocations.map((c) => c.method), contains('putImage'));
    });

    test('returns permissionDenied when access is refused', () async {
      hasAccessResult = false;
      requestAccessResult = false;

      final result = await saveImageToGallery(sourceFile);

      expect(result.status, ImageExportStatus.permissionDenied);
      // Access was refused, so nothing is written to the library.
      expect(invocations.map((c) => c.method), isNot(contains('putImage')));
    });

    test('maps a gal accessDenied error to permissionDenied', () async {
      putImageError = PlatformException(code: 'ACCESS_DENIED');

      final result = await saveImageToGallery(sourceFile);

      expect(result.status, ImageExportStatus.permissionDenied);
    });

    test('rethrows non-permission gal errors', () async {
      putImageError = PlatformException(code: 'NOT_ENOUGH_SPACE');

      await expectLater(
        saveImageToGallery(sourceFile),
        throwsA(isA<GalException>()),
      );
    });
  });
}
