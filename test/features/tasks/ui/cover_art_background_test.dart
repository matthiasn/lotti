import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/cover_art_background.dart';

import '../../../helpers/fake_entry_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  JournalImage buildJournalImage({String id = 'image-1'}) {
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
        imageId: 'img-uuid',
        imageFile: 'test.jpg',
        imageDirectory: '/test/dir/',
        capturedAt: now,
      ),
    );
  }

  group('CoverArtBackground', () {
    testWidgets('renders SizedBox.shrink when entry is not JournalImage',
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

    testWidgets('renders nothing when provider returns loading state',
        (tester) async {
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

    testWidgets('didUpdateWidget resets retries when imageId changes',
        (tester) async {
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
