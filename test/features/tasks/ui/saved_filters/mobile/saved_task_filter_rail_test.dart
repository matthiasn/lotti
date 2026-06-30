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
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_pill.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_rail.dart';
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
    'Saved button shows the subordinate "(N)" count and opens the sheet',
    (
      tester,
    ) async {
      // Seed has 2 filters → "Saved (2)".
      await _pumpRail(tester, pageState: const JournalPageState());

      final rich = tester.widget<Text>(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.savedButton),
          matching: find.text('Saved (2)'),
        ),
      );
      // The "(2)" parenthetical is de-ranked to low-emphasis (dimmer than the
      // medium-emphasis task-count pills), while the "Saved" word inherits the
      // root span's filled-pill high-emphasis colour.
      final root = rich.textSpan! as TextSpan;
      expect(root.style?.color, dsTokensLight.colors.text.highEmphasis);
      final spans = root.children!;
      final head = spans.first as TextSpan;
      final tail = spans.last as TextSpan;
      expect(head.text, 'Saved ');
      expect(tail.text, '(2)');
      expect(tail.style?.color, dsTokensLight.colors.text.lowEmphasis);

      await tester.tap(find.byKey(SavedTaskFilterRailKeys.savedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SavedTaskFiltersSheet), findsOneWidget);
    },
  );

  testWidgets(
    'Saved button glyphs use high-emphasis for light-theme contrast',
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
      final chevron = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.savedButton),
          matching: find.byIcon(Icons.expand_more_rounded),
        ),
      );
      expect(bookmark.color, high);
      expect(chevron.color, high);
    },
  );

  testWidgets('Saved button reads as a button: DsPill chrome + chevron', (
    tester,
  ) async {
    await _pumpRail(tester, pageState: const JournalPageState());

    // Same neutral chip chrome as the "All" pill, not a bare label.
    expect(
      find.descendant(
        of: find.byKey(SavedTaskFilterRailKeys.savedButton),
        matching: find.byType(DsPill),
      ),
      findsOneWidget,
    );
    // A disclosure chevron signals that it opens a menu.
    expect(
      find.descendant(
        of: find.byKey(SavedTaskFilterRailKeys.savedButton),
        matching: find.byIcon(Icons.expand_more_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Save chip is a teal outline CTA, not a muted ghost chip', (
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
    expect(pill.variant, DsPillVariant.outline);
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
      // stays one tap, followed by the Saved button.
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

      // The anchor + "All" scroll horizontally (so the leading chips scroll
      // instead of overflowing at accessibility sizes)…
      final scroll = find.descendant(
        of: find.byKey(SavedTaskFilterRailKeys.root),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.horizontal,
      );
      // …while the "Saved" button is PINNED outside that scroll view (it must
      // never scroll off into an "S" sliver at large text).
      expect(
        find.descendant(
          of: scroll,
          matching: find.byKey(SavedTaskFilterRailKeys.savedButton),
        ),
        findsNothing,
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
    // duplicate reset) and leading the Saved button; no quick-jump pills render.
    expect(_pill(tester, SavedTaskFilterRailKeys.allPill).selected, isTrue);
    expect(find.byKey(SavedTaskFilterRailKeys.pill('f1')), findsNothing);
    expect(find.byKey(SavedTaskFilterRailKeys.pill('f2')), findsNothing);
    expect(
      _leftOf(tester, SavedTaskFilterRailKeys.allPill),
      lessThan(_leftOf(tester, SavedTaskFilterRailKeys.savedButton)),
    );
  });

  testWidgets(
    'large text collapsed rail never overflows at 1.6x accessibility scale',
    (tester) async {
      // Regression: the old non-scrolling [Saved][All][anchor] row overflowed
      // by ~15px at 1.6x. The scrollable collapse must lay out cleanly.
      await _pumpRail(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
        mq: _xLargeTextMq,
      );

      // No RenderFlex overflow: the Expanded scroll area absorbs the slack that
      // the old non-scrolling [Saved][All][anchor] row could not.
      expect(tester.takeException(), isNull);

      final scroll = find.descendant(
        of: find.byKey(SavedTaskFilterRailKeys.root),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget);
      // The anchor leads inside the scroll area…
      expect(
        find.descendant(
          of: scroll,
          matching: find.byKey(SavedTaskFilterRailKeys.pill('f1')),
        ),
        findsOneWidget,
      );
      // …and the "Saved" button is PINNED outside it, sitting flush within the
      // rail's right edge (never pushed past it / clipped off), so the sheet
      // opener stays reachable instead of scrolling off into an "S" sliver.
      expect(
        find.descendant(
          of: scroll,
          matching: find.byKey(SavedTaskFilterRailKeys.savedButton),
        ),
        findsNothing,
      );
      final railRight = tester
          .getRect(find.byKey(SavedTaskFilterRailKeys.root))
          .right;
      final savedRight = tester
          .getRect(find.byKey(SavedTaskFilterRailKeys.savedButton))
          .right;
      expect(savedRight, lessThanOrEqualTo(railRight + 0.5));
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
}
