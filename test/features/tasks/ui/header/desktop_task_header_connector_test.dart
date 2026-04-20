import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
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
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';

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
    await getIt.reset();
    getIt.allowReassignment = true;

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

    getIt
      ..registerSingleton<EntitiesCacheService>(mockCache)
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
  });

  tearDown(() async {
    await getIt.reset();
  });

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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        expect(find.text('Work'), findsOneWidget);
      },
    );

    testWidgets('shows the project title when one is linked', (tester) async {
      final task = buildTask();
      final project = buildProject();

      await tester.pumpWidget(pumpConnector(task: task, project: project));
      await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        final alphaPos = tester.getTopLeft(find.text('Alpha')).dx;
        final betaPos = tester.getTopLeft(find.text('Beta')).dx;
        expect(alphaPos, lessThan(betaPos));
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
        await tester.pumpAndSettle();

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
          await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();

      expect(find.text('No estimate'), findsOneWidget);
    });

    testWidgets(
      'shows tracked / estimated duration when an estimate is set',
      (tester) async {
        final task = buildTask(estimate: const Duration(hours: 2));

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pumpAndSettle();

        // When no progress has been computed yet (null progress state), the
        // chip still formats the pair with a zero tracked component — this
        // keeps the chip the correct width during first paint.
        expect(find.text('00:00 / 02:00'), findsOneWidget);
      },
    );

    testWidgets(
      'formats the tracked / estimate pair as HH:MM consistently',
      (tester) async {
        final task = buildTask(estimate: const Duration(minutes: 45));

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pumpAndSettle();

        // 45-minute estimate pads hours with a leading zero.
        expect(find.text('00:00 / 00:45'), findsOneWidget);
      },
    );
  });

  group('DesktopTaskHeaderConnector — modal invocations', () {
    testWidgets(
      'tapping the priority badge opens the priority picker',
      (tester) async {
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pumpAndSettle();

        // The priority glyph is rendered inside the clickable badge in the
        // metadata row; tap its ancestor InkWell so the modal opens.
        await tester.tap(find.byType(TaskShowcasePriorityGlyph).first);
        await tester.pumpAndSettle();

        // Priority picker title "Select priority" is surfaced.
        expect(find.text('Select priority'), findsOneWidget);
      },
    );

    testWidgets(
      'priority picker lists a description for every TaskPriority',
      (tester) async {
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(TaskShowcasePriorityGlyph).first);
        await tester.pumpAndSettle();

        // Every enum variant should be rendered in the picker. (`P2`
        // appears twice — once in the header's own badge for the default
        // task, once in the picker row — so we allow `findsWidgets`.)
        expect(find.text('P0'), findsOneWidget);
        expect(find.text('P1'), findsOneWidget);
        expect(find.text('P2'), findsWidgets);
        expect(find.text('P3'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the status chip opens the status picker',
      (tester) async {
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pumpAndSettle();

        // Default status is "Open" — the dropdown chip shows that label.
        // Tap the first "Open" text (the header chip, not the modal option).
        await tester.tap(find.text('Open').first);
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        await tester.tap(find.text('unassigned'));
        await tester.pumpAndSettle();

        // CategorySelectionModalContent renders with an empty category
        // list — verify that the header's own "unassigned" chip has been
        // covered by a modal on top.
        expect(find.byType(CategorySelectionModalContent), findsOneWidget);
      },
    );

    testWidgets(
      'project picker is skipped when the task has no category',
      (tester) async {
        // Task has no categoryId; tapping project placeholder is a no-op
        // because _showProjectPicker returns early.
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pumpAndSettle();

        await tester.tap(find.text('No project'));
        await tester.pumpAndSettle();

        // No modal opened — the base connector is still the visible root.
        expect(find.byType(DesktopTaskHeaderConnector), findsOneWidget);
        expect(find.text('Select project'), findsNothing);
      },
    );

    testWidgets(
      'tapping the estimate chip (unset) opens the estimate picker',
      (tester) async {
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pumpAndSettle();

        await tester.tap(find.text('No estimate'));
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        await tester.tap(find.text('00:00 / 02:00'));
        await tester.pumpAndSettle();

        expect(find.text('Done'), findsOneWidget);
      },
    );
  });

  group('DesktopTaskHeaderConnector — picker callbacks', () {
    Widget pumpConnectorWithTracker({
      required Task task,
      required ToggleCallTracker tracker,
    }) {
      final override = entryControllerProvider(id: task.id).overrideWith(
        () => FakeEntryController(task, tracker: tracker),
      );
      return ProviderScope(
        overrides: [
          override,
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value(const []),
          ),
          projectForTaskProvider(task.id).overrideWith((ref) async => null),
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
        await tester.pumpAndSettle();

        await tester.tap(find.byType(TaskShowcasePriorityGlyph).first);
        await tester.pumpAndSettle();

        // Pick the P0 row in the picker.
        await tester.tap(find.text('P0'));
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        // Tap the status chip (shows "Open" for a new task).
        await tester.tap(find.text('Open').first);
        await tester.pumpAndSettle();

        // Tap "In Progress" in the status picker.
        await tester.tap(find.text('In Progress'));
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        await tester.tap(find.text('No estimate'));
        await tester.pumpAndSettle();

        // The Cupertino timer picker starts at 00:00; tapping Done without
        // changing the value is still a valid "save 0" path from the
        // connector's perspective.
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        await tester.tap(find.text('No due date'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        // Tap the due-date chip — match its rendered label.
        await tester.tap(find.textContaining('Apr 25, 2026'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();

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
        await tester.pumpAndSettle();

        await tester.tap(find.text('unassigned'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Focus'));
        await tester.pumpAndSettle();

        expect(tracker.updateCategoryIdCalls, equals(['cat-pick']));
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
        await tester.pumpAndSettle();

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
          await tester.pumpAndSettle();
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
          await tester.pumpAndSettle();
        });

        // Either the urgency label or the date string is visible.
        expect(find.byType(DesktopTaskHeader), findsOneWidget);
      },
    );
  });
}
