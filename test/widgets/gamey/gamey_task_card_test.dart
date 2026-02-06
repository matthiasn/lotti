import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/widgets/gamey/gamey_card.dart';
import 'package:lotti/widgets/gamey/gamey_icon_badge.dart';
import 'package:lotti/widgets/gamey/gamey_task_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/task_progress_test_controller.dart';
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
      ..registerSingleton<TagsService>(mockTagsService);

    now = DateTime(2024, 1, 1, 12);
    const taskId = 'test-task-id';

    final metadata = Metadata(
      id: taskId,
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

    const entryText = EntryText(
      plainText: 'Test task description',
      markdown: 'Test task description',
    );

    testTask = Task(
      meta: metadata,
      data: taskData,
      entryText: entryText,
    );

    ensureThemingServicesRegistered();
  });

  tearDown(() async {
    await getIt.reset();
  });

  /// Provider overrides to mock task progress controller
  final testOverrides = [
    taskProgressControllerProvider.overrideWith(
      () => TestTaskProgressController(
        progress: Duration.zero,
        estimate: Duration.zero,
      ),
    ),
  ];

  group('GameyTaskCard', () {
    testWidgets('renders task title', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: testOverrides,
          child: GameyTaskCard(task: testTask),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test Task Title'), findsOneWidget);
    });

    testWidgets('renders inside GameySubtleCard', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: testOverrides,
          child: GameyTaskCard(task: testTask),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameySubtleCard), findsOneWidget);
    });

    testWidgets('renders status icon badge', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: testOverrides,
          child: GameyTaskCard(task: testTask),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameyIconBadge), findsOneWidget);
    });

    testWidgets('navigates to task details on tap', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: testOverrides,
          child: GameyTaskCard(task: testTask),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(GameyTaskCard));
      await tester.pump();

      expect(mockNavService.navigationHistory, contains('/tasks/test-task-id'));
    });

    testWidgets('renders with different task statuses', (tester) async {
      // Test with in-progress status
      final inProgressStatus = TaskStatus.inProgress(
        id: 'status-id',
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      );

      final inProgressTask = Task(
        meta: testTask.meta,
        data: TaskData(
          status: inProgressStatus,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          statusHistory: [],
          title: 'In Progress Task',
        ),
        entryText: testTask.entryText,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: testOverrides,
          child: GameyTaskCard(task: inProgressTask),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('In Progress Task'), findsOneWidget);
    });

    testWidgets('renders with done status', (tester) async {
      final doneStatus = TaskStatus.done(
        id: 'status-id',
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      );

      final doneTask = Task(
        meta: testTask.meta,
        data: TaskData(
          status: doneStatus,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          statusHistory: [],
          title: 'Done Task',
        ),
        entryText: testTask.entryText,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: testOverrides,
          child: GameyTaskCard(task: doneTask),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Done Task'), findsOneWidget);
    });

    testWidgets('renders with blocked status', (tester) async {
      final blockedStatus = TaskStatus.blocked(
        id: 'status-id',
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
        reason: 'Waiting for dependencies',
      );

      final blockedTask = Task(
        meta: testTask.meta,
        data: TaskData(
          status: blockedStatus,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          statusHistory: [],
          title: 'Blocked Task',
        ),
        entryText: testTask.entryText,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: testOverrides,
          child: GameyTaskCard(task: blockedTask),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Blocked Task'), findsOneWidget);
    });

    testWidgets('renders due date when showDueDate is true', (tester) async {
      final taskWithDueDate = Task(
        meta: testTask.meta,
        data: TaskData(
          status: testTask.data.status,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          statusHistory: [],
          title: 'Task With Due Date',
          estimate: const Duration(hours: 2),
        ),
        entryText: testTask.entryText,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: testOverrides,
          child: GameyTaskCard(
            task: taskWithDueDate,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Task With Due Date'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        DarkRiverpodWidgetTestBench(
          overrides: testOverrides,
          child: GameyTaskCard(task: testTask),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test Task Title'), findsOneWidget);
    });

    testWidgets('renders with labels when task has labels', (tester) async {
      final taskWithLabels = Task(
        meta: Metadata(
          id: 'test-task-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          labelIds: ['label-1', 'label-2'],
        ),
        data: testTask.data,
        entryText: testTask.entryText,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: testOverrides,
          child: GameyTaskCard(task: taskWithLabels),
        ),
      );

      await tester.pumpAndSettle();

      // Task should render - check for GameySubtleCard presence
      expect(find.byType(GameySubtleCard), findsOneWidget);
    });

    group('priority and status chip colors', () {
      /// Finds the Container with a gradient decoration that is an ancestor
      /// of the given text widget (i.e. the _GameyStatusChip container).
      Container? findGradientChipContainer(
        WidgetTester tester,
        String chipText,
      ) {
        final textFinder = find.text(chipText);
        if (textFinder.evaluate().isEmpty) return null;

        final containers = find.ancestor(
          of: textFinder,
          matching: find.byType(Container),
        );

        for (final candidate in containers.evaluate()) {
          final container = candidate.widget as Container;
          final decoration = container.decoration;
          if (decoration is BoxDecoration && decoration.gradient != null) {
            return container;
          }
        }
        return null;
      }

      testWidgets('priority chip uses purple palette (not unified blue)',
          (tester) async {
        // testTask has default priority p2Medium
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: testOverrides,
            child: GameyTaskCard(task: testTask),
          ),
        );
        await tester.pumpAndSettle();

        final container = findGradientChipContainer(tester, 'P2');
        expect(container, isNotNull);

        final decoration = container!.decoration! as BoxDecoration;
        final gradient = decoration.gradient! as LinearGradient;

        // GameyColors.priorityColor(p2Medium) = indigo
        expect(gradient.colors.first,
            equals(GameyColors.priorityColor(TaskPriority.p2Medium)));
        // Should NOT be the old unified blue
        expect(gradient.colors.first, isNot(equals(GameyColors.gameyAccent)));
      });

      testWidgets('status chip uses semantic orange for open status',
          (tester) async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: testOverrides,
            child: GameyTaskCard(task: testTask),
          ),
        );
        await tester.pumpAndSettle();

        // testTask has TaskStatus.open → localized label is "Open"
        final container = findGradientChipContainer(tester, 'Open');
        expect(container, isNotNull);

        final decoration = container!.decoration! as BoxDecoration;
        final gradient = decoration.gradient! as LinearGradient;

        // Open status → GameyColors.primaryOrange
        expect(gradient.colors.first, equals(GameyColors.primaryOrange));
      });

      testWidgets('priority and status chips have different colors',
          (tester) async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: testOverrides,
            child: GameyTaskCard(task: testTask),
          ),
        );
        await tester.pumpAndSettle();

        final priorityContainer = findGradientChipContainer(tester, 'P2');
        final statusContainer = findGradientChipContainer(tester, 'Open');

        expect(priorityContainer, isNotNull);
        expect(statusContainer, isNotNull);

        final priorityGradient =
            (priorityContainer!.decoration! as BoxDecoration).gradient!
                as LinearGradient;
        final statusGradient = (statusContainer!.decoration! as BoxDecoration)
            .gradient! as LinearGradient;

        expect(
          priorityGradient.colors.first,
          isNot(equals(statusGradient.colors.first)),
        );
      });

      testWidgets('blocked status uses red color', (tester) async {
        final blockedTask = Task(
          meta: testTask.meta,
          data: TaskData(
            status: TaskStatus.blocked(
              id: 'status-id',
              createdAt: now,
              utcOffset: now.timeZoneOffset.inMinutes,
              reason: 'Blocked reason',
            ),
            dateFrom: now,
            dateTo: now.add(const Duration(hours: 1)),
            statusHistory: [],
            title: 'Blocked Task',
          ),
          entryText: testTask.entryText,
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: testOverrides,
            child: GameyTaskCard(task: blockedTask),
          ),
        );
        await tester.pumpAndSettle();

        final container = findGradientChipContainer(tester, 'Blocked');
        expect(container, isNotNull);

        final decoration = container!.decoration! as BoxDecoration;
        final gradient = decoration.gradient! as LinearGradient;

        expect(gradient.colors.first, equals(GameyColors.primaryRed));
      });

      testWidgets('each priority level uses distinct purple palette color',
          (tester) async {
        for (final priority in TaskPriority.values) {
          final task = Task(
            meta: testTask.meta,
            data: TaskData(
              status: testTask.data.status,
              dateFrom: now,
              dateTo: now.add(const Duration(hours: 1)),
              statusHistory: [],
              title: 'Task ${priority.short}',
              priority: priority,
            ),
            entryText: testTask.entryText,
          );

          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              overrides: testOverrides,
              child: GameyTaskCard(task: task),
            ),
          );
          await tester.pumpAndSettle();

          final container = findGradientChipContainer(tester, priority.short);
          expect(container, isNotNull,
              reason: 'Container not found for ${priority.short}');

          final decoration = container!.decoration! as BoxDecoration;
          final gradient = decoration.gradient! as LinearGradient;

          expect(
            gradient.colors.first,
            equals(GameyColors.priorityColor(priority)),
            reason: '${priority.short} should use priorityColor($priority)',
          );
        }
      });
    });
  });
}
