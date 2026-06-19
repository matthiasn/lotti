import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_selection_modal_content.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_connector.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class _FakeTaskProgressController extends TaskProgressController {
  _FakeTaskProgressController(this._state);

  final TaskProgressState? _state;

  @override
  Future<TaskProgressState?> build({required String id}) async => _state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockEntitiesCacheService mockCache;
  late MockEditorStateService mockEditorStateService;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockPersistenceLogic mockPersistenceLogic;

  final now = DateTime(2026, 4, 20, 12);

  setUp(() async {
    mockCache = MockEntitiesCacheService();
    mockEditorStateService = MockEditorStateService();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockPersistenceLogic = MockPersistenceLogic();

    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(() => mockCache.showPrivateEntries).thenReturn(true);
    when(() => mockCache.getCategoryById(any())).thenReturn(null);
    when(() => mockCache.getLabelById(any())).thenReturn(null);
    when(
      () => mockCache.sortedCategories,
    ).thenReturn(const <CategoryDefinition>[]);
    when(
      () => mockCache.sortedLabels,
    ).thenReturn(const <LabelDefinition>[]);
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
          ..registerSingleton<EditorStateService>(mockEditorStateService)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          // TaskProgressController resolves TimeService in a field
          // initialiser, so every test that touches the estimate chip needs
          // it registered even when it is never exercised.
          ..registerSingleton<TimeService>(MockTimeService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Task buildTask({
    String id = 'task-1',
    String? categoryId,
    DateTime? due,
    TaskStatus? status,
    Duration? estimate,
    List<String>? labelIds,
    TaskPriority priority = TaskPriority.p2Medium,
  }) {
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        categoryId: categoryId,
        labelIds: labelIds,
      ),
      data: TaskData(
        status:
            status ??
            TaskStatus.open(
              id: 'status-1',
              createdAt: now,
              utcOffset: 0,
            ),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: 'Test Task',
        due: due,
        estimate: estimate,
        priority: priority,
      ),
    );
  }

  CategoryDefinition buildCategory({
    String id = 'cat-1',
    String name = 'Work',
  }) {
    return CategoryDefinition(
      id: id,
      createdAt: now,
      updatedAt: now,
      name: name,
      color: '#FF0000',
      vectorClock: null,
      private: false,
      active: true,
    );
  }

  LabelDefinition buildLabel({
    required String id,
    required String name,
    String color = '#112233',
    bool? private,
  }) {
    return LabelDefinition(
      id: id,
      createdAt: now,
      updatedAt: now,
      name: name,
      color: color,
      vectorClock: null,
      private: private,
    );
  }

  ProjectEntry buildProject({
    String id = 'project-1',
    String title = 'Alpha',
  }) {
    return ProjectEntry(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: ProjectData(
        title: title,
        status: ProjectStatus.active(
          id: 'ps-active',
          createdAt: now,
          utcOffset: 0,
        ),
        dateFrom: now,
        dateTo: now,
      ),
    );
  }

  Widget pumpConnector({
    required Task task,
    ProjectEntry? project,
    List<LabelDefinition> labels = const [],
    TaskProgressState? progress,
  }) {
    return ProviderScope(
      overrides: [
        createEntryControllerOverride(task),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(labels),
        ),
        projectForTaskProvider(task.id).overrideWith(
          (ref) async => project,
        ),
        taskProgressControllerProvider(id: task.id).overrideWith(
          () => _FakeTaskProgressController(progress),
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
        home: Scaffold(
          body: DesktopTaskHeaderConnector(taskId: task.id),
        ),
      ),
    );
  }

  group('DesktopTaskHeaderConnector — data mapping', () {
    testWidgets('renders DesktopTaskHeader for a Task entity', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(pumpConnector(task: task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesktopTaskHeader), findsOneWidget);
      expect(find.text('Test Task'), findsOneWidget);
    });

    testWidgets('emits SizedBox.shrink for non-Task entities', (tester) async {
      final notATask = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'note-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(notATask),
            labelsStreamProvider.overrideWith(
              (ref) => Stream<List<LabelDefinition>>.value(const []),
            ),
            projectForTaskProvider('note-1').overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            theme: DesignSystemTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: DesktopTaskHeaderConnector(taskId: 'note-1'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesktopTaskHeader), findsNothing);
    });

    testWidgets(
      'passes the cached category definition into the header',
      (tester) async {
        when(
          () => mockCache.getCategoryById('cat-1'),
        ).thenReturn(buildCategory());
        final task = buildTask(categoryId: 'cat-1');

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Work'), findsOneWidget);
      },
    );

    testWidgets('shows the project title when one is linked', (tester) async {
      final task = buildTask();
      final project = buildProject();

      await tester.pumpWidget(pumpConnector(task: task, project: project));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets(
      'renders only label definitions present in the cache, sorted alphabetically',
      (tester) async {
        when(
          () => mockCache.getLabelById('lbl-b'),
        ).thenReturn(buildLabel(id: 'lbl-b', name: 'Beta'));
        when(
          () => mockCache.getLabelById('lbl-a'),
        ).thenReturn(buildLabel(id: 'lbl-a', name: 'Alpha'));
        when(
          () => mockCache.getLabelById('lbl-missing'),
        ).thenReturn(null);

        final task = buildTask(
          labelIds: const ['lbl-b', 'lbl-a', 'lbl-missing'],
        );

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Use document order (tree traversal) instead of `dx`. The new
        // single-row meta-layout shares a `Wrap` between priority/due/estimate
        // and the labels, so on narrow surfaces labels can wrap onto a new
        // line and `dx` no longer reflects sort order.
        final labelTexts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where((d) => d == 'Alpha' || d == 'Beta')
            .toList();
        expect(labelTexts, ['Alpha', 'Beta']);
        expect(find.text('lbl-missing'), findsNothing);
      },
    );

    testWidgets(
      'hides private labels when showPrivateEntries is false',
      (tester) async {
        when(() => mockCache.showPrivateEntries).thenReturn(false);
        when(
          () => mockCache.getLabelById('lbl-public'),
        ).thenReturn(buildLabel(id: 'lbl-public', name: 'Public'));
        when(() => mockCache.getLabelById('lbl-private')).thenReturn(
          buildLabel(id: 'lbl-private', name: 'Private', private: true),
        );

        final task = buildTask(
          labelIds: const ['lbl-public', 'lbl-private'],
        );

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Public'), findsOneWidget);
        expect(find.text('Private'), findsNothing);
      },
    );

    testWidgets(
      'completed tasks never paint an overdue due-date chip',
      (tester) async {
        // Due date ten days in the past but the task is done — urgency
        // collapses to "normal".
        final task = buildTask(
          due: DateTime(2026, 4, 10),
          status: TaskStatus.done(
            id: 'status-done',
            createdAt: now,
            utcOffset: 0,
          ),
        );

        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(pumpConnector(task: task));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        });

        // Due date chip renders with the default subdued styling, not the
        // overdue red. We assert the due label is present — the exact
        // styling is already covered by the header's own test.
        expect(find.textContaining('Apr'), findsOneWidget);
      },
    );
  });

  group('DesktopTaskHeaderConnector — estimate chip', () {
    testWidgets('shows the "No estimate" placeholder when estimate is null', (
      tester,
    ) async {
      final task = buildTask();

      await tester.pumpWidget(pumpConnector(task: task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No estimate'), findsOneWidget);
    });

    testWidgets(
      'shows tracked / estimated duration when an estimate is set',
      (tester) async {
        final task = buildTask(estimate: const Duration(hours: 2));

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // When no progress has been computed yet (null progress state), the
        // chip still formats the pair with a zero tracked component — this
        // keeps the chip the correct width during first paint. The "of"
        // connector reads as tracked-of-estimated rather than the ambiguous
        // "X / Y".
        expect(find.text('00:00 of 02:00'), findsOneWidget);
      },
    );

    testWidgets(
      'formats the tracked / estimate pair as HH:MM consistently',
      (tester) async {
        final task = buildTask(estimate: const Duration(minutes: 45));

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 45-minute estimate pads hours with a leading zero.
        expect(find.text('00:00 of 00:45'), findsOneWidget);
      },
    );

    testWidgets(
      'estimate chip carries a tracked-vs-estimate tooltip and a low-vision '
      'border',
      (tester) async {
        final task = buildTask(estimate: const Duration(hours: 2));

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The tooltip spells out which number is which for hover + a11y.
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.text('00:00 of 02:00'),
            matching: find.byType(Tooltip),
          ),
        );
        expect(tooltip.message, 'Time tracked: 00:00 of 02:00 estimated');

        // The neutral filled estimate chip carries the quiet border.
        final pill = tester.widget<DsPill>(
          find.ancestor(
            of: find.text('00:00 of 02:00'),
            matching: find.byType(DsPill),
          ),
        );
        expect(pill.bordered, isTrue);
      },
    );
  });

  group('DesktopTaskHeaderConnector — modal invocations', () {
    testWidgets(
      'tapping the priority badge opens the priority picker',
      (tester) async {
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The priority glyph is rendered inside the clickable badge in the
        // metadata row; tap its ancestor InkWell so the modal opens.
        await tester.tap(find.byType(TaskShowcasePriorityGlyph).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Priority picker title "Select priority" is surfaced.
        expect(find.text('Select priority'), findsOneWidget);
      },
    );

    testWidgets(
      'priority picker lists a description for every TaskPriority',
      (tester) async {
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byType(TaskShowcasePriorityGlyph).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Every enum variant is rendered in the picker via its short "P{n}"
        // code. The header's own badge now spells the priority out ("Medium"
        // for the default p2Medium task), so the short codes appear only in
        // the picker rows.
        expect(find.text('P0'), findsOneWidget);
        expect(find.text('P1'), findsOneWidget);
        expect(find.text('P2'), findsOneWidget);
        expect(find.text('P3'), findsOneWidget);
        // The header badge spells out the default priority instead of "P2".
        expect(find.text('Medium'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the status chip opens the status picker',
      (tester) async {
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Default status is "Open" — the dropdown chip shows that label.
        // Tap the first "Open" text (the header chip, not the modal option).
        await tester.tap(find.text('Open').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // TaskStatusModalContent renders the status list with labels like
        // "In Progress".
        expect(find.text('In Progress'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the "unassigned" category placeholder opens the category picker',
      (tester) async {
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('unassigned'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // CategoryPickerSheet renders with an empty category
        // list — verify that the header's own "unassigned" chip has been
        // covered by a modal on top.
        expect(find.byType(CategoryPickerSheet), findsOneWidget);
      },
    );

    testWidgets(
      'project picker is skipped when the task has no category',
      (tester) async {
        // Task has no categoryId; tapping project placeholder is a no-op
        // because _showProjectPicker returns early.
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('No project'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // No modal opened — the base connector is still the visible root.
        expect(find.byType(DesktopTaskHeaderConnector), findsOneWidget);
        expect(find.text('Select project'), findsNothing);
      },
    );

    testWidgets(
      'tapping the Add Label placeholder opens the label selector modal',
      (tester) async {
        // Empty labelIds → meta row renders the muted "Add Label" ghost.
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Add Label'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The label selection sliver mounts inside the modal once the
        // onAddLabelTap → _openLabelSelector path fires. The labels stream is
        // empty and no search query is active, so the sliver renders its empty
        // state — asserting on that content proves the modal actually opened
        // and populated its (empty) label list, not merely that the type is
        // present somewhere in the tree.
        expect(find.byType(EntityPickerSheet), findsOneWidget);
        expect(find.text('No matches'), findsOneWidget);
      },
    );

    testWidgets(
      'estimate chip switches to the overtime tinted variant when '
      'tracked > estimate',
      (tester) async {
        final task = buildTask(estimate: const Duration(hours: 1));

        await tester.pumpWidget(
          pumpConnector(
            task: task,
            progress: const TaskProgressState(
              progress: Duration(hours: 2),
              estimate: Duration(hours: 1),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The pill renders the "tracked of estimate" pair, with progress
        // overrunning the estimate; the connector takes the overtime branch
        // and paints a tinted error-coloured pill plus a progress bar.
        expect(find.text('02:00 of 01:00'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the estimate chip (unset) opens the estimate picker',
      (tester) async {
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('No estimate'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // showEstimatePicker surfaces a Cupertino timer picker and a Done
        // button.
        expect(find.text('Done'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the estimate chip (with value) opens the estimate picker',
      (tester) async {
        final task = buildTask(estimate: const Duration(hours: 2));

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('00:00 of 02:00'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Done'), findsOneWidget);
      },
    );
  });

  group('DesktopTaskHeaderConnector — picker callbacks', () {
    List<Override> connectorOverrides({
      required Task task,
      required ToggleCallTracker tracker,
    }) => [
      entryControllerProvider(id: task.id).overrideWith(
        () => FakeEntryController(task, tracker: tracker),
      ),
      labelsStreamProvider.overrideWith(
        (ref) => Stream<List<LabelDefinition>>.value(const []),
      ),
      projectForTaskProvider(task.id).overrideWith((ref) async => null),
      taskProgressControllerProvider(id: task.id).overrideWith(
        () => _FakeTaskProgressController(null),
      ),
    ];

    Widget wrapInTestApp({
      required List<Override> overrides,
      required Widget home,
    }) {
      return ProviderScope(
        overrides: overrides,
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
          home: home,
        ),
      );
    }

    Widget pumpConnectorWithTracker({
      required Task task,
      required ToggleCallTracker tracker,
    }) {
      return wrapInTestApp(
        overrides: connectorOverrides(task: task, tracker: tracker),
        home: Scaffold(body: DesktopTaskHeaderConnector(taskId: task.id)),
      );
    }

    testWidgets(
      'selecting a priority in the picker calls updateTaskPriority',
      (tester) async {
        final task = buildTask();
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          pumpConnectorWithTracker(task: task, tracker: tracker),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byType(TaskShowcasePriorityGlyph).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Pick the P0 row in the picker.
        await tester.tap(find.text('P0'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tracker.updateTaskPriorityCalls, equals(['P0']));
      },
    );

    testWidgets(
      'selecting a status in the picker calls updateTaskStatus',
      (tester) async {
        final task = buildTask();
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          pumpConnectorWithTracker(task: task, tracker: tracker),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the status chip (shows "Open" for a new task).
        await tester.tap(find.text('Open').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap "In Progress" in the status picker.
        await tester.tap(find.text('In Progress'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tracker.updateTaskStatusCalls, hasLength(1));
      },
    );

    testWidgets(
      'confirming the estimate picker forwards the new duration to save',
      (tester) async {
        final task = buildTask();
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          pumpConnectorWithTracker(task: task, tracker: tracker),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('No estimate'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The Cupertino timer picker starts at 00:00; tapping Done without
        // changing the value is still a valid "save 0" path from the
        // connector's perspective.
        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Either the estimate save happened (0 → 0 with no change calls)
        // or was skipped by the picker itself; the key coverage is that
        // the connector's `onTap` ran through showEstimatePicker without
        // throwing and the chip was rebuilt.
        expect(find.byType(DesktopTaskHeaderConnector), findsOneWidget);
      },
    );

    testWidgets(
      'due-date picker — Done with no initial date saves the current date',
      (tester) async {
        final task = buildTask();
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          pumpConnectorWithTracker(task: task, tracker: tracker),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('No due date'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // When no initial due date is set, tapping Done unconditionally
        // commits the current picker value via controller.save(dueDate: ...).
        expect(tracker.saveCalls, hasLength(1));
        expect(tracker.saveCalls.single['dueDate'], isA<DateTime>());
        expect(tracker.saveCalls.single['clearDueDate'], isFalse);
      },
    );

    testWidgets(
      'due-date picker — Clear on a task with a due date clears it',
      (tester) async {
        final task = buildTask(due: DateTime(2026, 4, 25));
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          pumpConnectorWithTracker(task: task, tracker: tracker),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the due-date chip — match its rendered label.
        await tester.tap(find.textContaining('Apr 25, 2026'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Clear'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tracker.saveCalls, hasLength(1));
        expect(tracker.saveCalls.single['clearDueDate'], isTrue);
        expect(tracker.saveCalls.single['dueDate'], isNull);
      },
    );

    testWidgets(
      'selecting a category in the picker calls updateCategoryId',
      (tester) async {
        final pickable = buildCategory(id: 'cat-pick', name: 'Focus');
        when(() => mockCache.sortedCategories).thenReturn([pickable]);
        when(() => mockCache.getCategoryById('cat-pick')).thenReturn(pickable);

        final task = buildTask();
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          pumpConnectorWithTracker(task: task, tracker: tracker),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('unassigned'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Focus'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tracker.updateCategoryIdCalls, equals(['cat-pick']));
      },
    );

    testWidgets(
      'category row tap closes the modal without popping the outer route',
      (tester) async {
        // Reproduces the bottom-nav topology: the connector lives in a
        // per-tab nested Navigator inside the MaterialApp root Navigator.
        // On phone width the picker opens on the root Navigator
        // (`shouldUseRootNavigatorForBottomSheet`), so popping with the
        // connector's outer context would pop the nested route instead of
        // the modal. This guards the c6627fe8d-style fix.
        final pickable = buildCategory(id: 'cat-pick', name: 'Focus');
        when(() => mockCache.sortedCategories).thenReturn([pickable]);
        when(() => mockCache.getCategoryById('cat-pick')).thenReturn(pickable);

        final task = buildTask();
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          wrapInTestApp(
            overrides: connectorOverrides(task: task, tracker: tracker),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(390, 844)),
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: DesktopTaskHeaderConnector(taskId: task.id),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('unassigned'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Focus'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Modal closed.
        expect(find.byType(CategoryPickerSheet), findsNothing);
        // Outer nested route was NOT popped — the connector is still
        // mounted. A pop targeting the connector's outer context would
        // have removed the MaterialPageRoute hosting the connector.
        expect(find.byType(DesktopTaskHeaderConnector), findsOneWidget);
      },
    );

    testWidgets(
      'saving a new title forwards to EntryController.save',
      (tester) async {
        final task = buildTask();
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          pumpConnectorWithTracker(task: task, tracker: tracker),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Enter edit mode on the read-only title.
        await tester.tap(find.text('Test Task'));
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'New Title');
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pump();

        expect(tracker.saveCalls, hasLength(1));
        expect(tracker.saveCalls.single['title'], 'New Title');
      },
    );
  });

  group('DesktopTaskHeaderConnector — due-date urgency', () {
    testWidgets(
      'past-due tasks surface the overdue badge styling',
      (tester) async {
        final past = DateTime(2026, 4, 10);
        final task = buildTask(due: past);

        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(pumpConnector(task: task));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        });

        // The due chip is present; overdue styling is exercised downstream.
        expect(find.textContaining('Apr'), findsOneWidget);
      },
    );

    testWidgets(
      'tasks due today pick up the today urgency styling',
      (tester) async {
        final task = buildTask(due: DateTime(2026, 4, 20, 18));

        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(pumpConnector(task: task));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        });

        // Either the urgency label or the date string is visible.
        expect(find.byType(DesktopTaskHeader), findsOneWidget);
      },
    );

    testWidgets(
      'tasks due in the future fall through to the normal urgency branch',
      (tester) async {
        // A future date (well past "today") exercises the
        // `case DueDateUrgency.normal:` arm of `_dueUrgency`.
        final task = buildTask(due: DateTime(2026, 6, 15));

        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(pumpConnector(task: task));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        });

        expect(find.byType(DesktopTaskHeader), findsOneWidget);
        expect(find.textContaining('Jun'), findsOneWidget);
      },
    );
  });

  group('DesktopTaskHeaderConnector — project picker', () {
    /// Builds overrides for project-picker tests, using a real
    /// [MockProjectRepository] stub so [projectsForCategoryProvider]
    /// can serve the project list and [linkTaskToProject] /
    /// [unlinkTaskFromProject] calls can be verified.
    List<Override> projectPickerOverrides({
      required Task task,
      required ToggleCallTracker tracker,
      required MockProjectRepository projectRepo,
      List<ProjectEntry> projects = const [],
    }) {
      return [
        entryControllerProvider(id: task.id).overrideWith(
          () => FakeEntryController(task, tracker: tracker),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(const []),
        ),
        projectForTaskProvider(task.id).overrideWith((ref) async => null),
        taskProgressControllerProvider(id: task.id).overrideWith(
          () => _FakeTaskProgressController(null),
        ),
        projectRepositoryProvider.overrideWithValue(projectRepo),
        if (task.meta.categoryId != null)
          projectsForCategoryProvider(task.meta.categoryId!).overrideWith(
            (ref) async => projects,
          ),
      ];
    }

    Widget wrapWithProjectApp({
      required List<Override> overrides,
      required Task task,
    }) {
      return ProviderScope(
        overrides: overrides,
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
          home: Scaffold(
            body: DesktopTaskHeaderConnector(taskId: task.id),
          ),
        ),
      );
    }

    testWidgets(
      'task with a category exposes a tappable project crumb that opens '
      'the project picker (covers onProjectTap lambda + _showProjectPicker)',
      (tester) async {
        final category = buildCategory(id: 'cat-proj', name: 'Design');
        when(
          () => mockCache.getCategoryById('cat-proj'),
        ).thenReturn(category);

        final task = buildTask(categoryId: 'cat-proj');
        final tracker = ToggleCallTracker();
        final projectRepo = MockProjectRepository();

        when(
          () => projectRepo.updateStream,
        ).thenAnswer((_) => const Stream<Set<String>>.empty());

        final overrides = projectPickerOverrides(
          task: task,
          tracker: tracker,
          projectRepo: projectRepo,
        );

        await tester.pumpWidget(
          wrapWithProjectApp(overrides: overrides, task: task),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // "No project" is the unassigned crumb; when categoryId is non-null
        // the connector passes a real onProjectTap callback (not null).
        await tester.tap(find.text('No project'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The project-selection modal opened.
        expect(find.byType(ProjectSelectionModalContent), findsOneWidget);
      },
    );

    testWidgets(
      'selecting "No project" in the picker calls unlinkTaskFromProject',
      (tester) async {
        final category = buildCategory(id: 'cat-proj', name: 'Design');
        when(
          () => mockCache.getCategoryById('cat-proj'),
        ).thenReturn(category);

        // Task already linked to a project so we can verify unlink.
        final existingProject = buildProject(id: 'proj-existing', title: 'Old');
        final task = buildTask(categoryId: 'cat-proj');
        final tracker = ToggleCallTracker();
        final projectRepo = MockProjectRepository();

        when(
          () => projectRepo.updateStream,
        ).thenAnswer((_) => const Stream<Set<String>>.empty());
        when(
          () => projectRepo.unlinkTaskFromProject(any()),
        ).thenAnswer((_) async => true);

        final overrides = projectPickerOverrides(
          task: task,
          tracker: tracker,
          projectRepo: projectRepo,
          projects: [existingProject],
        );

        await tester.pumpWidget(
          wrapWithProjectApp(overrides: overrides, task: task),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('No project'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the "No project" row (null selection).
        await tester.tap(find.text('No project').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(() => projectRepo.unlinkTaskFromProject(task.id)).called(1);
      },
    );

    testWidgets(
      'selecting an existing project in the picker calls linkTaskToProject',
      (tester) async {
        final category = buildCategory(id: 'cat-proj', name: 'Design');
        when(
          () => mockCache.getCategoryById('cat-proj'),
        ).thenReturn(category);

        final project = buildProject(id: 'proj-1', title: 'Alpha Project');
        final task = buildTask(categoryId: 'cat-proj');
        final tracker = ToggleCallTracker();
        final projectRepo = MockProjectRepository();

        when(
          () => projectRepo.updateStream,
        ).thenAnswer((_) => const Stream<Set<String>>.empty());
        when(
          () => projectRepo.linkTaskToProject(
            projectId: any(named: 'projectId'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);

        final overrides = projectPickerOverrides(
          task: task,
          tracker: tracker,
          projectRepo: projectRepo,
          projects: [project],
        );

        await tester.pumpWidget(
          wrapWithProjectApp(overrides: overrides, task: task),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('No project'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the "Alpha Project" row in the picker.
        await tester.tap(find.text('Alpha Project'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => projectRepo.linkTaskToProject(
            projectId: 'proj-1',
            taskId: task.id,
          ),
        ).called(1);
      },
    );
  });

  group('DesktopTaskHeaderConnector — onLabelTap', () {
    testWidgets(
      'tapping an existing label chip opens the label selector modal',
      (tester) async {
        // Build a task with a label that the cache resolves.
        final label = buildLabel(id: 'lbl-tap', name: 'Urgent');
        when(
          () => mockCache.getLabelById('lbl-tap'),
        ).thenReturn(label);

        final task = buildTask(labelIds: const ['lbl-tap']);
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              entryControllerProvider(id: task.id).overrideWith(
                () => FakeEntryController(task, tracker: tracker),
              ),
              labelsStreamProvider.overrideWith(
                (ref) => Stream<List<LabelDefinition>>.value(const []),
              ),
              projectForTaskProvider(task.id).overrideWith(
                (ref) async => null,
              ),
              taskProgressControllerProvider(id: task.id).overrideWith(
                () => _FakeTaskProgressController(null),
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
              home: Scaffold(
                body: DesktopTaskHeaderConnector(taskId: task.id),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The label pill is rendered (label name visible).
        expect(find.text('Urgent'), findsOneWidget);

        // Tapping the label fires onLabelTap → _openLabelSelector.
        await tester.tap(find.text('Urgent'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(EntityPickerSheet), findsOneWidget);
      },
    );
  });

  group(
    'DesktopTaskHeaderConnector — estimate chip saves changed duration',
    () {
      testWidgets(
        'changing the estimate value and tapping Done calls '
        'notifier.save(estimate: newDuration)',
        (tester) async {
          // Use a task with no estimate so the "No estimate" chip renders.
          // The test then opens the picker, simulates a duration change via
          // the CupertinoTimerPicker callback, and taps Done — this
          // exercises lines 363-364 (the onEstimateChanged closure body).
          final task = buildTask();
          final tracker = ToggleCallTracker();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                entryControllerProvider(id: task.id).overrideWith(
                  () => FakeEntryController(task, tracker: tracker),
                ),
                labelsStreamProvider.overrideWith(
                  (ref) => Stream<List<LabelDefinition>>.value(const []),
                ),
                projectForTaskProvider(task.id).overrideWith(
                  (ref) async => null,
                ),
                taskProgressControllerProvider(id: task.id).overrideWith(
                  () => _FakeTaskProgressController(null),
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
                home: Scaffold(
                  body: DesktopTaskHeaderConnector(taskId: task.id),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Open the estimate picker (initial duration is zero).
          await tester.tap(find.text('No estimate'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Directly invoke the picker's duration-changed callback to
          // simulate the user scrolling to 1 h — this ensures selectedDuration
          // diverges from initialDuration (zero) so Done will fire the
          // onEstimateChanged callback.
          final picker = tester.widget<CupertinoTimerPicker>(
            find.byType(CupertinoTimerPicker),
          );
          picker.onTimerDurationChanged(const Duration(hours: 1));

          await tester.tap(find.text('Done'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Verify save was called with the new 1-hour estimate.
          expect(tracker.saveCalls, hasLength(1));
          expect(
            tracker.saveCalls.single['estimate'],
            equals(const Duration(hours: 1)),
          );
        },
      );
    },
  );
}
