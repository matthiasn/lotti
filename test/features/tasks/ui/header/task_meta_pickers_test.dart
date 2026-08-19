import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_pickers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Hosts one button per picker so each [TaskMetaPickers] entry point can be
/// exercised directly, independent of the fly-out or the header.
class _PickerHost extends ConsumerWidget {
  const _PickerHost({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        TextButton(
          onPressed: () => TaskMetaPickers.showStatusPicker(context, ref, task),
          child: const Text('open-status'),
        ),
        TextButton(
          onPressed: () =>
              TaskMetaPickers.showPriorityPicker(context, ref, task),
          child: const Text('open-priority'),
        ),
        TextButton(
          onPressed: () =>
              TaskMetaPickers.showCategoryPicker(context, ref, task),
          child: const Text('open-category'),
        ),
        TextButton(
          onPressed: () =>
              TaskMetaPickers.showDueDatePicker(context, ref, task),
          child: const Text('open-due'),
        ),
        TextButton(
          onPressed: () =>
              TaskMetaPickers.showEstimatePickerForTask(context, ref, task),
          child: const Text('open-estimate'),
        ),
        TextButton(
          onPressed: () => TaskMetaPickers.openLabelSelector(context, task),
          child: const Text('open-labels'),
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockEntitiesCacheService mockCache;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;

  final now = DateTime(2026, 4, 20, 12);

  setUp(() async {
    mockCache = MockEntitiesCacheService();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();

    when(
      () => mockJournalDb.typedLinksForTaskIds(
        any(),
        types: any(named: 'types'),
      ),
    ).thenAnswer((_) async => <EntryLink>[]);
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(() => mockCache.showPrivateEntries).thenReturn(true);
    when(() => mockCache.getCategoryById(any())).thenReturn(null);
    when(() => mockCache.getLabelById(any())).thenReturn(null);
    when(
      () => mockCache.sortedCategories,
    ).thenReturn(const <CategoryDefinition>[]);
    when(() => mockCache.sortedLabels).thenReturn(const <LabelDefinition>[]);
    when(
      () => mockCache.filterLabelsForCategory(any(), any()),
    ).thenAnswer(
      (invocation) =>
          invocation.positionalArguments.first as List<LabelDefinition>,
    );

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
          ..registerSingleton<EntitiesCacheService>(mockCache)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<TimeService>(MockTimeService())
          ..registerSingleton<NavService>(MockNavService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Task buildTask({
    String id = 'task-1',
    TaskStatus? status,
    DateTime? due,
  }) {
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: TaskData(
        status:
            status ??
            TaskStatus.open(id: 'status-1', createdAt: now, utcOffset: 0),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: 'Test Task',
        due: due,
      ),
    );
  }

  Widget pumpHost({required Task task, ToggleCallTracker? tracker}) {
    return ProviderScope(
      overrides: [
        entryControllerProvider(task.id).overrideWith(
          () => FakeEntryController(task, tracker: tracker),
        ),
      ],
      child: MaterialApp(
        theme: DesignSystemTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FormBuilderLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _PickerHost(task: task)),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('TaskMetaPickers — selection persists through EntryController', () {
    testWidgets('status: selecting a status calls updateTaskStatus', (
      tester,
    ) async {
      final tracker = ToggleCallTracker();
      await tester.pumpWidget(pumpHost(task: buildTask(), tracker: tracker));
      await settle(tester);

      await tester.tap(find.text('open-status'));
      await settle(tester);
      await tester.tap(find.text('In Progress'));
      await settle(tester);

      expect(tracker.updateTaskStatusCalls, hasLength(1));
    });

    testWidgets('priority: selecting P0 calls updateTaskPriority', (
      tester,
    ) async {
      final tracker = ToggleCallTracker();
      await tester.pumpWidget(pumpHost(task: buildTask(), tracker: tracker));
      await settle(tester);

      await tester.tap(find.text('open-priority'));
      await settle(tester);
      expect(find.text('Select priority'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('task-priority-P0')));
      await settle(tester);

      expect(tracker.updateTaskPriorityCalls, equals(['P0']));
    });

    testWidgets('category: selecting one calls updateCategoryId', (
      tester,
    ) async {
      final pickable = CategoryDefinition(
        id: 'cat-pick',
        createdAt: now,
        updatedAt: now,
        name: 'Focus',
        color: '#FF0000',
        vectorClock: null,
        private: false,
        active: true,
      );
      when(() => mockCache.sortedCategories).thenReturn([pickable]);
      when(() => mockCache.getCategoryById('cat-pick')).thenReturn(pickable);

      final tracker = ToggleCallTracker();
      await tester.pumpWidget(pumpHost(task: buildTask(), tracker: tracker));
      await settle(tester);

      await tester.tap(find.text('open-category'));
      await settle(tester);
      expect(find.byType(CategoryPickerSheet), findsOneWidget);
      await tester.tap(find.text('Focus'));
      await settle(tester);

      expect(tracker.updateCategoryIdCalls, equals(['cat-pick']));
    });

    testWidgets('due date: Done with no initial date saves the picked date', (
      tester,
    ) async {
      final tracker = ToggleCallTracker();
      await tester.pumpWidget(pumpHost(task: buildTask(), tracker: tracker));
      await settle(tester);

      await tester.tap(find.text('open-due'));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);

      expect(tracker.saveCalls, hasLength(1));
      expect(tracker.saveCalls.single['dueDate'], isA<DateTime>());
      expect(tracker.saveCalls.single['clearDueDate'], isFalse);
    });

    testWidgets('due date: Clear on a task with a due date clears it', (
      tester,
    ) async {
      final tracker = ToggleCallTracker();
      await tester.pumpWidget(
        pumpHost(
          task: buildTask(due: DateTime(2026, 4, 25)),
          tracker: tracker,
        ),
      );
      await settle(tester);

      await tester.tap(find.text('open-due'));
      await settle(tester);
      await tester.tap(find.text('Clear'));
      await settle(tester);

      expect(tracker.saveCalls, hasLength(1));
      expect(tracker.saveCalls.single['clearDueDate'], isTrue);
      expect(tracker.saveCalls.single['dueDate'], isNull);
    });

    testWidgets(
      'estimate: changing the duration and tapping Done saves it',
      (tester) async {
        final tracker = ToggleCallTracker();
        await tester.pumpWidget(pumpHost(task: buildTask(), tracker: tracker));
        await settle(tester);

        await tester.tap(find.text('open-estimate'));
        await settle(tester);

        // Directly invoke the picker's duration-changed callback to simulate
        // the user scrolling to 1h, so selectedDuration diverges from the
        // zero initial and Done fires onEstimateChanged.
        final picker = tester.widget<CupertinoTimerPicker>(
          find.byType(CupertinoTimerPicker),
        );
        picker.onTimerDurationChanged(const Duration(hours: 1));
        await tester.tap(find.text('Done'));
        await settle(tester);

        expect(tracker.saveCalls, hasLength(1));
        expect(
          tracker.saveCalls.single['estimate'],
          equals(const Duration(hours: 1)),
        );
      },
    );

    testWidgets('labels: opens the label selector modal', (tester) async {
      await tester.pumpWidget(pumpHost(task: buildTask()));
      await settle(tester);

      await tester.tap(find.text('open-labels'));
      await settle(tester);

      expect(find.byType(EntityPickerSheet), findsOneWidget);
    });
  });

  group('TaskMetaPickers — blocked-status follow-up prompt', () {
    late MockFts5Db mockFts5Db;

    EntryLink blocksLink({
      required String id,
      required String fromId,
      required String toId,
    }) => EntryLink.blocks(
      id: id,
      fromId: fromId,
      toId: toId,
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
    );

    void stubBlockers(String taskId, List<EntryLink> links) {
      when(
        () => mockJournalDb.typedLinksForTaskIds(
          {taskId},
          types: {'BlocksLink'},
        ),
      ).thenAnswer((_) async => links);
    }

    setUp(() {
      mockFts5Db = MockFts5Db();
      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <JournalEntity>[]);
      when(
        () => mockFts5Db.watchFullTextMatches(any()),
      ).thenAnswer((_) => Stream.value(<String>[]));
      getIt.registerSingleton<Fts5Db>(mockFts5Db);

      // BlockingTaskPickerModal's onTaskSelected awaits a HapticFeedback
      // call before popping — never resolves under the test binding without
      // a mock handler (see test/README.md's platform-channel section).
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> selectBlockedStatus(WidgetTester tester, Task task) async {
      await tester.pumpWidget(pumpHost(task: task));
      await settle(tester);

      await tester.tap(find.text('open-status'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('task-status-BLOCKED')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets(
      'prompts for a blocker when a task becomes Blocked with no existing '
      'blocker',
      (tester) async {
        final task = buildTask();
        stubBlockers(task.id, []);

        await selectBlockedStatus(tester, task);

        expect(find.text("What's blocking this?"), findsOneWidget);
      },
    );

    testWidgets('does not prompt when the task already has an open blocker', (
      tester,
    ) async {
      final task = buildTask();
      final blocker = buildTask(id: 'blocker-1');
      stubBlockers(task.id, [
        blocksLink(id: 'l1', fromId: 'blocker-1', toId: task.id),
      ]);
      when(
        () => mockJournalDb.entriesForIds([blocker.meta.id]),
      ).thenReturn(MockSelectable([toDbEntity(blocker)]));

      await selectBlockedStatus(tester, task);

      expect(find.text("What's blocking this?"), findsNothing);
    });

    testWidgets(
      'does not re-prompt when reconfirming an already-Blocked status',
      (tester) async {
        final task = buildTask(
          status: TaskStatus.blocked(
            id: 's',
            createdAt: now,
            utcOffset: 0,
            reason: 'Blocked by: something',
          ),
        );
        stubBlockers(task.id, []);

        await selectBlockedStatus(tester, task);

        expect(find.text("What's blocking this?"), findsNothing);
      },
    );

    testWidgets(
      'does not prompt when the task is already blocked by an unresolved '
      'link',
      (tester) async {
        final task = buildTask();
        stubBlockers(task.id, [
          blocksLink(id: 'l1', fromId: 'missing-blocker', toId: task.id),
        ]);
        when(
          () => mockJournalDb.entriesForIds(['missing-blocker']),
        ).thenReturn(MockSelectable(const []));

        await selectBlockedStatus(tester, task);

        expect(find.text("What's blocking this?"), findsNothing);
      },
    );
  });
}
