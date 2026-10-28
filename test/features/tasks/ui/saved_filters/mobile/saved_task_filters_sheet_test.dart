import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/classes/saved_task_filter.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/save_current_task_filter.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
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
  final List<String> togglePinCalls = [];

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

  @override
  Future<void> togglePin(String id) async {
    togglePinCalls.add(id);
  }
}

class _StubPinnedOnly extends SavedTaskFiltersPinnedOnlyController {
  _StubPinnedOnly({required this.initial});
  final bool initial;

  final List<bool> setCalls = [];

  @override
  Future<bool> build() async => initial;

  @override
  Future<void> set({required bool pinnedOnly}) async {
    setCalls.add(pinnedOnly);
    state = AsyncData(pinnedOnly);
  }
}

Future<
  ({
    FakeJournalPageController fake,
    _RecordingSavedController saved,
    _StubPinnedOnly pinnedOnly,
  })
>
_pumpSheet(
  WidgetTester tester, {
  JournalPageState pageState = const JournalPageState(),
  List<SavedTaskFilter> seed = const [_f1, _f2],
  bool pinnedOnly = false,
}) async {
  final fake = FakeJournalPageController(pageState);
  final saved = _RecordingSavedController(seed);
  final pinnedOnlyStub = _StubPinnedOnly(initial: pinnedOnly);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      const Scaffold(
        body: CustomScrollView(slivers: [SavedTaskFiltersSheet()]),
        bottomNavigationBar: SavedTaskFiltersSaveFooter(),
      ),
      overrides: [
        savedTaskFiltersPinnedOnlyProvider.overrideWith(() => pinnedOnlyStub),
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
  return (fake: fake, saved: saved, pinnedOnly: pinnedOnlyStub);
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

  testWidgets(
    'Edit toggle is a tertiary design-system button on the glass bar, '
    'labelled Edit and then Done',
    (tester) async {
      await _pumpSheet(tester);

      DesignSystemButton button() => tester.widget<DesignSystemButton>(
        find.byKey(SavedTaskFiltersSheetKeys.editToggle),
      );
      expect(button().variant, DesignSystemButtonVariant.tertiary);
      expect(button().label, 'Edit');
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFiltersSheetBarKeys.bar),
          matching: find.byKey(SavedTaskFiltersSheetKeys.editToggle),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
      await tester.pump();
      expect(button().label, 'Done');
    },
  );

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
          matching: find.byIcon(LottiIcons.radioSelected),
        ),
      );
      final restingRadio = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(SavedTaskFiltersSheetKeys.row('f2')),
          matching: find.byIcon(LottiIcons.radioUnselected),
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
          matching: find.byIcon(LottiIcons.radioSelected),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
      await tester.pump();

      // In Edit mode selection is disabled, so NO radio remains anywhere (a
      // radio would imply "tap to select" against the Rename/Delete actions)…
      expect(find.byIcon(LottiIcons.radioSelected), findsNothing);
      expect(find.byIcon(LottiIcons.radioUnselected), findsNothing);
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

      final list = tester.widget<SliverReorderableList>(
        find.byType(SliverReorderableList),
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

  for (final editing in [false, true]) {
    testWidgets(
      'a long list scrolls in the one scroll view, under the pinned bar '
      '(editing: $editing)',
      (tester) async {
        final saved = List.generate(
          20,
          (index) => SavedTaskFilter(
            id: 'filter-$index',
            name: 'Filter $index',
            filter: const TasksFilter(),
          ),
        );
        await _pumpSheet(tester, seed: saved);
        if (editing) {
          await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
          await tester.pump();
        }

        // One Scrollable for the whole sheet: the rows are slivers of the
        // host's scroll view, never a list scrolling inside it.
        expect(find.byType(Scrollable), findsOneWidget);
        final barTop = tester
            .getTopLeft(find.byKey(SavedTaskFiltersSheetBarKeys.bar))
            .dy;

        await tester.drag(
          find.byKey(SavedTaskFiltersSheetKeys.row('filter-3')),
          const Offset(0, -300),
        );
        await tester.pump();

        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .pixels,
          greaterThan(0),
        );
        // The bar stayed where it was while the rows moved under it.
        expect(
          tester.getTopLeft(find.byKey(SavedTaskFiltersSheetBarKeys.bar)).dy,
          barTop,
        );
      },
    );
  }

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

    // Confirmation modal — the primary action renders the confirm label verbatim.
    await tester.tap(find.text('Delete'));
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

      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(bench.saved.deleteCalls.single, 'f1');
      // Fallback reset to default: clearToDefault() pushes an empty status set
      // (the "All" view) onto the live page.
      expect(bench.fake.applyBatchFilterUpdateCalled, 1);
      expect(bench.fake.setSelectedTaskStatusesCalls.single, <String>{});
    },
  );

  testWidgets(
    "Save current filter is the sticky glass footer's one large, full-width "
    'primary action',
    (tester) async {
      await _pumpSheet(tester);

      final button = tester.widget<DesignSystemButton>(
        find.byKey(SavedTaskFiltersSheetKeys.saveCurrent),
      );
      expect(button.variant, DesignSystemButtonVariant.primary);
      expect(button.size, DesignSystemButtonSize.large);
      expect(button.fullWidth, isTrue);
      expect(button.leadingIcon, LottiIcons.add);
      expect(button.label, 'Save current filter…');
      expect(
        find.ancestor(
          of: find.byKey(SavedTaskFiltersSheetKeys.saveCurrent),
          matching: find.byType(DesignSystemGlassActionFooter),
        ),
        findsOneWidget,
      );
      // It is the footer, not a row of the list.
      expect(
        find.descendant(
          of: find.byType(SavedTaskFiltersSheet),
          matching: find.byKey(SavedTaskFiltersSheetKeys.saveCurrent),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('the last row scrolls clear of the sticky footer', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      seed: List.generate(
        20,
        (index) => SavedTaskFilter(
          id: 'filter-$index',
          name: 'Filter $index',
          filter: const TasksFilter(),
        ),
      ),
    );

    await tester.drag(
      find.byKey(SavedTaskFiltersSheetKeys.row('filter-3')),
      const Offset(0, -5000),
    );
    await tester.pump();

    final lastRow = tester.getRect(
      find.byKey(SavedTaskFiltersSheetKeys.row('filter-19')),
    );
    final footer = tester.getRect(find.byType(DesignSystemGlassActionFooter));
    expect(lastRow.bottom, lessThanOrEqualTo(footer.top));
  });

  testWidgets('Save current filter as… creates from the live filter', (
    tester,
  ) async {
    final bench = await _pumpSheet(
      tester,
      pageState: const JournalPageState(selectedTaskStatuses: {'OPEN'}),
    );

    await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.saveCurrent));
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
      expect(find.bySemanticsLabel('Work, Work items'), findsOneWidget);
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
            savedTaskFiltersPinnedOnlyProvider.overrideWith(
              () => _StubPinnedOnly(initial: false),
            ),
            savedTaskFilterCountsProvider.overrideWith(
              (ref) async => const {'f1': 12, 'f2': 7},
            ),
            allTasksTotalCountProvider.overrideWith((ref) async => 124),
          ],
        ),
      );
      await tester.pump();

      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: CustomScrollView(slivers: [SavedTaskFiltersSheet()]),
            bottomNavigationBar: SavedTaskFiltersSaveFooter(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SavedTaskFiltersSheet), findsOneWidget);

      // Cancel the name modal → nothing is created and the sheet stays open.
      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.saveCurrent));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(saved.createCalls, isEmpty);
      expect(find.byType(SavedTaskFiltersSheet), findsOneWidget);

      // Save a name → the filter is created and the sheet closes.
      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.saveCurrent));
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

  group('pinning', () {
    const pinned = SavedTaskFilter(
      id: 'p1',
      name: 'Pinned one',
      filter: TasksFilter(selectedTaskStatuses: {'OPEN'}),
      pinned: true,
    );
    const pinned2 = SavedTaskFilter(
      id: 'p2',
      name: 'Pinned two',
      filter: TasksFilter(selectedTaskStatuses: {'DONE'}),
      pinned: true,
    );

    Icon pinIcon(WidgetTester tester, String id) => tester.widget<Icon>(
      find.descendant(
        of: find.byKey(SavedTaskFiltersSheetBarKeys.pin(id)),
        matching: find.byType(Icon),
      ),
    );

    testWidgets(
      'each row carries its pin state, and a tap flips it without selecting '
      'the row',
      (tester) async {
        final bench = await _pumpSheet(tester, seed: const [_f1, pinned]);

        expect(pinIcon(tester, 'f1').icon, LottiIcons.pin);
        expect(pinIcon(tester, 'p1').icon, LottiIconsFilled.pin);

        await tester.tap(find.byKey(SavedTaskFiltersSheetBarKeys.pin('f1')));
        await tester.pump();

        expect(bench.saved.togglePinCalls, ['f1']);
        // The pin is its own target: the row's apply did not fire.
        expect(bench.fake.applyBatchFilterUpdateCalled, 0);
      },
    );

    testWidgets('the pin is its own button to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpSheet(tester, seed: const [_f1, pinned]);

      expect(
        tester.getSemantics(find.byKey(SavedTaskFiltersSheetBarKeys.pin('f1'))),
        matchesSemantics(
          label: 'Pin In Progress',
          isButton: true,
          hasToggledState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(SavedTaskFiltersSheetBarKeys.pin('p1'))),
        matchesSemantics(
          label: 'Unpin Pinned one',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('Edit rows trade the pin for their Rename / Delete pair', (
      tester,
    ) async {
      await _pumpSheet(tester, seed: const [_f1, pinned]);
      await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
      await tester.pump();

      expect(find.byType(SavedTaskFilterPinToggle), findsNothing);
    });

    testWidgets(
      'All tasks keeps the pin slot, so its count lines up with the rows',
      (tester) async {
        await _pumpSheet(tester, seed: const [_f1, pinned]);

        final allCount = tester.getRect(
          find.descendant(
            of: find.byKey(SavedTaskFiltersSheetKeys.allRow),
            matching: find.text('124'),
          ),
        );
        final rowCount = tester.getRect(
          find.descendant(
            of: find.byKey(SavedTaskFiltersSheetKeys.row('f1')),
            matching: find.text('12'),
          ),
        );
        expect(allCount.right, rowCount.right);
      },
    );

    testWidgets('the pinned-only switch writes through the controller', (
      tester,
    ) async {
      final bench = await _pumpSheet(tester, seed: const [_f1, pinned]);

      await tester.tap(find.byKey(SavedTaskFiltersSheetBarKeys.pinnedOnly));
      await tester.pump();

      expect(bench.pinnedOnly.setCalls, [true]);
      // The list follows the switch at once.
      expect(find.byKey(SavedTaskFiltersSheetKeys.row('f1')), findsNothing);
      expect(find.byKey(SavedTaskFiltersSheetKeys.row('p1')), findsOneWidget);
    });

    testWidgets('pinned only shows the pinned rows, in Edit mode too', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        seed: const [_f1, pinned, _f2, pinned2],
        pinnedOnly: true,
      );

      for (final editing in [false, true]) {
        expect(find.byKey(SavedTaskFiltersSheetKeys.row('f1')), findsNothing);
        expect(find.byKey(SavedTaskFiltersSheetKeys.row('f2')), findsNothing);
        expect(find.byKey(SavedTaskFiltersSheetKeys.row('p1')), findsOneWidget);
        expect(find.byKey(SavedTaskFiltersSheetKeys.row('p2')), findsOneWidget);
        // All tasks is not a saved filter and is never hidden.
        expect(find.byKey(SavedTaskFiltersSheetKeys.allRow), findsOneWidget);
        if (!editing) {
          await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
          await tester.pump();
        }
      }
      expect(
        find.text(
          'Drag to set the order. Pinned filters appear in the sidebar.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'a drag among the pinned rows places the move by id in the full list',
      (tester) async {
        final bench = await _pumpSheet(
          tester,
          seed: const [pinned, _f1, _f2, pinned2],
          pinnedOnly: true,
        );
        await tester.tap(find.byKey(SavedTaskFiltersSheetKeys.editToggle));
        await tester.pump();

        tester
            .widget<SliverReorderableList>(find.byType(SliverReorderableList))
            .onReorderItem!(1, 0);
        await tester.pump();

        // Shown index 1 is p2 and index 0 is p1, whatever sits between them
        // in the full list.
        expect(bench.saved.reorderCalls, [('p2', 'p1')]);
      },
    );

    testWidgets('an empty pinned-only list says how to fill it', (
      tester,
    ) async {
      await _pumpSheet(tester, pinnedOnly: true);

      expect(
        find.byKey(SavedTaskFiltersSheetKeys.pinnedEmpty),
        findsOneWidget,
      );
      expect(
        find.text(
          'No pinned filters yet. Turn off Pinned only and pin the filters '
          'you want to keep in view.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a list with pinned rows shows no empty hint', (
      tester,
    ) async {
      await _pumpSheet(tester, seed: const [pinned], pinnedOnly: true);

      expect(find.byKey(SavedTaskFiltersSheetKeys.pinnedEmpty), findsNothing);
    });
  });
}
