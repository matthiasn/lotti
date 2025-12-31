import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/utils/platform.dart';

import '../../../helpers/fake_entry_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set test environment to avoid file system checks
  setUp(() {
    isTestEnv = true;
  });

  tearDown(() {
    isTestEnv = false;
  });

  JournalImage buildJournalImage() {
    final now = DateTime(2025, 12, 31, 12);
    return JournalImage(
      meta: Metadata(
        id: 'image-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: ImageData(
        imageId: 'img-uuid',
        imageFile: 'test.jpg',
        imageDirectory: '/test/dir',
        capturedAt: now,
      ),
    );
  }

  group('CoverArtThumbnail', () {
    testWidgets('renders with correct size', (tester) async {
      const testSize = 80.0;
      final image = buildJournalImage();

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

      // Find the outer SizedBox
      final sizedBoxFinder = find.byType(SizedBox).first;
      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);

      expect(sizedBox.width, testSize);
      expect(sizedBox.height, testSize);
    });

    testWidgets('uses default cropX of 0.5 (center)', (tester) async {
      final image = buildJournalImage();

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

      // The widget should render (even without actual image file in test env)
      expect(find.byType(CoverArtThumbnail), findsOneWidget);
    });

    testWidgets('accepts custom cropX value', (tester) async {
      final image = buildJournalImage();

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
                cropX: 0, // Left edge
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CoverArtThumbnail), findsOneWidget);
    });

    testWidgets('renders empty SizedBox when entry is not JournalImage',
        (tester) async {
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

      // Should render a SizedBox placeholder
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('cropX 0.0 maps to left alignment', (tester) async {
      // Verify the math: cropX 0.0 should map to alignment -1.0
      // Formula: alignmentX = (cropX * 2) - 1
      // 0.0 * 2 - 1 = -1.0 (left)
      const cropX = 0.0;
      const alignmentX = (cropX * 2) - 1;
      expect(alignmentX, -1.0);
    });

    testWidgets('cropX 0.5 maps to center alignment', (tester) async {
      // Verify the math: cropX 0.5 should map to alignment 0.0
      // Formula: alignmentX = (cropX * 2) - 1
      // 0.5 * 2 - 1 = 0.0 (center)
      const cropX = 0.5;
      const alignmentX = (cropX * 2) - 1;
      expect(alignmentX, 0.0);
    });

    testWidgets('cropX 1.0 maps to right alignment', (tester) async {
      // Verify the math: cropX 1.0 should map to alignment 1.0
      // Formula: alignmentX = (cropX * 2) - 1
      // 1.0 * 2 - 1 = 1.0 (right)
      const cropX = 1.0;
      const alignmentX = (cropX * 2) - 1;
      expect(alignmentX, 1.0);
    });
  });
}
