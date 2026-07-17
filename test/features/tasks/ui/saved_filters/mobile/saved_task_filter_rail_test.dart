import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/save_current_task_filter.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_pill.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_rail.dart';
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

// A wordy real-world filter name (category + status), matching the shape
// that overflowed the rail in production: at normal text scale on a narrow
// phone width, the MRU pill's actual rendered width blew past
// `_fitMruCount`'s flat per-pill estimate, since only the anchor pill was
// ever wrapped in `Flexible`.
const _fLong = SavedTaskFilter(
  id: 'f-long',
  name: 'Lotti-in-progress',
  filter: TasksFilter(selectedCategoryIds: {'cat-lotti'}),
);

const _wideMq = MediaQueryData(
  size: Size(900, 800),
  textScaler: TextScaler.noScaling,
);

const _largeTextMq = MediaQueryData(
  size: Size(390, 844),
  textScaler: TextScaler.linear(1.4),
);

// A harder accessibility size: at 1.6x the old non-scrolling collapse overflowed
// the row by ~15px. The collapsed rail must now scroll instead of overflowing.
const _xLargeTextMq = MediaQueryData(
  size: Size(390, 844),
  textScaler: TextScaler.linear(1.6),
);

/// The left-edge x of the widget with [key] — used to assert the collapsed
/// large-text order (active anchor leads, then All, then Saved).
double _leftOf(WidgetTester tester, Key key) =>
    tester.getTopLeft(find.byKey(key)).dx;

class _StubSavedController extends SavedTaskFiltersController {
  _StubSavedController(this._seed);
  final List<SavedTaskFilter> _seed;

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;
}

/// Repository that returns [value] for any filter, or a gated future once
/// [gate] is set — used to hold the counts provider in the loading state while
/// keeping its previous value (stale-while-revalidate).
class _GatedRepo implements SavedTaskFilterCountRepository {
  _GatedRepo(this.value);
  int value;
  Completer<int>? gate;

  @override
  Future<int> count(TasksFilter filter) {
    final g = gate;
    if (g != null) return g.future;
    return Future.value(value);
  }
}

Future<({ProviderContainer container})> _pumpRail(
  WidgetTester tester, {
  required JournalPageState pageState,
  List<SavedTaskFilter> seed = const [_f1, _f2],
  List<Override> extraOverrides = const [],
  Override? countsOverride,
  Override? currentCountOverride,
  MediaQueryData? mq,
}) async {
  final fake = FakeJournalPageController(pageState);
  final result = makeTestableWidgetWithContainer(
    const Scaffold(body: SavedTaskFilterRail()),
    mediaQueryData: mq ?? phoneMediaQueryData,
    overrides: [
      journalPageControllerProvider(true).overrideWith(() => fake),
      savedTaskFiltersControllerProvider.overrideWith(
        () => _StubSavedController(seed),
      ),
      countsOverride ??
          savedTaskFilterCountsProvider.overrideWith(
            (ref) async => const {'f1': 12, 'f2': 7},
          ),
      allTasksTotalCountProvider.overrideWith((ref) async => 124),
      // The "Custom" pill's live filtered count — kept off the GetIt-backed
      // repository. A distinctive value so the pill assertion is unambiguous.
      currentCountOverride ??
          currentTasksFilterCountProvider.overrideWith((ref) async => 4),
      ...extraOverrides,
    ],
  );
  addTearDown(result.container.dispose);
  await tester.pumpWidget(result.widget);
  await tester.pump();
  await tester.pump();
  return (container: result.container);
}

SavedTaskFilterPill _pill(WidgetTester tester, Key key) =>
    tester.widget<SavedTaskFilterPill>(find.byKey(key));

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

  testWidgets('collapses to nothing when there are no saved filters', (
    tester,
  ) async {
    await _pumpRail(
      tester,
      pageState: const JournalPageState(),
      seed: const [],
    );

    expect(find.byKey(SavedTaskFilterRailKeys.savedButton), findsNothing);
    expect(find.byKey(SavedTaskFilterRailKeys.allPill), findsNothing);
  });

  testWidgets(
    'Views button shows the saved-view count in the shared slot and opens '
    'the sheet',
    (
      tester,
    ) async {
      // Seed has 2 filters → the Views button reads "Views  2", using the SAME
      // shared count widget as the rail pills so it stays consistent with the
      // "All 124" / per-filter numerals.
      await _pumpRail(tester, pageState: const JournalPageState());

      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.savedButton),
          matching: find.text('Views'),
        ),
      );
      // The label inherits the filled pill's high-emphasis colour…
      expect(label.style?.color, dsTokensLight.colors.text.highEmphasis);
      // …the count rides the shared SavedFilterCountText slot (reads "2")…
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.savedButton),
          matching: find.byType(SavedFilterCountText),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.savedButton),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      // …and the count rides the slot, never a parenthetical baked into label.
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.savedButton),
          matching: find.textContaining('('),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(SavedTaskFilterRailKeys.savedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SavedTaskFiltersSheet), findsOneWidget);
    },
  );

  testWidgets(
    'Views button glyphs use high-emphasis for light-theme contrast',
    (
      tester,
    ) async {
      await _pumpRail(tester, pageState: const JournalPageState());

      final high = dsTokensLight.colors.text.highEmphasis;
      final bookmark = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.savedButton),
          matching: find.byIcon(Icons.bookmarks_outlined),
        ),
      );
      final glyph = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.savedButton),
          matching: find.byIcon(Icons.unfold_more_rounded),
        ),
      );
      expect(bookmark.color, high);
      expect(glyph.color, high);
    },
  );

  testWidgets(
    'Views button is a distinct borderless chip with a panel-disclosure glyph',
    (
      tester,
    ) async {
      await _pumpRail(tester, pageState: const JournalPageState());

      final pill = tester.widget<DsPill>(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.savedButton),
          matching: find.byType(DsPill),
        ),
      );
      // Chip chrome (not a bare label)…
      expect(pill.variant, DsPillVariant.filled);
      // …but borderless, so the menu-opener is visually distinct from the
      // bordered All / active filter pills rather than reading as a filter value.
      expect(pill.bordered, isFalse);
      // An `unfold_more` glyph (not a down-chevron) signals a panel that rises
      // as a bottom sheet rather than a dropdown.
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.savedButton),
          matching: find.byIcon(Icons.unfold_more_rounded),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    },
  );

  testWidgets('Save chip is a teal-tinted CTA, not a bordered/ghost chip', (
    tester,
  ) async {
    await _pumpRail(
      tester,
      pageState: const JournalPageState(selectedPriorities: {'P0'}),
    );

    final pill = tester.widget<DsPill>(
      find.descendant(
        of: find.byKey(SavedTaskFilterRailKeys.saveChip),
        matching: find.byType(DsPill),
      ),
    );
    // Filled teal-tint (no border) so the CTA does not share the teal-outline
    // vocabulary of the bordered active / Custom selection pills.
    expect(pill.variant, DsPillVariant.tinted);
    expect(pill.color, dsTokensLight.colors.interactive.enabled);
    // Leading "+" affordance; the muted dashed ghost-chip skin is gone.
    expect(find.byType(DsGhostChip), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(SavedTaskFilterRailKeys.saveChip),
        matching: find.byIcon(Icons.add_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'large text leads with the active anchor, then All, then Saved (scrollable)',
    (tester) async {
      await _pumpRail(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
        mq: _largeTextMq,
      );

      // The active saved pill is the anchor and LEADS; the MRU f2 quick-jump is
      // dropped, but "All" is KEPT (an unselected reset) so return-to-unfiltered
      // stays one tap, followed by the Views button.
      expect(
        _pill(tester, SavedTaskFilterRailKeys.pill('f1')).selected,
        isTrue,
      );
      expect(_pill(tester, SavedTaskFilterRailKeys.allPill).selected, isFalse);
      expect(find.byKey(SavedTaskFilterRailKeys.savedButton), findsOneWidget);
      expect(find.byKey(SavedTaskFilterRailKeys.pill('f2')), findsNothing);

      // Order: active anchor → All → Saved.
      expect(
        _leftOf(tester, SavedTaskFilterRailKeys.pill('f1')),
        lessThan(_leftOf(tester, SavedTaskFilterRailKeys.allPill)),
      );
      expect(
        _leftOf(tester, SavedTaskFilterRailKeys.allPill),
        lessThan(_leftOf(tester, SavedTaskFilterRailKeys.savedButton)),
      );

      // The whole run is ONE horizontal scroll view (the rail root itself), so
      // at accessibility sizes the chips scroll instead of overflowing…
      final root = tester.widget<SingleChildScrollView>(
        find.byKey(SavedTaskFilterRailKeys.root),
      );
      expect(root.scrollDirection, Axis.horizontal);
      // …and the "Saved" button now lives INSIDE that scroll run (no pinned
      // split that could overlap a bisected "All").
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.root),
          matching: find.byKey(SavedTaskFilterRailKeys.savedButton),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'large text leads with the Custom anchor, then All + Save chip',
    (tester) async {
      await _pumpRail(
        tester,
        pageState: const JournalPageState(selectedPriorities: {'P0'}),
        mq: _largeTextMq,
      );

      // Ad-hoc filter → Custom anchor leads; "All" survives the collapse as the
      // one-tap reset, and the Save chip is still offered.
      final custom = _pill(tester, SavedTaskFilterRailKeys.customPill);
      expect(custom.selected, isTrue);
      expect(_pill(tester, SavedTaskFilterRailKeys.allPill).selected, isFalse);
      expect(find.byKey(SavedTaskFilterRailKeys.saveChip), findsOneWidget);
      // Custom leads the All reset.
      expect(
        _leftOf(tester, SavedTaskFilterRailKeys.customPill),
        lessThan(_leftOf(tester, SavedTaskFilterRailKeys.allPill)),
      );
    },
  );

  testWidgets('large text default view keeps All as the leading anchor', (
    tester,
  ) async {
    await _pumpRail(
      tester,
      pageState: const JournalPageState(),
      mq: _largeTextMq,
    );

    // All is the active selection, surfaced as the single anchor pill (no
    // duplicate reset) and leading the Views button; no quick-jump pills render.
    expect(_pill(tester, SavedTaskFilterRailKeys.allPill).selected, isTrue);
    expect(find.byKey(SavedTaskFilterRailKeys.pill('f1')), findsNothing);
    expect(find.byKey(SavedTaskFilterRailKeys.pill('f2')), findsNothing);
    expect(
      _leftOf(tester, SavedTaskFilterRailKeys.allPill),
      lessThan(_leftOf(tester, SavedTaskFilterRailKeys.savedButton)),
    );
  });

  testWidgets(
    'large text collapsed rail scrolls without overlap at 1.6x scale',
    (tester) async {
      // Regression: the old split — an Expanded horizontal scroll of
      // [anchor][All] plus a separately-pinned "Saved" — let "Saved" overlap a
      // bisected "All" at ~1.6x. The single scroll run must lay out cleanly with
      // a real gap between every chip and never overlap.
      await _pumpRail(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
        mq: _xLargeTextMq,
      );

      // No RenderFlex overflow / exception: the single scroll run absorbs the
      // slack the old pinned split could not.
      expect(tester.takeException(), isNull);

      // The rail root IS a single horizontal scroll view.
      final root = tester.widget<SingleChildScrollView>(
        find.byKey(SavedTaskFilterRailKeys.root),
      );
      expect(root.scrollDirection, Axis.horizontal);

      // The active anchor leads and "Saved" rides the same run.
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.root),
          matching: find.byKey(SavedTaskFilterRailKeys.pill('f1')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.root),
          matching: find.byKey(SavedTaskFilterRailKeys.savedButton),
        ),
        findsOneWidget,
      );

      // A REAL gap between chips (no overlap): "All" starts one inter-pill gap
      // (step2) after the anchor's right edge, never on top of it.
      final anchorRight = tester
          .getTopRight(find.byKey(SavedTaskFilterRailKeys.pill('f1')))
          .dx;
      final allLeft = tester
          .getTopLeft(find.byKey(SavedTaskFilterRailKeys.allPill))
          .dx;
      expect(allLeft, greaterThanOrEqualTo(anchorRight));
      expect(allLeft - anchorRight, closeTo(dsTokensLight.spacing.step2, 0.5));

      // …and the same true between "All" and "Saved".
      final allRight = tester
          .getTopRight(find.byKey(SavedTaskFilterRailKeys.allPill))
          .dx;
      final savedLeft = tester
          .getTopLeft(find.byKey(SavedTaskFilterRailKeys.savedButton))
          .dx;
      expect(savedLeft, greaterThanOrEqualTo(allRight));
      expect(savedLeft - allRight, closeTo(dsTokensLight.spacing.step2, 0.5));
    },
  );

  testWidgets('tri-state: default view selects "All"', (tester) async {
    await _pumpRail(tester, pageState: const JournalPageState());

    expect(_pill(tester, SavedTaskFilterRailKeys.allPill).selected, isTrue);
    // No active saved pill, no Custom pill, no Save chip in the default view.
    expect(find.byKey(SavedTaskFilterRailKeys.customPill), findsNothing);
    expect(find.byKey(SavedTaskFilterRailKeys.saveChip), findsNothing);
  });

  testWidgets('tri-state: a matching live filter selects its saved pill', (
    tester,
  ) async {
    await _pumpRail(
      tester,
      pageState: const JournalPageState(
        selectedTaskStatuses: {'IN_PROGRESS'},
      ),
    );

    expect(_pill(tester, SavedTaskFilterRailKeys.pill('f1')).selected, isTrue);
    expect(_pill(tester, SavedTaskFilterRailKeys.allPill).selected, isFalse);
    // The active pill carries the live count.
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets(
    'tri-state: an ad-hoc filter shows Custom (with its count) + the Save chip',
    (tester) async {
      await _pumpRail(
        tester,
        pageState: const JournalPageState(selectedPriorities: {'P0'}),
      );

      final custom = _pill(tester, SavedTaskFilterRailKeys.customPill);
      expect(custom.selected, isTrue);
      // The active filter never hides its magnitude: Custom now surfaces the
      // live filtered count (4 from the override) in the reserved slot.
      expect(custom.showCount, isTrue);
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.customPill),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(SavedTaskFilterRailKeys.saveChip), findsOneWidget);
      expect(_pill(tester, SavedTaskFilterRailKeys.allPill).selected, isFalse);
    },
  );

  testWidgets('Custom pill shows a "–" placeholder while its count computes', (
    tester,
  ) async {
    // Gate the live count so it never resolves during the test: the Custom
    // pill must still render, showing the reserved-slot placeholder.
    final gate = Completer<int>();
    addTearDown(() => gate.complete(0));
    await _pumpRail(
      tester,
      pageState: const JournalPageState(selectedPriorities: {'P0'}),
      currentCountOverride: currentTasksFilterCountProvider.overrideWith(
        (ref) => gate.future,
      ),
    );

    final custom = _pill(tester, SavedTaskFilterRailKeys.customPill);
    expect(custom.showCount, isTrue);
    expect(
      find.descendant(
        of: find.byKey(SavedTaskFilterRailKeys.customPill),
        matching: find.text('–'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('one tap on a quick-jump pill applies its filter', (
    tester,
  ) async {
    // Wide layout so the MRU quick-jump pills render alongside All.
    final result = await _pumpRail(
      tester,
      pageState: const JournalPageState(),
      mq: _wideMq,
    );

    // f2 ("Blocked") is an inactive quick-jump pill in the default view.
    expect(find.byKey(SavedTaskFilterRailKeys.pill('f2')), findsOneWidget);
    await tester.tap(find.byKey(SavedTaskFilterRailKeys.pill('f2')));
    await tester.pump();

    final fake =
        result.container.read(journalPageControllerProvider(true).notifier)
            as FakeJournalPageController;
    expect(fake.applyBatchFilterUpdateCalled, 1);
    expect(fake.setSelectedTaskStatusesCalls.single, {'BLOCKED'});
  });

  testWidgets(
    'stale-while-revalidate: counts do not flash to a dash on reload',
    (tester) async {
      final repo = _GatedRepo(12);
      await _pumpRail(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
        // Use the real counts provider backed by a gated repo so we can hold it
        // in the loading state with a retained previous value.
        countsOverride: savedTaskFilterCountsProvider.overrideWith(
          savedTaskFilterCounts,
        ),
        extraOverrides: [
          savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
        ],
      );
      // Let the counts resolve. The active f1 pill shows its count.
      await tester.pump();
      await tester.pump();
      final f1Count = find.descendant(
        of: find.byKey(SavedTaskFilterRailKeys.pill('f1')),
        matching: find.text('12'),
      );
      expect(f1Count, findsOneWidget);

      // Gate the next computation, then invalidate — the provider re-enters
      // loading but retains its previous value (no `–` flash).
      repo.gate = Completer<int>();
      ProviderScope.containerOf(
        tester.element(find.byType(SavedTaskFilterRail)),
      ).invalidate(savedTaskFilterCountsProvider);
      await tester.pump();
      await tester.pump();

      // Still 12 (retained), never a loading dash, while the recompute is
      // in flight.
      expect(f1Count, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.pill('f1')),
          matching: find.text('–'),
        ),
        findsNothing,
      );

      repo.gate!.complete(12);
      await tester.pump();
    },
  );

  testWidgets('tapping "All" clears the live filter to the default view', (
    tester,
  ) async {
    // Start from an ad-hoc filter so "All" is not already the selection.
    final result = await _pumpRail(
      tester,
      pageState: const JournalPageState(selectedTaskStatuses: {'OPEN'}),
    );

    await tester.tap(find.byKey(SavedTaskFilterRailKeys.allPill));
    await tester.pump();

    final fake =
        result.container.read(journalPageControllerProvider(true).notifier)
            as FakeJournalPageController;
    expect(fake.applyBatchFilterUpdateCalled, 1);
  });

  testWidgets('tapping "+ Save" opens the name-entry modal', (tester) async {
    // An ad-hoc filter makes the Save chip visible.
    await _pumpRail(
      tester,
      pageState: const JournalPageState(selectedTaskStatuses: {'OPEN'}),
    );

    expect(find.byKey(SavedTaskFilterRailKeys.saveChip), findsOneWidget);
    await tester.tap(find.byKey(SavedTaskFilterRailKeys.saveChip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(SaveCurrentTaskFilterKeys.nameField), findsOneWidget);
  });

  testWidgets('tapping the "Custom" anchor pill opens the sheet', (
    tester,
  ) async {
    await _pumpRail(
      tester,
      pageState: const JournalPageState(selectedTaskStatuses: {'OPEN'}),
    );

    await tester.tap(find.byKey(SavedTaskFilterRailKeys.customPill));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(SavedTaskFiltersSheetKeys.root), findsOneWidget);
  });

  testWidgets('tapping the active saved pill opens the sheet', (tester) async {
    // Page state matches f1 ("In Progress") → f1 is the active anchor.
    await _pumpRail(
      tester,
      pageState: const JournalPageState(selectedTaskStatuses: {'IN_PROGRESS'}),
    );

    await tester.tap(find.byKey(SavedTaskFilterRailKeys.pill('f1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(SavedTaskFiltersSheetKeys.root), findsOneWidget);
  });

  testWidgets(
    'a saved pill with a category speaks the category in its semantics label',
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
        id: 'f3',
        name: 'Work items',
        filter: TasksFilter(selectedCategoryIds: {'cat-work'}),
      );

      // Wide layout so f3 renders as an inactive quick-jump pill.
      await _pumpRail(
        tester,
        pageState: const JournalPageState(),
        seed: const [categorized],
        mq: _wideMq,
      );

      final pill = _pill(tester, SavedTaskFilterRailKeys.pill('f3'));
      expect(pill.semanticsLabel, contains('Work'));
    },
  );

  testWidgets(
    'a long MRU filter name never overflows the row at phone width',
    (tester) async {
      // Regression: `_fitMruCount` only estimates how many quick-jump pills to
      // attempt from a flat per-pill width assumption — it does not measure
      // the real label. A wordy saved filter (e.g. "Lotti-in-progress") could
      // still render past the estimate and throw a RenderFlex overflow,
      // because only the anchor pill was wrapped in `Flexible`; the MRU pills
      // were bare `Row` children with no bound on their width at all.
      //
      // `phoneMediaQueryData` alone only overrides what `MediaQuery.of()`
      // reports — it does not change the real root view size that
      // `LayoutBuilder`'s `constraints.maxWidth` is derived from, so the rail
      // would otherwise lay out against the (much wider) default test
      // surface and never actually exercise the narrow-width path. Pin the
      // real view to match.
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpRail(
        tester,
        pageState: const JournalPageState(),
        seed: const [_fLong, _f2],
        countsOverride: savedTaskFilterCountsProvider.overrideWith(
          (ref) async => const {'f-long': 13, 'f2': 7},
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );
}
