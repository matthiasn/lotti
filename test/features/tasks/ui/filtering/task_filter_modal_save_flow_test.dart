// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';

/// Recorder controller — captures `create` and `updateFilter` calls so we can
/// assert which save-flow branch ran.
class _RecordingSavedFiltersController extends SavedTaskFiltersController {
  _RecordingSavedFiltersController(this._seed);

  final List<SavedTaskFilter> _seed;
  final List<({String name, TasksFilter filter})> creates = [];
  final List<({String id, TasksFilter filter})> updates = [];

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;

  @override
  Future<SavedTaskFilter> create({
    required String name,
    required TasksFilter filter,
  }) async {
    creates.add((name: name, filter: filter));
    final created = SavedTaskFilter(
      id: 'sv-${creates.length}',
      name: name,
      filter: filter,
    );
    state = AsyncData([..._seed, created]);
    return created;
  }

  @override
  Future<void> updateFilter(String id, TasksFilter filter) async {
    updates.add((id: id, filter: filter));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeJournalPageController fakeController;
  late JournalPageState mockState;
  late MockEntitiesCacheService mockCache;
  late MockJournalDb mockJournalDb;

  setUp(() {
    mockCache = MockEntitiesCacheService();
    mockJournalDb = MockJournalDb();

    when(() => mockCache.sortedCategories).thenReturn(const []);
    when(() => mockCache.sortedLabels).thenReturn(const []);
    when(
      () => mockJournalDb.getProjectsForCategory(any()),
    ).thenAnswer((_) async => <ProjectEntry>[]);

    mockState = const JournalPageState(
      taskStatuses: ['OPEN', 'IN PROGRESS'],
      selectedTaskStatuses: {'OPEN'},
      selectedCategoryIds: {},
      selectedLabelIds: {},
      selectedPriorities: {},
    );

    final mockSettingsDb = MockSettingsDb();
    when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);

    getIt.allowReassignment = true;
    getIt
      ..registerSingleton<EntitiesCacheService>(mockCache)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<SettingsDb>(mockSettingsDb);
  });

  tearDown(getIt.reset);

  Widget buildSubject({
    required _RecordingSavedFiltersController recorder,
    String? activeId,
    bool hasUnsavedClauses = true,
    JournalPageState? pageState,
  }) {
    // The modal builds its draft from the controller state via
    // `buildTasksFilterSheetState`, then the Save handler converts that
    // draft to a `TasksFilter` directly — so tests configure the starting
    // shape via [pageState], not via a `liveTasksFilterProvider` override.
    fakeController = FakeJournalPageController(pageState ?? mockState);

    return WidgetTestBench(
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(
            true,
          ).overrideWith(() => fakeController),
          savedTaskFiltersControllerProvider.overrideWith(() => recorder),
          currentSavedTaskFilterIdProvider.overrideWith((ref) => activeId),
          tasksFilterHasUnsavedClausesProvider.overrideWith(
            (ref) => hasUnsavedClauses,
          ),
        ],
        child: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const ValueKey('open-filter-modal'),
              onPressed: () => showTaskFilterModal(context, showTasks: true),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openModalAndSave(
    WidgetTester tester, {
    required String typedName,
  }) async {
    await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
    await tester.pumpAndSettle();

    // Open the Save popup.
    await tester.tap(find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey));
    await tester.pumpAndSettle();

    // Type the name and commit.
    await tester.enterText(
      find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupFieldKey),
      typedName,
    );
    // Allow the controller listener to flip _canCommit.
    await tester.pump();
    await tester.tap(
      find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupCommitKey),
    );
    await tester.pumpAndSettle();
  }

  group('save flow', () {
    testWidgets(
      'creates a new saved filter when no active id is set, captures the '
      'modal draft, and closes the modal',
      (tester) async {
        final recorder = _RecordingSavedFiltersController(const []);
        await tester.pumpWidget(
          buildSubject(
            recorder: recorder,
            pageState: const JournalPageState(
              taskStatuses: ['OPEN', 'IN PROGRESS'],
              selectedTaskStatuses: {'IN PROGRESS'},
              selectedCategoryIds: {},
              selectedLabelIds: {},
              selectedPriorities: {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await openModalAndSave(tester, typedName: '  My filter  ');

        expect(recorder.creates, hasLength(1));
        expect(recorder.creates.single.name, 'My filter');
        // The captured filter mirrors the controller state the draft was
        // seeded from — proving the save flow now sources from the modal
        // draft rather than `liveTasksFilterProvider`.
        expect(
          recorder.creates.single.filter.selectedTaskStatuses,
          {'IN PROGRESS'},
        );
        expect(recorder.updates, isEmpty);

        // Modal closes after Save (apply + save + close).
        expect(
          find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
          findsNothing,
        );
      },
    );

    testWidgets(
      'updates the active saved filter when typed name matches the active name',
      (tester) async {
        final recorder = _RecordingSavedFiltersController(
          const [
            SavedTaskFilter(
              id: 'sv-1',
              name: 'In progress',
              filter: TasksFilter(),
            ),
          ],
        );
        await tester.pumpWidget(
          buildSubject(
            recorder: recorder,
            activeId: 'sv-1',
            pageState: const JournalPageState(
              taskStatuses: ['OPEN', 'IN PROGRESS', 'BLOCKED'],
              selectedTaskStatuses: {'BLOCKED'},
              selectedCategoryIds: {},
              selectedLabelIds: {},
              selectedPriorities: {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Prime the AsyncNotifier so its initial seed has resolved before
        // the modal reads `.value` — otherwise the modal sees an empty list
        // and routes to the create branch.
        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const ValueKey('open-filter-modal'))),
        );
        await container.read(savedTaskFiltersControllerProvider.future);
        await tester.pumpAndSettle();

        await openModalAndSave(tester, typedName: 'In progress');

        expect(recorder.updates, hasLength(1));
        expect(recorder.updates.single.id, 'sv-1');
        expect(
          recorder.updates.single.filter.selectedTaskStatuses,
          {'BLOCKED'},
        );
        expect(recorder.creates, isEmpty);
      },
    );

    testWidgets(
      'creates a new saved filter when active id has no resolved name',
      (tester) async {
        // Stale-id case: provider says sv-1 is active but the list does not
        // contain it (concurrent delete). The save flow must degrade to the
        // create branch rather than calling updateFilter on a stale id.
        final recorder = _RecordingSavedFiltersController(const []);
        await tester.pumpWidget(
          buildSubject(
            recorder: recorder,
            activeId: 'sv-1', // no matching entry in seed
          ),
        );
        await tester.pumpAndSettle();

        await openModalAndSave(tester, typedName: 'Whatever');

        expect(recorder.creates, hasLength(1));
        expect(recorder.creates.single.name, 'Whatever');
        expect(recorder.updates, isEmpty);
      },
    );

    testWidgets(
      'creates a new saved filter when typed name differs from active name',
      (tester) async {
        final recorder = _RecordingSavedFiltersController(
          const [
            SavedTaskFilter(
              id: 'sv-1',
              name: 'Existing',
              filter: TasksFilter(),
            ),
          ],
        );
        await tester.pumpWidget(
          buildSubject(
            recorder: recorder,
            activeId: 'sv-1',
            pageState: const JournalPageState(
              taskStatuses: ['OPEN', 'IN PROGRESS', 'BLOCKED'],
              selectedTaskStatuses: {'BLOCKED'},
              selectedCategoryIds: {},
              selectedLabelIds: {},
              selectedPriorities: {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const ValueKey('open-filter-modal'))),
        );
        await container.read(savedTaskFiltersControllerProvider.future);
        await tester.pumpAndSettle();

        await openModalAndSave(tester, typedName: 'Different');

        // User typed a new name → create branch fires, no update.
        expect(recorder.creates, hasLength(1));
        expect(recorder.creates.single.name, 'Different');
        expect(recorder.updates, isEmpty);
      },
    );

    testWidgets(
      'captures in-modal priority edits in the saved filter — regression '
      'guard for the bug where Save persisted the previously applied '
      'filter instead of the current modal draft',
      (tester) async {
        // Controller starts with no priority selected; user toggles P1 on
        // inside the modal *without* tapping Apply, then taps Save.
        // Pre-fix: the saved filter would carry no priorities (read from
        // liveTasksFilterProvider, which still reflects the controller's
        // pre-edit state). Post-fix: the saved filter contains 'P1',
        // sourced from the modal's draft state.
        //
        // Priority chips are inline pills inside the sheet (unlike status
        // / category / label / project, which are drill-down fields), so
        // they're the cleanest section to mutate from a widget test.
        final recorder = _RecordingSavedFiltersController(const []);
        await tester.pumpWidget(
          buildSubject(recorder: recorder),
        );
        await tester.pumpAndSettle();

        // Open the modal.
        await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
        await tester.pumpAndSettle();

        // Tap the P1 priority chip — this toggles 'p1' (display id) into
        // the modal's draft state. The bug fix sets up Save to map this
        // back to the internal 'P1' priority and persist it.
        final p1Chip = find.byKey(
          const ValueKey('design-system-task-filter-priority-p1'),
        );
        await tester.ensureVisible(p1Chip);
        await tester.pumpAndSettle();
        await tester.tap(p1Chip);
        await tester.pumpAndSettle();

        // Open the Save popup, type a name, commit.
        await tester.tap(
          find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupFieldKey),
          'Edited',
        );
        await tester.pump();
        await tester.tap(
          find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupCommitKey),
        );
        await tester.pumpAndSettle();

        expect(recorder.creates, hasLength(1));
        expect(recorder.creates.single.name, 'Edited');
        // P1 was toggled in-modal — the captured filter must include it.
        expect(
          recorder.creates.single.filter.selectedPriorities,
          {'P1'},
        );
        expect(recorder.updates, isEmpty);
        // Modal closes after Save.
        expect(
          find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
          findsNothing,
        );
      },
    );
  });
}
