import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_image_card.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_view_widget.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget_non_scrollable.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

class MockNavService extends Mock implements NavService {
  final List<String> navigationHistory = [];

  @override
  void beamToNamed(String path, {Object? data}) {
    navigationHistory.add(path);
  }
}

class MockTimeService implements TimeService {
  JournalEntity? _linkedFrom;

  @override
  JournalEntity? get linkedFrom => _linkedFrom;

  @override
  Stream<JournalEntity?> getStream() {
    return Stream.value(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTagsService extends Mock implements TagsService {
  @override
  Map<String, TagEntity> get tagsById => {};

  @override
  Stream<List<TagEntity>> watchTags() {
    return Stream.value(<TagEntity>[]);
  }

  @override
  TagEntity? getTagById(String id) {
    return null;
  }
}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {
  @override
  CategoryDefinition? getCategoryById(String? categoryId) {
    return categoryId != null
        ? CategoryDefinition(
            id: 'test-category-id',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            name: 'Test Category',
            vectorClock: null,
            private: false,
            active: true,
            color: '#FF0000',
          )
        : null;
  }
}

void main() {
  late MockNavService mockNavService;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockTagsService mockTagsService;
  late MockTimeService mockTimeService;

  setUp(() {
    mockNavService = MockNavService();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockTagsService = MockTagsService();
    mockTimeService = MockTimeService();

    getIt.allowReassignment = true;

    // Create temp directory for tests
    final tempDir =
        Directory.systemTemp.createTempSync('journal_image_card_test');

    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<TagsService>(mockTagsService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<Directory>(tempDir);
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
    testWidgets('renders journal image entry', (tester) async {
      final imageEntry = testImageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: imageEntry),
        ),
      );

      expect(find.byType(ModernJournalImageCard), findsOneWidget);
      expect(find.byType(ModernBaseCard), findsOneWidget);
      expect(find.byType(CardImageWidget), findsOneWidget);
    });

    testWidgets('displays entry text when available', (tester) async {
      final imageEntry = testImageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: imageEntry),
        ),
      );

      if (imageEntry.entryText != null) {
        // TextViewerWidgetNonScrollable is used for displaying text in non-compact mode
        expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      }
    });

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
        meta: testImageEntry.meta.copyWith(private: true),
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
        meta: testImageEntry.meta.copyWith(flag: EntryFlag.import),
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
          deletedAt: DateTime.now(),
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
      getIt.registerSingleton<NavService>(mockNavService);

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: imageEntry),
        ),
      );

      await tester.tap(find.byType(ModernBaseCard));
      await tester.pumpAndSettle();

      expect(
        mockNavService.navigationHistory,
        contains('/journal/${imageEntry.meta.id}'),
      );
    });

    testWidgets('shows category icon', (tester) async {
      final imageEntry = testImageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: imageEntry),
        ),
      );

      // Category icon should be displayed
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('shows date in correct format', (tester) async {
      final imageEntry = testImageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: imageEntry),
        ),
      );

      // Date should be displayed
      expect(find.textContaining(RegExp(r'\d{2}:\d{2}')), findsOneWidget);
    });

    testWidgets('shows tags when not in compact mode', (tester) async {
      final imageEntry = testImageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(
            item: imageEntry,
          ),
        ),
      );

      // Tags view should be present in non-compact mode
      // Verify TagsViewWidget is present
      expect(find.byType(TagsViewWidget), findsOneWidget);
      // Verify text content is present
      expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
    });

    testWidgets('uses correct border radius for image', (tester) async {
      final imageEntry = testImageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: imageEntry),
        ),
      );

      // ClipRRect should have correct border radius
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

    testWidgets('text viewer receives finite maxHeight instead of infinity',
        (tester) async {
      final imageEntry = testImageEntry.copyWith(
        entryText: const EntryText(
          plainText: 'Test content for overflow detection',
          markdown: 'Test content for overflow detection',
        ),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalImageCard(item: imageEntry),
        ),
      );

      // Find the TextViewerWidgetNonScrollable widget
      final textViewer = tester.widget<TextViewerWidgetNonScrollable>(
        find.byType(TextViewerWidgetNonScrollable),
      );

      // Verify that maxHeight is not infinity (our bug fix)
      expect(textViewer.maxHeight, isNot(double.infinity));
      expect(textViewer.maxHeight, greaterThan(0));
    });
  });
}
