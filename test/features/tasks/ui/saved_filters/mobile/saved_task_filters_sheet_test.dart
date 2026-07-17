import 'dart:async';

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
import '../../../../categories/test_utils.dart';

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
  final List<(String dragId, String targetId)> reorderCalls = [];

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

  @override
  Future<void> reorder(String dragId, String targetId) async {
    reorderCalls.add((dragId, targetId));
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
  Finder nameTextField() => find.descendant(
    of: find.byKey(SaveCurrentTaskFilterKeys.nameField),
    matching: find.byType(TextField),
  );

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

  bool rowHasSelectedSurface(WidgetTester tester, Key rowKey) {
    final decorated = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byKey(rowKey),
        matching: find.byType(DecoratedBox),
      ),
    );
    return decorated.any(
      (d) =>
          d.decoration is BoxDecoration &&
          (d.decoration as BoxDecoration).color ==
              dsTokensLight.colors.surface.selected,
    );
  }

  testWidgets(
    'the active row carries a token-backed selected surface tint',
    (tester) async {
      // Page state matches f1 → f1 is the active selection. Selection must be
      // multi-channel: the active row gets a `surface.selected` background tint
      // (the rail pill's mint), not just the teal radio.
      await _pumpSheet(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
      );

      expect(
        rowHasSelectedSurface(tester, SavedTaskFiltersSheetKeys.row('f1')),
        isTrue,
        reason: 'active row tinted with surface.selected',
      );
      // An inactive row stays untinted, so the tint is a true selection signal.
      expect(
        rowHasSelectedSurface(tester, SavedTaskFiltersSheetKeys.row('f2')),
        isFalse,
        reason: 'inactive row is not tinted',
      );
    },
  );

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
    'Edit-mode Rename/Delete: >=48dp targets, generous separation, inset from '
    'the row edge, with clear icon weight',
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
      final rowRect = tester.getRect(
        find.byKey(SavedTaskFiltersSheetKeys.row('f1')),
      );

      for (final r in [renameRect, deleteRect]) {
        expect(r.width, greaterThanOrEqualTo(48));
        expect(r.height, greaterThanOrEqualTo(48));
      }
      // Generous (>= step5) gap between the two targets so the destructive
      // Delete is clearly separated from Rename and can't be mis-tapped.
      expect(
        deleteRect.left - renameRect.right,
        greaterThanOrEqualTo(dsTokensLight.spacing.step5),
      );
      // Delete is inset from the row's right edge (trailing gap + row padding),
      // so the destructive control isn't the smallest / edge-most element.
      expect(
        rowRect.right - deleteRect.right,
        greaterThanOrEqualTo(dsTokensLight.spacing.step4),
      );
      // Both glyphs carry the larger (step6) icon weight — bigger than the
      // step5 radio — for clear parity between the two controls.
      for (final key in [
        SavedTaskFiltersSheetKeys.rename('f1'),
        SavedTaskFiltersSheetKeys.delete('f1'),
      ]) {
        final icon = tester.widget<Icon>(
          find.descendant(of: find.byKey(key), matching: find.byType(Icon)),
        );
        expect(icon.size, dsTokensLight.spacing.step6);
      }
    },
  );

  testWidgets(
    'unselected radio uses a perceivable medium-emphasis ring; selected is teal',
    (tester) async {
      // f1 matches the live filter → filled teal radio; f2 is resting → a
      // medium-emphasis ring (raised from the old near-invisible low emphasis)
      // so the single-select control is perceivable before it's filled.
      await _pumpSheet(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
      );

      final selectedRadio = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(SavedTaskFiltersSheetKeys.row('f1')),
          matching: find.byIcon(Icons.radio_button_checked_rounded),
        ),
      );
      final restingRadio = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(SavedTaskFiltersSheetKeys.row('f2')),
          matching: find.byIcon(Icons.radio_button_unchecked_rounded),
        ),
      );
      expect(selectedRadio.color, dsTokensLight.colors.interactive.enabled);
      expect(restingRadio.color, dsTokensLight.colors.text.mediumEmphasis);
    },
  );

  Iterable<Container> accentDots(WidgetTester tester, Key rowKey) => tester
      .widgetList<Container>(
        find.descendant(
          of: find.byKey(rowKey),
          matching: find.byType(Container),
        ),
      )
      .where((c) {
        final d = c.decoration;
        return d is BoxDecoration &&
            d.shape == BoxShape.circle &&
            d.color == dsTokensLight.colors.interactive.enabled;
      });

  testWidgets(
    'Edit mode demotes the active radio to a non-interactive status dot',
    (tester) async {
      // f1 matches the live filter → it is the active selection.
      await _pumpSheet(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
      );

      // Outside Edit mode the active row carries a tap-to-select radio.
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFiltersSheetKeys.row('f1')),
          matching: find.byIcon(Icons.radio_button_checked_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
      await tester.pump();

      // In Edit mode selection is disabled, so NO radio remains anywhere (a
      // radio would imply "tap to select" against the Rename/Delete actions)…
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);
      // …the active row instead shows a plain accent status dot…
      expect(
        accentDots(tester, SavedTaskFiltersSheetKeys.row('f1')),
        isNotEmpty,
      );
      // …and an inactive row shows neither a radio nor a status dot.
      expect(
        accentDots(tester, SavedTaskFiltersSheetKeys.row('f2')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'active-row count lifts to high emphasis on its mint surface; inactive '
    'stays medium',
    (tester) async {
      // The count must read as legible DATA on the selected row's mint tint:
      // the active f1 count (12) lifts to high emphasis, the inactive f2 count
      // (7) keeps the secondary medium emphasis.
      await _pumpSheet(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
      );

      final activeCount = tester.widget<Text>(
        find.descendant(
          of: find.byKey(SavedTaskFiltersSheetKeys.row('f1')),
          matching: find.text('12'),
        ),
      );
      final inactiveCount = tester.widget<Text>(
        find.descendant(
          of: find.byKey(SavedTaskFiltersSheetKeys.row('f2')),
          matching: find.text('7'),
        ),
      );
      expect(activeCount.style?.color, dsTokensLight.colors.text.highEmphasis);
      expect(
        inactiveCount.style?.color,
        dsTokensLight.colors.text.mediumEmphasis,
      );
    },
  );

  testWidgets(
    'toggling Edit keeps the same row height (the list does not jump)',
    (tester) async {
      await _pumpSheet(tester);

      final normalHeight = tester
          .getSize(find.byKey(SavedTaskFiltersSheetKeys.row('f1')))
          .height;

      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
      await tester.pump();

      final editHeight = tester
          .getSize(find.byKey(SavedTaskFiltersSheetKeys.row('f1')))
          .height;

      // Same min-height/padding in both modes: Edit swaps the count for the
      // action pair without resizing the row, so the list stays steady.
      expect(editHeight, normalHeight);
      expect(editHeight, greaterThanOrEqualTo(48));
    },
  );

  testWidgets(
    '"All tasks" drops its count in Edit mode (no count vs action-pairs)',
    (tester) async {
      await _pumpSheet(tester);

      // Normal mode: the All total is shown.
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFiltersSheetKeys.allRow),
          matching: find.text('124'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
      await tester.pump();

      // Edit mode: "All tasks" carries neither a count nor per-row actions, so
      // it never mixes a lone count against the other rows' action pairs.
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFiltersSheetKeys.allRow),
          matching: find.text('124'),
        ),
        findsNothing,
      );
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

  testWidgets(
    'Edit mode explains sidebar order and reorders saved filters',
    (tester) async {
      final bench = await _pumpSheet(tester);

      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
      await tester.pump();

      expect(
        find.text(
          'Drag to set the order. The first five filters appear in the sidebar.',
        ),
        findsOneWidget,
      );
      for (final id in ['f1', 'f2']) {
        final handle = find.byKey(
          SavedTaskFiltersSheetKeys.dragHandle(id),
        );
        expect(handle, findsOneWidget);
        expect(tester.getSize(handle).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(handle).height, greaterThanOrEqualTo(48));
      }

      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      final proxy = list.proxyDecorator!(
        const Text('Drag preview'),
        0,
        const AlwaysStoppedAnimation<double>(1),
      );
      expect(proxy, isA<Material>());
      expect((proxy as Material).type, MaterialType.transparency);

      list.onReorderItem!(1, 0);
      await tester.pump();

      list.onReorderItem!(0, 1);
      await tester.pump();

      expect(bench.saved.reorderCalls, [
        ('f2', 'f1'),
        ('f1', 'f2'),
      ]);
    },
  );

  testWidgets('Edit mode keeps long saved-filter lists scrollable', (
    tester,
  ) async {
    final saved = List.generate(
      20,
      (index) => SavedTaskFilter(
        id: 'filter-$index',
        name: 'Filter $index',
        filter: const TasksFilter(),
      ),
    );
    await _pumpSheet(tester, seed: saved);

    await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
    await tester.pump();

    final listFinder = find.byType(ReorderableListView);
    final list = tester.widget<ReorderableListView>(listFinder);
    expect(list.physics, isNot(isA<NeverScrollableScrollPhysics>()));

    final scrollableFinder = find.descendant(
      of: listFinder,
      matching: find.byType(Scrollable),
    );
    await tester.drag(listFinder, const Offset(0, -300));
    await tester.pump();

    expect(
      tester.state<ScrollableState>(scrollableFinder).position.pixels,
      greaterThan(0),
    );
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

    expect(find.text('Rename In Progress'), findsOneWidget);
    await tester.enterText(
      nameTextField(),
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
      nameTextField(),
      'My filter',
    );
    await tester.pump();
    await tester.tap(find.byKey(SaveCurrentTaskFilterKeys.saveButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(bench.saved.createCalls.single, 'My filter');
  });

  testWidgets(
    'a filter with a category renders a colored dot and names it in semantics',
    (tester) async {
      when(
        () => getIt<EntitiesCacheService>().getCategoryById('cat-work'),
      ).thenReturn(
        CategoryTestUtils.createTestCategory(
          id: 'cat-work',
          name: 'Work',
          color: '#00FF00',
        ),
      );

      const categorized = SavedTaskFilter(
        id: 'fc',
        name: 'Work items',
        filter: TasksFilter(selectedCategoryIds: {'cat-work'}),
      );
      await _pumpSheet(tester, seed: const [categorized]);

      // The row draws the category dot: a circular, green-filled Container.
      final dot = tester.widgetList<Container>(
        find.descendant(
          of: find.byKey(SavedTaskFiltersSheetKeys.row('fc')),
          matching: find.byType(Container),
        ),
      );
      expect(
        dot.any(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
        isTrue,
      );

      // The category is also spoken in the row's accessibility label so the
      // information is never colour-only.
      final semantics = tester.getSemantics(
        find.byKey(SavedTaskFiltersSheetKeys.row('fc')),
      );
      expect(semantics.label, contains('Work'));
    },
  );

  testWidgets(
    'create closes the sheet only when a filter is saved, not on cancel',
    (tester) async {
      // The sheet is presented as a real route so its post-create
      // `Navigator.maybePop()` has something to close — the default harness
      // renders it as the root route where a pop is a no-op.
      final fake = FakeJournalPageController(
        const JournalPageState(selectedTaskStatuses: {'OPEN'}),
      );
      final saved = _RecordingSavedController(const [_f1, _f2]);
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(body: SizedBox.shrink()),
          navigatorKey: navKey,
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

      unawaited(
        navKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: SavedTaskFiltersSheet()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SavedTaskFiltersSheet), findsOneWidget);

      // Cancel the name modal → nothing is created and the sheet stays open.
      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.createRow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(saved.createCalls, isEmpty);
      expect(find.byType(SavedTaskFiltersSheet), findsOneWidget);

      // Save a name → the filter is created and the sheet closes.
      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.createRow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        nameTextField(),
        'My filter',
      );
      await tester.pump();
      await tester.tap(find.byKey(SaveCurrentTaskFilterKeys.saveButton));
      await tester.pump();
      // Two transitions run back-to-back: the name modal closes, then
      // `_create` pops the sheet route — pump enough for both to finish.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(saved.createCalls, ['My filter']);
      expect(find.byType(SavedTaskFiltersSheet), findsNothing);
    },
  );
}
