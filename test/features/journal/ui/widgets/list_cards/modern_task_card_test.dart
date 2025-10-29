import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_task_card.dart';
import 'package:lotti/features/tasks/ui/compact_task_progress.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {
  @override
  CategoryDefinition? getCategoryById(String? id) {
    return id == 'test-category-id'
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
  Stream<JournalEntity?> getStream() {
    return Stream.value(null);
  }
}

class MockTagsService extends Mock implements TagsService {
  @override
  Map<String, TagEntity> tagsById = {};

  @override
  Stream<List<TagEntity>> watchTags() {
    return Stream.value(<TagEntity>[]);
  }

  @override
  TagEntity? getTagById(String id) {
    return null;
  }
}

void main() {
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNavService mockNavService;
  late MockTimeService mockTimeService;
  late MockTagsService mockTagsService;
  late DateTime testDate;

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNavService = MockNavService();
    mockTimeService = MockTimeService();
    mockTagsService = MockTagsService();
    testDate = DateTime(2024, 1, 15, 10, 30);

    // Register mock services
    getIt.allowReassignment = true;
    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<TagsService>(mockTagsService);
  });

  tearDown(() {
    // Clean up registered services
    getIt
      ..unregister<EntitiesCacheService>()
      ..unregister<TimeService>()
      ..unregister<NavService>()
      ..unregister<TagsService>();
  });

  Task createTestTask({
    String id = 'test-task-id',
    String title = 'Test Task Title',
    TaskStatus? status,
    DateTime? due,
    String? categoryId = 'test-category-id',
    bool starred = false,
  }) {
    final metadata = Metadata(
      id: id,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate.add(const Duration(hours: 1)),
      categoryId: categoryId,
      starred: starred,
    );

    final taskStatus = status ??
        TaskStatus.open(
          id: 'status-id',
          createdAt: testDate,
          utcOffset: testDate.timeZoneOffset.inMinutes,
        );

    final taskData = TaskData(
      status: taskStatus,
      dateFrom: testDate,
      dateTo: testDate.add(const Duration(hours: 1)),
      statusHistory: [],
      title: title,
      due: due,
    );

    const entryText = EntryText(
      plainText: 'Test task description',
      markdown: 'Test task description',
    );

    return Task(
      meta: metadata,
      data: taskData,
      entryText: entryText,
    );
  }

  group('ModernTaskCard', () {
    testWidgets('renders basic task correctly', (WidgetTester tester) async {
      final task = createTestTask();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      // Check core components are present
      expect(find.byType(ModernBaseCard), findsOneWidget);
      expect(find.byType(ModernCardContent), findsOneWidget);
      expect(find.byType(ModernIconContainer), findsOneWidget);
      expect(find.byType(CategoryIconCompact), findsOneWidget);
      expect(find.byType(TimeRecordingIcon), findsOneWidget);
      expect(find.byType(CompactTaskProgress), findsOneWidget);
      // Status row now includes two chips: priority + status
      expect(find.byType(ModernStatusChip), findsWidgets);

      // Check task title is displayed
      expect(find.text('Test Task Title'), findsOneWidget);
    });

    testWidgets('displays correct status chip for open task',
        (WidgetTester tester) async {
      final task = createTestTask(
        status: TaskStatus.open(
          id: 'status-id',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('displays correct status chip for in progress task',
        (WidgetTester tester) async {
      final task = createTestTask(
        status: TaskStatus.inProgress(
          id: 'status-id',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('In Progress'), findsOneWidget);
      expect(
        find.byIcon(Icons.play_circle_outline_rounded),
        findsOneWidget,
      );
    });

    testWidgets('shows priority chip with short code',
        (WidgetTester tester) async {
      final task = createTestTask(
        status: TaskStatus.open(
          id: 'status-id',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      // Default priority is P2
      expect(find.text('P2'), findsOneWidget);

      // No exclamation priority icon should be present on the card
      expect(find.byIcon(Icons.priority_high_rounded), findsNothing);
    });

    testWidgets('displays correct status chip for done task',
        (WidgetTester tester) async {
      final task = createTestTask(
        status: TaskStatus.done(
          id: 'status-id',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('displays correct status chip for blocked task',
        (WidgetTester tester) async {
      final task = createTestTask(
        status: TaskStatus.blocked(
          id: 'status-id',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'Test blocker reason',
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blocked'), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    });

    testWidgets('displays correct status chip for groomed task',
        (WidgetTester tester) async {
      final task = createTestTask(
        status: TaskStatus.groomed(
          id: 'status-id',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Groomed'), findsOneWidget);
      expect(find.byIcon(Icons.done_outline_rounded), findsOneWidget);
    });

    testWidgets('displays correct status chip for on hold task',
        (WidgetTester tester) async {
      final task = createTestTask(
        status: TaskStatus.onHold(
          id: 'status-id',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'Test on hold reason',
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('On Hold'), findsOneWidget);
      expect(
        find.byIcon(Icons.pause_circle_outline_rounded),
        findsOneWidget,
      );
    });

    testWidgets('displays correct status chip for rejected task',
        (WidgetTester tester) async {
      final task = createTestTask(
        status: TaskStatus.rejected(
          id: 'status-id',
          createdAt: testDate,
          utcOffset: 0,
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rejected'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });

    testWidgets('displays due date when present', (WidgetTester tester) async {
      final dueDate = DateTime(2024, 2, 20);
      final task = createTestTask(due: dueDate);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      // Check due date is displayed
      expect(find.text('Feb 20'), findsOneWidget);
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
    });

    testWidgets('does not display due date when not present',
        (WidgetTester tester) async {
      final task = createTestTask();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      // Check due date icon is not displayed
      expect(find.byIcon(Icons.event_rounded), findsNothing);
    });

    testWidgets('navigates to task detail on tap', (WidgetTester tester) async {
      final task = createTestTask(id: 'test-task-123');

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the card
      await tester.tap(find.byType(ModernBaseCard));
      await tester.pumpAndSettle();

      // Verify navigation was triggered
      expect(mockNavService.navigationHistory.length, 1);
      expect(mockNavService.navigationHistory.last, '/tasks/test-task-123');
    });

    testWidgets('displays task without category', (WidgetTester tester) async {
      final task = createTestTask(categoryId: null);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      // Should still render without errors
      expect(find.byType(ModernTaskCard), findsOneWidget);
      expect(find.byType(CategoryIconCompact), findsOneWidget);
    });

    testWidgets('long task title is handled properly',
        (WidgetTester tester) async {
      final task = createTestTask(
        title:
            'This is a very long task title that should be truncated with ellipsis when it exceeds the available space in the card',
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: SizedBox(
            width: 400, // Constrain width to test text overflow
            child: ModernTaskCard(task: task),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The title should still be present (even if truncated)
      expect(
        find.text(
            'This is a very long task title that should be truncated with ellipsis when it exceeds the available space in the card'),
        findsOneWidget,
      );
    });

    testWidgets('applies correct margins', (WidgetTester tester) async {
      final task = createTestTask();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTaskCard(task: task),
        ),
      );
      await tester.pumpAndSettle();

      final modernBaseCard = tester.widget<ModernBaseCard>(
        find.byType(ModernBaseCard),
      );
      expect(
        modernBaseCard.margin,
        const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: AppTheme.cardSpacing / 2,
        ),
      );
    });

    testWidgets('renders label chips when labels present', (tester) async {
      // Arrange cache to return labels
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
      when(() => mockEntitiesCacheService.getLabelById('l1')).thenReturn(
        LabelDefinition(
          id: 'l1',
          name: 'Alpha',
          color: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );
      when(() => mockEntitiesCacheService.getLabelById('l2')).thenReturn(
        LabelDefinition(
          id: 'l2',
          name: 'Beta',
          color: '#00FF00',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );

      final task = createTestTask().copyWith(
        meta: createTestTask().meta.copyWith(labelIds: const ['l1', 'l2']),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(child: ModernTaskCard(task: task)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Wrap), findsWidgets);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('filters private labels when showPrivate is false',
        (tester) async {
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(false);
      when(() => mockEntitiesCacheService.getLabelById('l1')).thenReturn(
        LabelDefinition(
          id: 'l1',
          name: 'Hidden',
          color: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          private: true,
        ),
      );

      final task = createTestTask().copyWith(
        meta: createTestTask().meta.copyWith(labelIds: const ['l1']),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(child: ModernTaskCard(task: task)),
      );
      await tester.pumpAndSettle();

      // No labels should render
      expect(find.text('Hidden'), findsNothing);
      // No Wrap for labels section
      // There may be other Wraps; ensure label chip text absent is sufficient.
    });
  });
}
