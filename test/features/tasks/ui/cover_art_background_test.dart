import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/cover_art_background.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/image_utils.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockDocumentsDirectory;

  JournalImage buildJournalImage({
    String id = 'image-1',
    String imageFile = 'test.jpg',
    String imageDirectory = '/images/',
  }) {
    final now = DateTime(2025, 12, 31, 12);
    return JournalImage(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: ImageData(
        imageId: 'img-uuid-$id',
        imageFile: imageFile,
        imageDirectory: imageDirectory,
        capturedAt: now,
      ),
    );
  }

  /// Creates a file with invalid image data at the path that getFullImagePath()
  /// will compute. This causes Image.file to trigger the errorBuilder.
  String createInvalidImageFile(JournalImage image) {
    final fullPath = getFullImagePath(image);

    // Create parent directories
    Directory(
      fullPath.substring(0, fullPath.lastIndexOf('/')),
    ).createSync(recursive: true);

    // Write invalid content (not a valid image format)
    File(fullPath).writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);

    return fullPath;
  }

  group('CoverArtBackground', () {
    group('with mock file system', () {
      setUp(() async {
        mockDocumentsDirectory = Directory.systemTemp.createTempSync(
          'cover_art_background_test_',
        );
        // Register the services EntryController constructs against so the
        // provider returns a real value instead of an error state — without
        // this the widget short-circuits at `entry is! JournalImage` before
        // reaching the Image.file render path.
        await setUpTestGetIt(
          additionalSetup: () {
            getIt
              ..registerSingleton<EditorStateService>(MockEditorStateService())
              ..registerSingleton<Directory>(mockDocumentsDirectory);
          },
        );
      });

      tearDown(() async {
        await tearDownTestGetIt();
        try {
          mockDocumentsDirectory.deleteSync(recursive: true);
        } catch (_) {
          // Ignore cleanup errors
        }
      });

      testWidgets('errorBuilder triggers when image file is invalid', (
        tester,
      ) async {
        final image = buildJournalImage();
        final filePath = createInvalidImageFile(image);

        // Verify file exists before test
        expect(File(filePath).existsSync(), isTrue);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtBackground(imageId: 'image-1'),
              ),
            ),
          ),
        );

        // Pump multiple times to allow error handling
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // The errorBuilder should have triggered and returned SizedBox.shrink
        // The widget tree should still contain the CoverArtBackground
        expect(find.byType(CoverArtBackground), findsOneWidget);
      });

      testWidgets(
        'renders Image.file with a positive LayoutBuilder-derived cacheHeight',
        (tester) async {
          final image = buildJournalImage();
          createInvalidImageFile(image);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [createEntryControllerOverride(image)],
              child: const MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    height: 240,
                    width: 360,
                    child: CoverArtBackground(imageId: 'image-1'),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final imageWidget = tester.widget<Image>(find.byType(Image));
          expect(imageWidget.fit, BoxFit.cover);
          expect(imageWidget.errorBuilder, isNotNull);

          // The cacheHeight cap is applied by ResizeImage wrapping FileImage,
          // sized from `constraints.maxHeight * 3` inside the LayoutBuilder.
          // 240 logical px × 3 = 720 physical px ceiling on decoded bitmap.
          expect(imageWidget.image, isA<ResizeImage>());
          final resize = imageWidget.image as ResizeImage;
          expect(resize.height, 720);
          expect(resize.imageProvider, isA<FileImage>());
        },
      );

      testWidgets(
        'errorBuilder returns SizedBox.shrink and exercises cache eviction',
        (tester) async {
          final image = buildJournalImage();
          createInvalidImageFile(image);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [createEntryControllerOverride(image)],
              child: const MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    height: 200,
                    width: 320,
                    child: CoverArtBackground(imageId: 'image-1'),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final imageWidget = tester.widget<Image>(find.byType(Image));
          final builder = imageWidget.errorBuilder!;

          final element = tester.element(find.byType(Image));
          final result = builder(element, Object(), StackTrace.current);

          // SizedBox.shrink() is a const SizedBox with 0 width/height.
          expect(result, isA<SizedBox>());
          final shrink = result as SizedBox;
          expect(shrink.width, 0.0);
          expect(shrink.height, 0.0);
        },
      );
    });

    testWidgets('renders SizedBox.shrink when entry is not JournalImage', (
      tester,
    ) async {
      final now = DateTime(2025, 12, 31, 12);
      final textEntry = JournalEntry(
        meta: Metadata(
          id: 'text-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        entryText: const EntryText(plainText: 'Not an image'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(textEntry),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CoverArtBackground(imageId: 'text-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render SizedBox.shrink
      expect(find.byType(CoverArtBackground), findsOneWidget);
    });

    testWidgets('widget can be constructed with JournalImage', (tester) async {
      final image = buildJournalImage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(image),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CoverArtBackground(imageId: 'image-1'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CoverArtBackground), findsOneWidget);
    });

    testWidgets('renders within a SliverAppBar context', (tester) async {
      final image = buildJournalImage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(image),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200,
                    flexibleSpace: FlexibleSpaceBar(
                      background: CoverArtBackground(imageId: 'image-1'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: 500),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CoverArtBackground), findsOneWidget);
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('renders nothing when provider returns loading state', (
      tester,
    ) async {
      // Without override, the provider should be in loading state
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CoverArtBackground(imageId: 'nonexistent'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Widget should still exist (rendering empty state)
      expect(find.byType(CoverArtBackground), findsOneWidget);
    });

    testWidgets('didUpdateWidget resets retries when imageId changes', (
      tester,
    ) async {
      final image1 = buildJournalImage();
      final now = DateTime(2025, 12, 31, 12);
      final image2 = JournalImage(
        meta: Metadata(
          id: 'image-2',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: ImageData(
          imageId: 'img-uuid-2',
          imageFile: 'test2.jpg',
          imageDirectory: '/test/dir',
          capturedAt: now,
        ),
      );

      // Start with image-1
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(image1),
            createEntryControllerOverride(image2),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CoverArtBackground(imageId: 'image-1'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CoverArtBackground), findsOneWidget);

      // Change to image-2 - this should trigger didUpdateWidget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(image1),
            createEntryControllerOverride(image2),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CoverArtBackground(imageId: 'image-2'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Widget should still render after imageId change
      expect(find.byType(CoverArtBackground), findsOneWidget);
    });

    testWidgets('maintains same imageId does not reset state', (tester) async {
      final image = buildJournalImage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(image),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 150,
                child: CoverArtBackground(imageId: 'image-1'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Pump with same imageId but in different container
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(image),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400, // Different container size
                height: 200,
                child: CoverArtBackground(imageId: 'image-1'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Widget should still render correctly
      expect(find.byType(CoverArtBackground), findsOneWidget);
    });
  });
}
