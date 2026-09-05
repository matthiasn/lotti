import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_image_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/thumbhash.dart';
import 'package:lotti/widgets/media/thumb_hash_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../../../../helpers/thumb_hash_fixtures.dart';
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
    final testDate = DateTime(2024, 3, 15, 10, 30);
    testImage = JournalImage(
      meta: Metadata(
        id: 'test-image-id',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: ImageData(
        capturedAt: testDate,
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

    testWidgets('returns container when file does not exist', (
      WidgetTester tester,
    ) async {
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

      // Verify the widget built properly, and that the picture wears the fit.
      expect(find.byType(SizedBox), findsOneWidget);
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    });

    group('with a ThumbHash', () {
      JournalImage withHash(String hash) => testImage.copyWith(
        data: testImage.data.copyWith(thumbHash: hash),
      );

      testWidgets('shows the stand-in in the same box while the file is '
          'missing', (tester) async {
        expect(File(getExpectedImagePath()).existsSync(), isFalse);

        await tester.pumpWidget(
          WidgetTestBench(
            child: CardImageWidget(
              journalImage: withHash(sampleThumbHash),
              height: testHeight,
            ),
          ),
        );
        await tester.pump();

        final box = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(box.width, testHeight.toDouble());
        expect(box.height, testHeight.toDouble());
        final standIn = tester.widget<Image>(find.byType(Image));
        expect(
          standIn.image,
          ThumbHashImage(ThumbHash.fromBase64(sampleThumbHash)),
        );
        // The default scaleDown would leave the 32 px raster a stamp in the
        // corner; the stand-in fills the box the way the picture will.
        expect(standIn.fit, BoxFit.contain);
      });

      testWidgets('gives the stand-in the fit it was given', (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: CardImageWidget(
              journalImage: withHash(sampleThumbHash),
              height: testHeight,
              fit: BoxFit.cover,
            ),
          ),
        );
        await tester.pump();

        expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
      });

      testWidgets('takes no space for a hash that does not parse', (
        tester,
      ) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: CardImageWidget(
              journalImage: withHash(corruptThumbHash),
              height: testHeight,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(Image), findsNothing);
        final box = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(box.width, 0);
        expect(box.height, 0);
      });
    });

    testWidgets('didUpdateWidget resets watcher when journalImage.id changes', (
      WidgetTester tester,
    ) async {
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
      final now = DateTime(2024, 3, 15, 10, 30);
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

      // The watcher reset took effect: the rendered Image now points at the
      // SECOND image's file, not the stale first path.
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image;
      final fileImage = provider is ResizeImage
          ? provider.imageProvider as FileImage
          : provider as FileImage;
      expect(fileImage.file.path, filePath2);
      expect(fileImage.file.path, isNot(filePath1));
    });

    testWidgets('does not reset watcher when other props change', (
      WidgetTester tester,
    ) async {
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
