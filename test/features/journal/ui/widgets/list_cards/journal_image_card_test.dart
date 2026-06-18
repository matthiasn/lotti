import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_image_card.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  late RecordingMockNavService mockNavService;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockTimeService mockTimeService;

  setUp(() {
    mockNavService = RecordingMockNavService();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockTimeService = MockTimeService();

    // Create temp directory for tests
    final tempDir = Directory.systemTemp.createTempSync(
      'journal_image_card_test',
    );

    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<Directory>(tempDir);

    when(() => mockTimeService.linkedFrom).thenReturn(null);
    when(mockTimeService.getStream).thenAnswer((_) => Stream.value(null));
    when(
      () => mockEntitiesCacheService.getCategoryById(any()),
    ).thenReturn(
      CategoryDefinition(
        id: 'test-category-id',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        updatedAt: DateTime(2024, 3, 15, 10, 30),
        name: 'Test Category',
        vectorClock: null,
        private: false,
        active: true,
        color: '#FF0000',
      ),
    );
    when(() => mockEntitiesCacheService.getCategoryById(null)).thenReturn(null);
  });

  tearDown(() async {
    await getIt.reset();
  });

  tearDownAll(() {
    // Clean up temp directories
    try {
      Directory.systemTemp
          .listSync()
          .where((entity) => entity.path.contains('journal_image_card_test'))
          .forEach((entity) => entity.deleteSync(recursive: true));
    } catch (_) {}
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModernJournalImageCard', () {
    testWidgets('renders the image thumbnail', (tester) async {
      final imageEntry = testImageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: imageEntry),
        ),
      );

      expect(find.byType(ModernBaseCard), findsOneWidget);
      // The leading thumbnail is a CardImageWidget over a framed-image glyph
      // placeholder, so a missing file degrades gracefully.
      expect(find.byType(CardImageWidget), findsOneWidget);
      expect(find.byIcon(MdiIcons.imageOutline), findsOneWidget);
    });

    testWidgets('renders the caption text as the title', (tester) async {
      final imageEntry = testImageEntry;
      // Guard: this assertion only has value if the fixture carries text.
      expect(imageEntry.entryText, isNotNull);

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: imageEntry),
        ),
      );

      // The caption is rendered as plain text (no rich text viewer anymore).
      expect(find.text(imageEntry.entryText!.plainText), findsOneWidget);
    });

    // When there is no caption text, the card falls back to the localized
    // "Photo" label as its title. Both the null-entryText and the
    // empty-plainText branches collapse to the same observable outcome.
    for (final (label, entry) in [
      ('null entryText', testImageEntry.copyWith(entryText: null)),
      (
        'empty plainText',
        testImageEntry.copyWith(
          entryText: const EntryText(plainText: '', markdown: ''),
        ),
      ),
    ]) {
      testWidgets('falls back to the photo label for $label', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ModernJournalImageCard(item: entry),
          ),
        );

        final BuildContext context = tester.element(
          find.byType(ModernJournalImageCard),
        );
        // The card still renders, titled with the localized type label.
        expect(
          find.text(context.messages.entryTypeLabelJournalImage),
          findsOneWidget,
        );
        // And it never shows the original (empty) caption.
        expect(find.text('test image entry text'), findsNothing);
      });
    }

    testWidgets('shows starred icon when entry is starred', (tester) async {
      final starredEntry = testImageEntry.copyWith(
        meta: testImageEntry.meta.copyWith(starred: true),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: starredEntry),
        ),
      );

      expect(find.byIcon(MdiIcons.star), findsOneWidget);
    });

    testWidgets('shows private icon when entry is private', (tester) async {
      final privateEntry = testImageEntry.copyWith(
        meta: testImageEntry.meta.copyWith(private: true, starred: false),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: privateEntry),
        ),
      );

      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });

    testWidgets('shows flag icon for imported entries', (tester) async {
      final importedEntry = testImageEntry.copyWith(
        meta: testImageEntry.meta.copyWith(
          flag: EntryFlag.import,
          starred: false,
        ),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: importedEntry),
        ),
      );

      expect(find.byIcon(MdiIcons.flag), findsOneWidget);
    });

    testWidgets('hides deleted entries', (tester) async {
      final deletedEntry = testImageEntry.copyWith(
        meta: testImageEntry.meta.copyWith(
          deletedAt: DateTime(2024, 3, 15, 10, 30),
        ),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: deletedEntry),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(ModernBaseCard), findsNothing);
    });

    testWidgets('navigates to journal detail on tap', (tester) async {
      final imageEntry = testImageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: imageEntry),
        ),
      );

      await tester.tap(find.byType(ModernBaseCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        mockNavService.navigationHistory,
        contains('/journal/${imageEntry.meta.id}'),
      );
    });

    testWidgets('shows a full date + time label in the meta row', (
      tester,
    ) async {
      final entry = testImageEntry.copyWith(
        meta: testImageEntry.meta.copyWith(
          dateFrom: DateTime(2024, 3, 15, 10, 30),
        ),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: entry),
        ),
      );

      // The meta row shows the full humanised timestamp (date + time), resolved
      // via the same code path so the locale matches the rendered card.
      final BuildContext context = tester.element(
        find.byType(ModernJournalImageCard),
      );
      expect(
        find.text(entryDateLabel(context, entry.meta.dateFrom)),
        findsOneWidget,
      );
    });

    testWidgets('uses rounded-left border radius on the thumbnail', (
      tester,
    ) async {
      final imageEntry = testImageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: imageEntry),
        ),
      );

      // The thumbnail clips its top-left and bottom-left corners only.
      final clipRRect = tester.widget<ClipRRect>(
        find.byType(ClipRRect).first,
      );
      expect(
        clipRRect.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.cardBorderRadius),
          bottomLeft: Radius.circular(AppTheme.cardBorderRadius),
        ),
      );
    });
  });
}
