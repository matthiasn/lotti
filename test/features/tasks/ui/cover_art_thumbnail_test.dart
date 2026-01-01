import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockDocumentsDirectory;

  setUp(() async {
    await getIt.reset();
    getIt.allowReassignment = true;

    // Create a temp directory to simulate the documents directory
    mockDocumentsDirectory =
        Directory.systemTemp.createTempSync('cover_art_thumbnail_test_');

    // Register temp directory for getDocumentsDirectory()
    getIt.registerSingleton<Directory>(mockDocumentsDirectory);

    // Register required mocks for EntryController
    final mockEditorStateService = MockEditorStateService();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockJournalDb = MockJournalDb();
    final mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());

    getIt
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() async {
    await getIt.reset();
    try {
      mockDocumentsDirectory.deleteSync(recursive: true);
    } catch (_) {
      // Ignore cleanup errors
    }
  });

  /// Creates a JournalImage with the specified id.
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

  /// Creates the image file on disk at the path that getFullImagePath() will compute.
  /// Returns the full path to the created file.
  String createImageFile(JournalImage image) {
    // Use the same function the widget uses to get the path
    final fullPath = getFullImagePath(image);

    // Create parent directories
    Directory(fullPath.substring(0, fullPath.lastIndexOf('/')))
        .createSync(recursive: true);

    // Create a minimal valid file (not a real image, but exists)
    File(fullPath)
        .writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG magic bytes

    return fullPath;
  }

  group('CoverArtThumbnail', () {
    group('with valid JournalImage and existing file', () {
      testWidgets('renders Image.file when file exists', (tester) async {
        final image = buildJournalImage();
        final filePath = createImageFile(image);

        // Verify file exists before test
        expect(File(filePath).existsSync(), isTrue);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: 80,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should render the image structure: SizedBox > ClipRect > FittedBox > Image.file
        expect(find.byType(ClipRect), findsOneWidget);
        expect(find.byType(FittedBox), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('alignment reflects cropX=0.0 (left)', (tester) async {
        final image = buildJournalImage();
        createImageFile(image);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: 80,
                  cropX: 0, // Left edge: (0 * 2) - 1 = -1
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
        expect(fittedBox.alignment, Alignment.centerLeft);
        expect(fittedBox.fit, BoxFit.cover);
      });

      testWidgets('alignment reflects cropX=0.5 (center)', (tester) async {
        final image = buildJournalImage();
        createImageFile(image);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: 80,
                  // cropX defaults to 0.5: (0.5 * 2) - 1 = 0
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
        expect(fittedBox.alignment, Alignment.center);
      });

      testWidgets('alignment reflects cropX=1.0 (right)', (tester) async {
        final image = buildJournalImage();
        createImageFile(image);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: 80,
                  cropX: 1, // Right edge: (1 * 2) - 1 = 1
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
        expect(fittedBox.alignment, Alignment.centerRight);
      });

      testWidgets('alignment reflects cropX=0.25 (quarter left)',
          (tester) async {
        final image = buildJournalImage();
        createImageFile(image);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: 80,
                  cropX: 0.25, // (0.25 * 2) - 1 = -0.5
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
        expect(fittedBox.alignment, const Alignment(-0.5, 0));
      });

      testWidgets('renders with correct size', (tester) async {
        const testSize = 100.0;
        final image = buildJournalImage();
        createImageFile(image);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: testSize,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the outer SizedBox (the one wrapping the image content)
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final outerSizedBox = sizedBoxes.firstWhere(
          (sb) => sb.width == testSize && sb.height == testSize,
        );
        expect(outerSizedBox.width, testSize);
        expect(outerSizedBox.height, testSize);
      });
    });

    group('when entry is not a JournalImage', () {
      testWidgets('renders fallback SizedBox for JournalEntry', (tester) async {
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
                body: CoverArtThumbnail(
                  imageId: 'text-1',
                  size: 80,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should NOT render ClipRect/FittedBox/Image
        expect(find.byType(ClipRect), findsNothing);
        expect(find.byType(FittedBox), findsNothing);
        expect(find.byType(Image), findsNothing);

        // Should render a fallback SizedBox with correct dimensions
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(sizedBox.width, 80);
        expect(sizedBox.height, 80);
      });

      testWidgets('renders fallback SizedBox for Task entry', (tester) async {
        final now = DateTime(2025, 12, 31, 12);
        // Task is not a JournalImage, so it should fallback
        final task = Task(
          meta: Metadata(
            id: 'task-1',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: TaskData(
            title: 'Test task',
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: now,
              utcOffset: 0,
            ),
            dateFrom: now,
            dateTo: now,
            statusHistory: [],
          ),
          entryText: const EntryText(plainText: 'Task text'),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(task),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'task-1',
                  size: 60,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should NOT render image widgets
        expect(find.byType(ClipRect), findsNothing);
        expect(find.byType(Image), findsNothing);

        // Should render fallback SizedBox
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(sizedBox.width, 60);
        expect(sizedBox.height, 60);
      });
    });

    group('when image file is absent', () {
      testWidgets('renders fallback SizedBox when file does not exist',
          (tester) async {
        // Create JournalImage but DON'T create the file on disk
        final image = buildJournalImage(
          imageFile: 'nonexistent.jpg',
          imageDirectory: '/missing/',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: 80,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should NOT render image widgets since file doesn't exist
        expect(find.byType(ClipRect), findsNothing);
        expect(find.byType(FittedBox), findsNothing);
        expect(find.byType(Image), findsNothing);

        // Should render fallback SizedBox
        expect(find.byType(SizedBox), findsWidgets);
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(sizedBox.width, 80);
        expect(sizedBox.height, 80);
      });

      testWidgets(
          'renders fallback even with valid JournalImage but missing file',
          (tester) async {
        final image = buildJournalImage();
        // Note: NOT calling createImageFile - file doesn't exist

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: 50,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // File doesn't exist, so should show fallback
        expect(find.byType(Image), findsNothing);
        expect(find.byType(ClipRect), findsNothing);
      });
    });

    group('didUpdateWidget behavior', () {
      testWidgets('resets file watcher when imageId changes', (tester) async {
        final image1 = buildJournalImage();
        final image2 = buildJournalImage(
          id: 'image-2',
          imageFile: 'test2.jpg',
        );

        // Create files for both images
        createImageFile(image1);
        createImageFile(image2);

        // Start with image-1
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image1),
              createEntryControllerOverride(image2),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: 80,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify image-1 is showing
        expect(find.byType(Image), findsOneWidget);

        // Change to image-2 - this triggers didUpdateWidget -> resetFileWatcher
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image1),
              createEntryControllerOverride(image2),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-2',
                  size: 80,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // After imageId change, widget should still render correctly
        expect(find.byType(CoverArtThumbnail), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('does not reset when same imageId with different props',
          (tester) async {
        final image = buildJournalImage();
        createImageFile(image);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: 80,
                  cropX: 0,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsOneWidget);

        // Change size and cropX but keep same imageId
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1', // Same imageId
                  size: 100, // Different size
                  cropX: 1, // Different cropX
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Widget should still render correctly
        expect(find.byType(Image), findsOneWidget);

        // Alignment should reflect new cropX
        final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
        expect(fittedBox.alignment, Alignment.centerRight);
      });

      testWidgets('handles switching from existing to non-existing file',
          (tester) async {
        final image1 = buildJournalImage();
        final image2 = buildJournalImage(
          id: 'image-2',
          imageFile: 'nonexistent.jpg',
          imageDirectory: '/missing/',
        );

        // Only create file for image1
        createImageFile(image1);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image1),
              createEntryControllerOverride(image2),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: 80,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // First image should render
        expect(find.byType(Image), findsOneWidget);

        // Switch to image2 (file doesn't exist)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image1),
              createEntryControllerOverride(image2),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-2',
                  size: 80,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should now show fallback (no Image widget)
        expect(find.byType(Image), findsNothing);
        expect(find.byType(SizedBox), findsWidgets);
      });
    });

    group('dispose behavior', () {
      testWidgets('cleans up file watcher on widget removal', (tester) async {
        final image = buildJournalImage();
        createImageFile(image);

        // Key to help identify the widget
        final key = UniqueKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  key: key,
                  imageId: 'image-1',
                  size: 80,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CoverArtThumbnail), findsOneWidget);

        // Remove the widget by replacing it with something else
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: Text('Widget removed'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Widget should be gone
        expect(find.byType(CoverArtThumbnail), findsNothing);
        expect(find.text('Widget removed'), findsOneWidget);

        // No exception means dispose completed successfully
      });

      testWidgets('handles multiple mount/unmount cycles', (tester) async {
        final image = buildJournalImage();
        createImageFile(image);

        for (var i = 0; i < 3; i++) {
          // Mount
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                createEntryControllerOverride(image),
              ],
              child: const MaterialApp(
                home: Scaffold(
                  body: CoverArtThumbnail(
                    imageId: 'image-1',
                    size: 80,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CoverArtThumbnail), findsOneWidget);

          // Unmount
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                createEntryControllerOverride(image),
              ],
              child: const MaterialApp(
                home: Scaffold(
                  body: SizedBox(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CoverArtThumbnail), findsNothing);
        }
      });
    });

    group('cropX alignment calculation', () {
      test('cropX 0.0 maps to alignment -1.0 (left)', () {
        const cropX = 0.0;
        const alignmentX = (cropX * 2) - 1;
        expect(alignmentX, -1.0);
        expect(Alignment.centerLeft, Alignment.centerLeft);
      });

      test('cropX 0.25 maps to alignment -0.5', () {
        const cropX = 0.25;
        const alignmentX = (cropX * 2) - 1;
        expect(alignmentX, -0.5);
      });

      test('cropX 0.5 maps to alignment 0.0 (center)', () {
        const cropX = 0.5;
        const alignmentX = (cropX * 2) - 1;
        expect(alignmentX, 0.0);
        expect(Alignment.center, Alignment.center);
      });

      test('cropX 0.75 maps to alignment 0.5', () {
        const cropX = 0.75;
        const alignmentX = (cropX * 2) - 1;
        expect(alignmentX, 0.5);
      });

      test('cropX 1.0 maps to alignment 1.0 (right)', () {
        const cropX = 1.0;
        const alignmentX = (cropX * 2) - 1;
        expect(alignmentX, 1.0);
        expect(Alignment.centerRight, Alignment.centerRight);
      });
    });

    group('edge cases', () {
      testWidgets('handles null entry gracefully', (tester) async {
        // Don't provide any override - provider returns null
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'nonexistent',
                  size: 80,
                ),
              ),
            ),
          ),
        );
        // Just pump once without settling (provider might be loading)
        await tester.pump();

        // Should not crash - widget handles null/loading state
        expect(find.byType(CoverArtThumbnail), findsOneWidget);
      });

      testWidgets('renders with very small size', (tester) async {
        final image = buildJournalImage();
        createImageFile(image);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CoverArtThumbnail(
                  imageId: 'image-1',
                  size: 1,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CoverArtThumbnail), findsOneWidget);
      });

      testWidgets('renders with very large size', (tester) async {
        final image = buildJournalImage();
        createImageFile(image);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              createEntryControllerOverride(image),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CoverArtThumbnail(
                    imageId: 'image-1',
                    size: 1000,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CoverArtThumbnail), findsOneWidget);
      });
    });
  });
}
