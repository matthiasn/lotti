import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/save_current_task_filter.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../../widget_test_utils.dart';

const _f1 = SavedTaskFilter(
  id: 'f1',
  name: 'In Progress',
  filter: TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'}),
);
const _f2 = SavedTaskFilter(
  id: 'f2',
  name: 'Blocked',
  filter: TasksFilter(selectedTaskStatuses: {'BLOCKED'}),
);

class _RecordingSavedController extends SavedTaskFiltersController {
  _RecordingSavedController(this._seed);
  final List<SavedTaskFilter> _seed;

  final List<(String id, String name)> renameCalls = [];
  final List<String> deleteCalls = [];
  final List<String> createCalls = [];

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;

  @override
  Future<void> rename(String id, String name) async {
    renameCalls.add((id, name));
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls.add(id);
  }

  @override
  Future<SavedTaskFilter> create({
    required String name,
    required TasksFilter filter,
  }) async {
    createCalls.add(name);
    return SavedTaskFilter(id: 'new', name: name, filter: filter);
  }
}

Future<({FakeJournalPageController fake, _RecordingSavedController saved})>
_pumpSheet(
  WidgetTester tester, {
  JournalPageState pageState = const JournalPageState(),
  List<SavedTaskFilter> seed = const [_f1, _f2],
}) async {
  final fake = FakeJournalPageController(pageState);
  final saved = _RecordingSavedController(seed);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      const Scaffold(body: SavedTaskFiltersSheet()),
      overrides: [
        journalPageControllerProvider(true).overrideWith(() => fake),
        savedTaskFiltersControllerProvider.overrideWith(() => saved),
        savedTaskFilterCountsProvider.overrideWith(
          (ref) async => const {'f1': 12, 'f2': 7},
        ),
        allTasksTotalCountProvider.overrideWith((ref) async => 124),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
  return (fake: fake, saved: saved);
}

void main() {
  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        final cache = MockEntitiesCacheService();
        when(() => cache.getCategoryById(any())).thenReturn(null);
        getIt.registerSingleton<EntitiesCacheService>(cache);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  testWidgets('renders the All-total and a tabular count per saved filter', (
    tester,
  ) async {
    await _pumpSheet(tester);

    expect(find.text('All tasks'), findsOneWidget);
    expect(find.text('124'), findsOneWidget); // All total
    expect(find.text('12'), findsOneWidget); // f1
    expect(find.text('7'), findsOneWidget); // f2
  });

  testWidgets('tapping a saved row applies that filter', (tester) async {
    final bench = await _pumpSheet(tester);

    await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.row('f2')));
    await tester.pump();

    expect(bench.fake.applyBatchFilterUpdateCalled, 1);
    expect(bench.fake.setSelectedTaskStatusesCalls.single, {'BLOCKED'});
  });

  testWidgets('tapping the All row clears the filter to default', (
    tester,
  ) async {
    final bench = await _pumpSheet(
      tester,
      pageState: const JournalPageState(selectedTaskStatuses: {'IN_PROGRESS'}),
    );

    await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.allRow));
    await tester.pump();

    expect(bench.fake.applyBatchFilterUpdateCalled, 1);
    // Cleared: empty status set is forwarded.
    expect(bench.fake.setSelectedTaskStatusesCalls.single, <String>{});
  });

  testWidgets('Edit toggle uses the teal interactive accent, not purple', (
    tester,
  ) async {
    await _pumpSheet(tester);

    final button = tester.widget<TextButton>(
      find.byKey(SavedTaskFiltersSheetKeys.editToggle),
    );
    expect(
      button.style?.foregroundColor?.resolve(const <WidgetState>{}),
      dsTokensLight.colors.interactive.enabled,
    );
  });

  testWidgets(
    'Edit-mode Rename/Delete are >=48dp targets with a clear gap between them',
    (tester) async {
      await _pumpSheet(tester);

      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
      await tester.pump();

      final renameRect = tester.getRect(
        find.byKey(SavedTaskFiltersSheetKeys.rename('f1')),
      );
      final deleteRect = tester.getRect(
        find.byKey(SavedTaskFiltersSheetKeys.delete('f1')),
      );

      for (final r in [renameRect, deleteRect]) {
        expect(r.width, greaterThanOrEqualTo(48));
        expect(r.height, greaterThanOrEqualTo(48));
      }
      // Delete sits clearly to the right of Rename — the tap targets do not
      // abut, so the destructive action can't be mis-tapped.
      expect(deleteRect.left - renameRect.right, greaterThanOrEqualTo(4));
    },
  );

  testWidgets('Edit toggle reveals and hides per-row Rename / Delete', (
    tester,
  ) async {
    await _pumpSheet(tester);

    expect(find.byKey(SavedTaskFiltersSheetKeys.rename('f1')), findsNothing);

    await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
    await tester.pump();
    expect(find.byKey(SavedTaskFiltersSheetKeys.rename('f1')), findsOneWidget);
    expect(find.byKey(SavedTaskFiltersSheetKeys.delete('f1')), findsOneWidget);

    await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
    await tester.pump();
    expect(find.byKey(SavedTaskFiltersSheetKeys.rename('f1')), findsNothing);
  });

  testWidgets('Rename opens the name modal and renames via the controller', (
    tester,
  ) async {
    final bench = await _pumpSheet(tester);

    await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
    await tester.pump();
    await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.rename('f1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(SaveCurrentTaskFilterKeys.nameField),
      'Doing now',
    );
    await tester.pump();
    await tester.tap(find.byKey(SaveCurrentTaskFilterKeys.saveButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(bench.saved.renameCalls.single, ('f1', 'Doing now'));
  });

  testWidgets('Delete asks for confirmation, then deletes', (tester) async {
    final bench = await _pumpSheet(tester);

    await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
    await tester.pump();
    await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.delete('f1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Confirmation modal — the primary action is the upper-cased confirm label.
    await tester.tap(find.text('DELETE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(bench.saved.deleteCalls.single, 'f1');
    // f1 is not the active filter here (default page state), so the live
    // filter is left untouched — no fallback reset.
    expect(bench.fake.applyBatchFilterUpdateCalled, 0);
  });

  testWidgets(
    'deleting the ACTIVE filter falls back to the default "All" view',
    (tester) async {
      // Page state matches f1 ("IN_PROGRESS"), so f1 reads as the active
      // selection. Deleting it must not strand the list on an orphaned filter:
      // the live filter resets to the default (empty) shape.
      final bench = await _pumpSheet(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
      );

      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
      await tester.pump();
      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.delete('f1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('DELETE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(bench.saved.deleteCalls.single, 'f1');
      // Fallback reset to default: clearToDefault() pushes an empty status set
      // (the "All" view) onto the live page.
      expect(bench.fake.applyBatchFilterUpdateCalled, 1);
      expect(bench.fake.setSelectedTaskStatusesCalls.single, <String>{});
    },
  );

  testWidgets('Save current filter as… creates from the live filter', (
    tester,
  ) async {
    final bench = await _pumpSheet(
      tester,
      pageState: const JournalPageState(selectedTaskStatuses: {'OPEN'}),
    );

    await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.createRow));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(SaveCurrentTaskFilterKeys.nameField),
      'My filter',
    );
    await tester.pump();
    await tester.tap(find.byKey(SaveCurrentTaskFilterKeys.saveButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(bench.saved.createCalls.single, 'My filter');
  });
}
