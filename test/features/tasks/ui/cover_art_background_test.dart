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

  group('coverArtCacheExtent', () {
    test('returns null for an unbounded constraint', () {
      expect(coverArtCacheExtent(double.infinity, 2), isNull);
    });

    test('returns null for a zero extent (SliverAppBar collapse)', () {
      expect(coverArtCacheExtent(0, 2), isNull);
    });

    test('returns null for a negative extent', () {
      expect(coverArtCacheExtent(-10, 2), isNull);
    });

    test('returns null for NaN', () {
      expect(coverArtCacheExtent(double.nan, 2), isNull);
    });

    test('returns null for a non-finite devicePixelRatio', () {
      // ceil() on a NaN/infinite product throws — the guard must catch the
      // ratio before the multiplication happens.
      expect(coverArtCacheExtent(100, double.nan), isNull);
      expect(coverArtCacheExtent(100, double.infinity), isNull);
    });

    test('returns null for a non-positive devicePixelRatio', () {
      expect(coverArtCacheExtent(100, 0), isNull);
      expect(coverArtCacheExtent(100, -2), isNull);
    });

    test('rounds physical pixels up to the next bucket multiple', () {
      // 360 logical × 3 DPR = 1080 physical → next 256-multiple is 1280.
      expect(coverArtCacheExtent(360, 3), 1280);
    });

    test('keeps an exact bucket multiple unchanged', () {
      // 256 logical × 1 DPR = 256 physical — already on a bucket boundary.
      expect(coverArtCacheExtent(256, 1), coverArtDecodeBucket);
    });

    test('maps a tiny extent to a full bucket, never below one', () {
      expect(coverArtCacheExtent(1, 1), coverArtDecodeBucket);
    });

    test('yields identical extents for all widths within one bucket', () {
      // The whole point of quantization: every divider position between
      // two bucket boundaries produces the same decode target, so the
      // image cache is hit instead of re-decoding per dragged pixel.
      final low = coverArtCacheExtent(342, 3); // 1026 physical
      final high = coverArtCacheExtent(426, 3); // 1278 physical
      expect(low, 1280);
      expect(high, 1280);
    });

    test('yields a larger extent once a bucket boundary is crossed', () {
      expect(coverArtCacheExtent(426, 3), 1280); // 1278 physical
      expect(coverArtCacheExtent(428, 3), 1536); // 1284 physical
    });

    test('clamps to coverArtMaxDecodeExtent for huge extents', () {
      // 4000 logical × 3 DPR = 12000 physical → bucketed 12032 → clamped.
      expect(coverArtCacheExtent(4000, 3), coverArtMaxDecodeExtent);
    });
  });

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

      Widget buildSubject(
        JournalImage image, {
        double height = 100,
        double width = 100,
      }) {
        // Align gives the SizedBox loose constraints so it keeps its
        // specified dimensions, and the SizedBox bounds CoverArtBackground's
        // Stack(StackFit.expand) — without explicit bounds, the surrounding
        // SingleChildScrollView would leave the Stack with an unbounded
        // vertical constraint.
        return makeTestableWidget(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: height,
              width: width,
              child: CoverArtBackground(imageId: image.meta.id),
            ),
          ),
          overrides: [createEntryControllerOverride(image)],
          mediaQueryData: phoneMediaQueryData.copyWith(devicePixelRatio: 3),
        );
      }

      testWidgets('configures errorBuilder when image file is invalid', (
        tester,
      ) async {
        final image = buildJournalImage();
        final filePath = createInvalidImageFile(image);

        expect(File(filePath).existsSync(), isTrue);

        await tester.pumpWidget(buildSubject(image));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // The integration assertion: the rendered Image.file is wired with
        // an errorBuilder callback so a decode failure on this invalid file
        // can fall back without tearing down the widget. The callback's
        // body itself is exercised in the dedicated white-box test below.
        final imageWidget = tester.widget<Image>(find.byType(Image));
        expect(imageWidget.errorBuilder, isNotNull);
      });

      testWidgets(
        'renders Image.file with bucket-quantized cacheWidth/cacheHeight',
        (tester) async {
          final image = buildJournalImage();
          createInvalidImageFile(image);

          await tester.pumpWidget(
            buildSubject(image, height: 240, width: 360),
          );
          await tester.pump();

          final imageWidget = tester.widget<Image>(find.byType(Image));
          expect(imageWidget.fit, BoxFit.cover);
          expect(imageWidget.errorBuilder, isNotNull);

          // The cap is derived from the width alone (360 × 3 = 1080 physical
          // → next coverArtDecodeBucket multiple is 1280) and applied to both
          // axes, so the cache key ignores the height that SliverAppBar
          // collapse animates every frame. ResizeImagePolicy.fit keeps the
          // source aspect ratio at decode time so the displayed bitmap isn't
          // squashed.
          expect(imageWidget.image, isA<ResizeImage>());
          final resize = imageWidget.image as ResizeImage;
          expect(resize.width, 1280);
          expect(resize.height, 1280);
          expect(resize.policy, ResizeImagePolicy.fit);
          expect(resize.imageProvider, isA<FileImage>());
        },
      );

      testWidgets(
        'keeps the same cache key when only the height changes (collapse)',
        (tester) async {
          final image = buildJournalImage();
          createInvalidImageFile(image);

          await tester.pumpWidget(
            buildSubject(image, height: 240, width: 360),
          );
          await tester.pump();
          final before = tester.widget<Image>(find.byType(Image)).image;
          final beforeKey = await before.obtainKey(ImageConfiguration.empty);

          // SliverAppBar collapse shrinks the height every scrolled frame;
          // the decode target must not follow it or scrolling would churn
          // the image cache exactly like the pane-resize bug did.
          await tester.pumpWidget(
            buildSubject(image, height: 120, width: 360),
          );
          await tester.pump();
          final after = tester.widget<Image>(find.byType(Image)).image;
          final afterKey = await after.obtainKey(ImageConfiguration.empty);

          expect(afterKey, equals(beforeKey));
        },
      );

      testWidgets(
        'falls back to a height-derived cap when the width collapses to zero',
        (tester) async {
          final image = buildJournalImage();
          createInvalidImageFile(image);

          await tester.pumpWidget(
            buildSubject(image, width: 0),
          );
          await tester.pump();

          // Width extent is null at 0, so the height axis (default 100)
          // supplies the cap: 100 × 3 = 300 physical → next bucket multiple
          // is 512.
          final imageWidget = tester.widget<Image>(find.byType(Image));
          final resize = imageWidget.image as ResizeImage;
          expect(resize.width, 512);
          expect(resize.height, 512);
        },
      );

      testWidgets(
        'enables gaplessPlayback so resizes never blank the current frame',
        (tester) async {
          final image = buildJournalImage();
          createInvalidImageFile(image);

          await tester.pumpWidget(buildSubject(image));
          await tester.pump();

          final imageWidget = tester.widget<Image>(find.byType(Image));
          expect(imageWidget.gaplessPlayback, isTrue);
        },
      );

      testWidgets(
        'keeps the same ResizeImage cache key while resizing inside a bucket',
        (tester) async {
          final image = buildJournalImage();
          createInvalidImageFile(image);

          // 360 × 3 = 1080 and 380 × 3 = 1140 both round up to 1280 — the
          // decoded bitmap is reused for every intermediate divider position
          // in that band instead of re-decoding per dragged pixel.
          await tester.pumpWidget(
            buildSubject(image, height: 240, width: 360),
          );
          await tester.pump();
          final before = tester.widget<Image>(find.byType(Image)).image;
          final beforeKey = await before.obtainKey(ImageConfiguration.empty);

          await tester.pumpWidget(
            buildSubject(image, height: 240, width: 380),
          );
          await tester.pump();
          final after = tester.widget<Image>(find.byType(Image)).image;
          final afterKey = await after.obtainKey(ImageConfiguration.empty);

          // Identical image-cache keys mean the second layout resolves from
          // the in-memory cache instead of kicking off a new decode.
          expect(afterKey, equals(beforeKey));
        },
      );

      testWidgets(
        'changes the ResizeImage cache key when a bucket boundary is crossed',
        (tester) async {
          final image = buildJournalImage();
          createInvalidImageFile(image);

          // 360 × 3 = 1080 → 1280, but 480 × 3 = 1440 → 1536: a genuinely
          // larger pane re-decodes at higher resolution.
          await tester.pumpWidget(
            buildSubject(image, height: 240, width: 360),
          );
          await tester.pump();
          final before = tester.widget<Image>(find.byType(Image)).image;
          final beforeKey = await before.obtainKey(ImageConfiguration.empty);

          await tester.pumpWidget(
            buildSubject(image, height: 240, width: 480),
          );
          await tester.pump();
          final after = tester.widget<Image>(find.byType(Image)).image;
          final afterKey = await after.obtainKey(ImageConfiguration.empty);

          expect(afterKey, isNot(equals(beforeKey)));
          expect((after as ResizeImage).width, 1536);
        },
      );

      testWidgets(
        'errorBuilder returns SizedBox.shrink and exercises cache eviction',
        (tester) async {
          final image = buildJournalImage();
          createInvalidImageFile(image);

          await tester.pumpWidget(
            buildSubject(image, height: 200, width: 320),
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
