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

  /// Helper to build a [GameyTaskCard] with the given task and options.
  Widget buildCard(Task task, {bool dark = false}) {
    if (dark) {
      return DarkRiverpodWidgetTestBench(
        overrides: testOverrides,
        child: GameyTaskCard(task: task),
      );
    }
    return RiverpodWidgetTestBench(
      overrides: testOverrides,
      child: GameyTaskCard(task: task),
    );
  }

  /// Helper to create a task with a given status and title.
  Task taskWithStatus(
    Task base,
    TaskStatus status, {
    String? title,
    List<String>? labelIds,
  }) {
    return Task(
      meta: labelIds != null
          ? Metadata(
              id: base.meta.id,
              createdAt: base.meta.createdAt,
              updatedAt: base.meta.updatedAt,
              dateFrom: base.meta.dateFrom,
              dateTo: base.meta.dateTo,
              labelIds: labelIds,
            )
          : base.meta,
      data: TaskData(
        status: status,
        dateFrom: base.data.dateFrom,
        dateTo: base.data.dateTo,
        statusHistory: [],
        title: title ?? base.data.title,
      ),
      entryText: base.entryText,
    );
  }

  group('GameyTaskCard', () {
    testWidgets('renders card with title, status badge, and correct structure',
        (tester) async {
      await tester.pumpWidget(buildCard(testTask));
      await tester.pumpAndSettle();

      // Card structure
      expect(find.byType(GameySubtleCard), findsOneWidget);
      expect(find.byType(GameyIconBadge), findsOneWidget);

      // Title text content
      expect(find.text('Test Task Title'), findsOneWidget);

      // Status chip shows "Open" for the default open status
      expect(find.text('Open'), findsOneWidget);

      // Priority chip shows default priority
      expect(find.text('P2'), findsOneWidget);
    });

    testWidgets('navigates to task details on tap', (tester) async {
      await tester.pumpWidget(buildCard(testTask));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(GameyTaskCard));
      await tester.pump();

      expect(
        mockNavService.navigationHistory,
        contains('/tasks/test-task-id'),
      );
    });

    testWidgets('renders correct status label for each status type',
        (tester) async {
      final statusCases = [
        (
          TaskStatus.inProgress(
            id: 'sid',
            createdAt: now,
            utcOffset: now.timeZoneOffset.inMinutes,
          ),
          'In Progress',
        ),
        (
          TaskStatus.done(
            id: 'sid',
            createdAt: now,
            utcOffset: now.timeZoneOffset.inMinutes,
          ),
          'Done',
        ),
        (
          TaskStatus.blocked(
            id: 'sid',
            createdAt: now,
            utcOffset: now.timeZoneOffset.inMinutes,
            reason: 'Waiting',
          ),
          'Blocked',
        ),
      ];

      for (final (status, expectedLabel) in statusCases) {
        final task = taskWithStatus(testTask, status, title: expectedLabel);
        await tester.pumpWidget(buildCard(task));
        await tester.pumpAndSettle();

        expect(
          find.text(expectedLabel),
          findsWidgets,
          reason: 'Should show "$expectedLabel" status chip',
        );
      }
    });

    testWidgets('renders in dark mode with correct structure', (tester) async {
      await tester.pumpWidget(buildCard(testTask, dark: true));
      await tester.pumpAndSettle();

      expect(find.text('Test Task Title'), findsOneWidget);
      expect(find.byType(GameySubtleCard), findsOneWidget);
      expect(find.byType(GameyIconBadge), findsOneWidget);
    });

    testWidgets('renders card when task has label IDs', (tester) async {
      final taskWithLabels = taskWithStatus(
        testTask,
        testTask.data.status,
        labelIds: ['label-1', 'label-2'],
      );

      await tester.pumpWidget(buildCard(taskWithLabels));
      await tester.pumpAndSettle();

      // Card renders successfully (labels are null from mock, so no LabelChips)
      expect(find.byType(GameySubtleCard), findsOneWidget);
      expect(find.text('Test Task Title'), findsOneWidget);
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

      testWidgets('priority chip uses urgency palette (not unified blue)',
          (tester) async {
        await tester.pumpWidget(buildCard(testTask));
        await tester.pumpAndSettle();

        final container = findGradientChipContainer(tester, 'P2');
        expect(container, isNotNull);

        final decoration = container!.decoration! as BoxDecoration;
        final gradient = decoration.gradient! as LinearGradient;

        expect(gradient.colors.first,
            equals(GameyColors.priorityColor(TaskPriority.p2Medium)));
        expect(gradient.colors.first, isNot(equals(GameyColors.gameyAccent)));
      });

      testWidgets('status chip uses semantic orange for open status',
          (tester) async {
        await tester.pumpWidget(buildCard(testTask));
        await tester.pumpAndSettle();

        final container = findGradientChipContainer(tester, 'Open');
        expect(container, isNotNull);

        final decoration = container!.decoration! as BoxDecoration;
        final gradient = decoration.gradient! as LinearGradient;

        expect(gradient.colors.first, equals(GameyColors.primaryOrange));
      });

      testWidgets('priority and status chips have different colors',
          (tester) async {
        await tester.pumpWidget(buildCard(testTask));
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
        final blockedTask = taskWithStatus(
          testTask,
          TaskStatus.blocked(
            id: 'status-id',
            createdAt: now,
            utcOffset: now.timeZoneOffset.inMinutes,
            reason: 'Blocked reason',
          ),
          title: 'Blocked Task',
        );

        await tester.pumpWidget(buildCard(blockedTask));
        await tester.pumpAndSettle();

        final container = findGradientChipContainer(tester, 'Blocked');
        expect(container, isNotNull);

        final decoration = container!.decoration! as BoxDecoration;
        final gradient = decoration.gradient! as LinearGradient;

        expect(gradient.colors.first, equals(GameyColors.primaryRed));
      });

      testWidgets('each priority level uses distinct urgency palette color',
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

          await tester.pumpWidget(buildCard(task));
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
