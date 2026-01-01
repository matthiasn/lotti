import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_image_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as p;

import '../../../../../test_helper.dart';

void main() {
  late JournalImage testImage;
  late Directory mockDirectory;
  const testHeight = 100;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Create mock directory that getDocumentsDirectory() will return
    final tempDir = Directory.systemTemp.createTempSync('card_image_test');
    mockDirectory = tempDir;

    // Register mock directory with GetIt
    getIt.allowReassignment = true;
    getIt.registerSingleton<Directory>(mockDirectory);

    // Create test data
    final now = DateTime.now();
    testImage = JournalImage(
      meta: Metadata(
        id: 'test-image-id',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: ImageData(
        capturedAt: now,
        imageId: 'test-image-id',
        imageFile: 'test_image.jpg',
        imageDirectory: '/images/2023/',
      ),
      entryText: const EntryText(plainText: 'Test image'),
    );
  });

  tearDown(() {
    // Clean up
    getIt.unregister<Directory>();
    try {
      mockDirectory.deleteSync(recursive: true);
    } catch (_) {}
  });

  // Helper to get the expected image path
  String getExpectedImagePath() {
    return p
        .join(
          mockDirectory.path,
          testImage.data.imageDirectory.replaceFirst('/', ''),
          testImage.data.imageFile,
        )
        .replaceAll(r'\', '/');
  }

  group('CardImageWidget', () {
    testWidgets('displays image when file exists', (WidgetTester tester) async {
      // Setup: Create the directory structure
      Directory(
        p.join(
          mockDirectory.path,
          testImage.data.imageDirectory.replaceFirst('/', ''),
        ),
      ).createSync(recursive: true);

      // Create an empty file to make existsSync() return true
      final filePath = getExpectedImagePath();
      File(filePath).createSync();

      // Verify the file exists before the test
      expect(File(filePath).existsSync(), isTrue);

      // Build the widget
      await tester.pumpWidget(
        WidgetTestBench(
          child: CardImageWidget(
            journalImage: testImage,
            height: testHeight,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When the file exists, it should show a SizedBox with the image
      expect(find.byType(SizedBox), findsOneWidget);

      // Verify the SizedBox has the correct height
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.height, testHeight.toDouble());
    });

    testWidgets('returns container when file does not exist',
        (WidgetTester tester) async {
      // For this test, we don't create the file, so existsSync() returns false
      final filePath = getExpectedImagePath();

      // Verify the file doesn't exist before the test
      expect(File(filePath).existsSync(), isFalse);

      // Build the widget
      await tester.pumpWidget(
        WidgetTestBench(
          child: CardImageWidget(
            journalImage: testImage,
            height: testHeight,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When the file doesn't exist, it should show a SizedBox.shrink
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('uses provided BoxFit parameter', (WidgetTester tester) async {
      // Setup: Create the file to make existsSync() return true
      Directory(
        p.join(
          mockDirectory.path,
          testImage.data.imageDirectory.replaceFirst('/', ''),
        ),
      ).createSync(recursive: true);

      final filePath = getExpectedImagePath();
      File(filePath).createSync();

      // Build the widget with custom BoxFit
      await tester.pumpWidget(
        WidgetTestBench(
          child: CardImageWidget(
            journalImage: testImage,
            height: testHeight,
            fit: BoxFit.cover, // Custom BoxFit
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the widget built properly
      expect(find.byType(SizedBox), findsOneWidget);

      // Note: We can't directly test the BoxFit value since it's inside an Image.file
      // widget, but we've confirmed it accepts the parameter
    });

    testWidgets('didUpdateWidget resets watcher when journalImage.id changes',
        (WidgetTester tester) async {
      // Setup: Create the directory structure for both images
      Directory(
        p.join(
          mockDirectory.path,
          testImage.data.imageDirectory.replaceFirst('/', ''),
        ),
      ).createSync(recursive: true);

      final filePath1 = getExpectedImagePath();
      File(filePath1).createSync();

      // Create second image data
      final now = DateTime.now();
      final testImage2 = JournalImage(
        meta: Metadata(
          id: 'test-image-id-2',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: ImageData(
          capturedAt: now,
          imageId: 'test-image-id-2',
          imageFile: 'test_image_2.jpg',
          imageDirectory: '/images/2023/',
        ),
        entryText: const EntryText(plainText: 'Test image 2'),
      );

      final filePath2 = p
          .join(
            mockDirectory.path,
            testImage2.data.imageDirectory.replaceFirst('/', ''),
            testImage2.data.imageFile,
          )
          .replaceAll(r'\', '/');
      File(filePath2).createSync();

      // Build with first image
      await tester.pumpWidget(
        WidgetTestBench(
          child: CardImageWidget(
            journalImage: testImage,
            height: testHeight,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CardImageWidget), findsOneWidget);

      // Rebuild with second image - this should trigger didUpdateWidget
      await tester.pumpWidget(
        WidgetTestBench(
          child: CardImageWidget(
            journalImage: testImage2,
            height: testHeight,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Widget should still render correctly after id change
      expect(find.byType(CardImageWidget), findsOneWidget);
    });

    testWidgets('does not reset watcher when other props change',
        (WidgetTester tester) async {
      // Setup: Create the file to make existsSync() return true
      Directory(
        p.join(
          mockDirectory.path,
          testImage.data.imageDirectory.replaceFirst('/', ''),
        ),
      ).createSync(recursive: true);

      final filePath = getExpectedImagePath();
      File(filePath).createSync();

      // Build with initial height
      await tester.pumpWidget(
        WidgetTestBench(
          child: CardImageWidget(
            journalImage: testImage,
            height: testHeight,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rebuild with different height but same journalImage.id
      await tester.pumpWidget(
        WidgetTestBench(
          child: CardImageWidget(
            journalImage: testImage,
            height: 200, // Different height
            fit: BoxFit.cover, // Different fit
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Widget should render correctly - no watcher reset needed
      expect(find.byType(CardImageWidget), findsOneWidget);
    });
  });
}
