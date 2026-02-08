import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/gamey/gamey_card.dart';
import 'package:lotti/widgets/gamey/gamey_journal_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../test_helper.dart';
import '../../widget_test_utils.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {
  @override
  CategoryDefinition? getCategoryById(String? id) {
    return id == 'test-category-id'
        ? CategoryDefinition(
            id: 'test-category-id',
            createdAt: DateTime(2024, 1, 1, 12),
            updatedAt: DateTime(2024, 1, 1, 12),
            name: 'Test Category',
            vectorClock: null,
            private: false,
            active: true,
            color: '#FF0000',
          )
        : null;
  }

  @override
  HabitDefinition? getHabitById(String? id) => null;

  @override
  LabelDefinition? getLabelById(String? id) => null;

  @override
  bool get showPrivateEntries => true;
}

class MockNavService extends Mock implements NavService {
  final List<String> navigationHistory = [];

  @override
  void beamToNamed(String path, {Object? data}) {
    navigationHistory.add(path);
  }
}

class MockTimeService extends Mock implements TimeService {
  @override
  JournalEntity? get linkedFrom => null;

  @override
  Stream<JournalEntity?> getStream() => Stream.value(null);
}

class MockTagsService extends Mock implements TagsService {
  @override
  Map<String, TagEntity> tagsById = {};

  @override
  Stream<List<TagEntity>> watchTags() => Stream.value(<TagEntity>[]);

  @override
  TagEntity? getTagById(String id) => null;
}

void main() {
  late JournalEntry testJournalEntry;
  late Task testTask;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNavService mockNavService;
  late MockTimeService mockTimeService;
  late MockTagsService mockTagsService;
  late DateTime now;

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNavService = MockNavService();
    mockTimeService = MockTimeService();
    mockTagsService = MockTagsService();

    getIt.allowReassignment = true;
    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<TagsService>(mockTagsService)
      ..registerSingleton<LoggingService>(LoggingService());

    now = DateTime(2024, 1, 1, 12);

    // Create test journal entry
    final journalMetadata = Metadata(
      id: 'test-journal-id',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
    );

    const entryText = EntryText(
      plainText: 'Test journal entry content',
      markdown: 'Test journal entry content',
    );

    testJournalEntry = JournalEntry(
      meta: journalMetadata,
      entryText: entryText,
    );

    // Create test task
    final taskMetadata = Metadata(
      id: 'test-task-id',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
    );

    final taskStatus = TaskStatus.open(
      id: 'status-id',
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );

    final taskData = TaskData(
      status: taskStatus,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      statusHistory: [],
      title: 'Test Task Title',
    );

    testTask = Task(
      meta: taskMetadata,
      data: taskData,
      entryText: entryText,
    );

    ensureThemingServicesRegistered();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('GameyJournalCard', () {
    testWidgets('renders journal entry inside GameySubtleCard', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: GameyJournalCard(item: testJournalEntry),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameySubtleCard), findsOneWidget);
    });

    testWidgets('navigates to journal details on tap', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: GameyJournalCard(item: testJournalEntry),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(GameyJournalCard));
      await tester.pump();

      expect(
        mockNavService.navigationHistory,
        contains('/journal/test-journal-id'),
      );
    });

    testWidgets('navigates to task details when item is Task', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: GameyJournalCard(item: testTask),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(GameyJournalCard));
      await tester.pump();

      expect(
        mockNavService.navigationHistory,
        contains('/tasks/test-task-id'),
      );
    });

    testWidgets('renders rating entry with label', (tester) async {
      final ratingEntry = JournalEntity.rating(
        meta: Metadata(
          id: 'test-rating-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
        ),
        data: const RatingData(
          timeEntryId: 'te-1',
          dimensions: [
            RatingDimension(key: 'productivity', value: 0.8),
          ],
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: GameyJournalCard(item: ratingEntry),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameySubtleCard), findsOneWidget);
      expect(find.text('Session Rating'), findsOneWidget);
    });

    testWidgets('returns empty when item is deleted', (tester) async {
      final deletedEntry = JournalEntry(
        meta: Metadata(
          id: 'deleted-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          deletedAt: now, // Marked as deleted
        ),
        entryText: const EntryText(
          plainText: 'Deleted entry',
          markdown: 'Deleted entry',
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: GameyJournalCard(item: deletedEntry),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameySubtleCard), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders in compact mode', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: GameyJournalCard(
            item: testJournalEntry,
            isCompact: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameySubtleCard), findsOneWidget);
    });

    testWidgets('renders without horizontal margin when specified',
        (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: GameyJournalCard(
            item: testJournalEntry,
            removeHorizontalMargin: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final subtleCard =
          tester.widget<GameySubtleCard>(find.byType(GameySubtleCard));
      // Verify margin is applied (horizontal should be 0)
      expect(subtleCard.margin?.horizontal, equals(0));
    });

    testWidgets('renders task with title', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: GameyJournalCard(item: testTask),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test Task Title'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        DarkWidgetTestBench(
          child: GameyJournalCard(item: testJournalEntry),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameySubtleCard), findsOneWidget);
    });

    testWidgets('renders with labels when entry has labels', (tester) async {
      final entryWithLabels = JournalEntry(
        meta: Metadata(
          id: 'test-journal-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          labelIds: ['label-1', 'label-2'],
        ),
        entryText: const EntryText(
          plainText: 'Short',
          markdown: 'Short',
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: SingleChildScrollView(
            child: GameyJournalCard(
              item: entryWithLabels,
              isCompact: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameySubtleCard), findsOneWidget);
    });

    testWidgets('renders with category when entry has category',
        (tester) async {
      final entryWithCategory = JournalEntry(
        meta: Metadata(
          id: 'test-journal-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          categoryId: 'test-category-id',
        ),
        entryText: const EntryText(
          plainText: 'Entry with category',
          markdown: 'Entry with category',
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: GameyJournalCard(item: entryWithCategory),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameySubtleCard), findsOneWidget);
    });

    testWidgets('respects maxHeight parameter', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: GameyJournalCard(
            item: testJournalEntry,
            maxHeight: 200,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameySubtleCard), findsOneWidget);
    });

    testWidgets('shows linked duration when enabled', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: GameyJournalCard(
            item: testTask,
            showLinkedDuration: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameySubtleCard), findsOneWidget);
    });
  });
}
