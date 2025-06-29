import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget_non_scrollable.dart';
import 'package:lotti/features/tasks/ui/linked_duration.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
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
    final tempDir = Directory.systemTemp.createTempSync('journal_card_test');
    
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
      Directory.systemTemp.listSync()
          .where((entity) => entity.path.contains('journal_card_test'))
          .forEach((entity) => entity.deleteSync(recursive: true));
    } catch (_) {}
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModernJournalCard', () {
    testWidgets('renders journal entry with text', (tester) async {
      final testEntry = testTextEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byType(ModernBaseCard), findsOneWidget);
      
      // TextViewerWidgetNonScrollable uses QuillEditor which doesn't create a simple Text widget
      // Instead, we should verify that the TextViewerWidgetNonScrollable is present
      expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      
      // For compact mode, we can find the text directly
      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testEntry, isCompact: true),
        ),
      );
      // In compact mode, we render plain text instead of TextViewerWidget
      expect(find.text(testEntry.entryText!.plainText), findsOneWidget);
    });

    testWidgets('renders journal audio entry', (tester) async {
      final audioEntry = testAudioEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: audioEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('renders task entry with title', (tester) async {
      final taskEntry = testTask;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: taskEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.text(taskEntry.data.title), findsOneWidget);
    });

    testWidgets('renders measurement entry with numeric icon', (tester) async {
      final measurementEntry = testMeasurementChocolateEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: measurementEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byIcon(MdiIcons.numeric), findsWidgets);
    });

    testWidgets('renders quantitative entry with heart icon', (tester) async {
      final healthEntry = testBpSystolicEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: healthEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byIcon(MdiIcons.heart), findsOneWidget);
    });

    testWidgets('renders another measurement entry', (tester) async {
      final measurementEntry = testMeasuredCoverageEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: measurementEntry),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      expect(find.byIcon(MdiIcons.numeric), findsOneWidget);
    });

    testWidgets('shows starred icon when entry is starred', (tester) async {
      final starredEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(starred: true),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: starredEntry),
        ),
      );

      expect(find.byIcon(MdiIcons.star), findsOneWidget);
    });

    testWidgets('shows private icon when entry is private', (tester) async {
      final privateEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(private: true),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: privateEntry),
        ),
      );

      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });

    testWidgets('shows flag icon for imported entries', (tester) async {
      final importedEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(flag: EntryFlag.import),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: importedEntry),
        ),
      );

      expect(find.byIcon(MdiIcons.flag), findsOneWidget);
    });

    testWidgets('renders in compact mode', (tester) async {
      final testEntry = testTextEntry;

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(
            item: testEntry,
            isCompact: true,
          ),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      
      // In compact mode, text should be limited to 2 lines
      final textWidget = tester.widget<Text>(
        find.text(testEntry.entryText!.plainText),
      );
      expect(textWidget.maxLines, 2);
    });

    testWidgets('hides deleted entries', (tester) async {
      final deletedEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(
          deletedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: deletedEntry),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(ModernBaseCard), findsNothing);
    });

    testWidgets('navigates to task detail on tap', (tester) async {
      final taskEntry = testTask;
      getIt.registerSingleton<NavService>(mockNavService);

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: taskEntry),
        ),
      );

      await tester.tap(find.byType(ModernBaseCard));
      await tester.pumpAndSettle();

      expect(
        mockNavService.navigationHistory,
        contains('/tasks/${taskEntry.meta.id}'),
      );
    });

    testWidgets('navigates to journal detail on tap', (tester) async {
      final testEntry = testTextEntry;
      getIt.registerSingleton<NavService>(mockNavService);

      await tester.pumpWidget(
        makeTestableWidget(
          ModernJournalCard(item: testEntry),
        ),
      );

      await tester.tap(find.byType(ModernBaseCard));
      await tester.pumpAndSettle();

      expect(
        mockNavService.navigationHistory,
        contains('/journal/${testEntry.meta.id}'),
      );
    });


    testWidgets('shows linked duration when enabled', (tester) async {
      final taskEntry = testTask;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernJournalCard(
            item: taskEntry,
            showLinkedDuration: true,
          ),
        ),
      );

      expect(find.byType(ModernJournalCard), findsOneWidget);
      // LinkedDuration widget would be shown if there's an estimate
      expect(find.byType(LinkedDuration), findsOneWidget);
    });
  });
}
