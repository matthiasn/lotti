import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show Glados2, IntAnys, any;
import 'package:lotti/features/tasks/ui/widgets/collapsing_task_list_header.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('TaskListHeaderCollapseController', () {
    late TaskListHeaderCollapseController controller;
    late int notifications;

    setUp(() {
      controller = TaskListHeaderCollapseController();
      notifications = 0;
      controller.addListener(() => notifications++);
    });

    tearDown(() => controller.dispose());

    /// Establishes a top-of-list baseline frame, then moves down to [pixels].
    void scrollDownTo(double pixels, {double maxScrollExtent = 1000}) {
      controller
        ..handleScroll(pixels: 0, maxScrollExtent: maxScrollExtent)
        ..handleScroll(pixels: pixels, maxScrollExtent: maxScrollExtent);
    }

    test('collapses on downward movement past the activation offset', () {
      scrollDownTo(200);
      expect(controller.collapsed, isTrue);
      expect(notifications, 1);
    });

    test('stays expanded below the activation offset', () {
      scrollDownTo(TaskListHeaderCollapseController.collapseActivationOffset);
      expect(controller.collapsed, isFalse);
      expect(notifications, 0);
    });

    test('stays expanded when the list is too short to collapse safely', () {
      scrollDownTo(
        200,
        maxScrollExtent:
            TaskListHeaderCollapseController.minCollapsibleExtent - 1,
      );
      expect(controller.collapsed, isFalse);
    });

    test('expands after a deliberate upward scroll', () {
      scrollDownTo(200);
      controller.handleScroll(
        pixels: 200 - TaskListHeaderCollapseController.expandUpwardTravel,
        maxScrollExtent: 1000,
      );
      expect(controller.collapsed, isFalse);
      expect(notifications, 2);
    });

    test('an upward jiggle below the travel threshold stays collapsed', () {
      scrollDownTo(200);
      controller.handleScroll(pixels: 195, maxScrollExtent: 1000);
      expect(controller.collapsed, isTrue);
    });

    test('a downward frame resets accumulated upward travel', () {
      scrollDownTo(300);
      // 20px up (below threshold), down again, then 20px up: neither upward
      // burst alone crosses the threshold, and they must not sum.
      controller
        ..handleScroll(pixels: 280, maxScrollExtent: 1000)
        ..handleScroll(pixels: 320, maxScrollExtent: 1000)
        ..handleScroll(pixels: 300, maxScrollExtent: 1000);
      expect(controller.collapsed, isTrue);
    });

    test('upward travel accumulates across small frames', () {
      scrollDownTo(300);
      // Three 10px frames: no single frame crosses 24, the run does.
      controller
        ..handleScroll(pixels: 290, maxScrollExtent: 1000)
        ..handleScroll(pixels: 280, maxScrollExtent: 1000)
        ..handleScroll(pixels: 270, maxScrollExtent: 1000);
      expect(controller.collapsed, isFalse);
    });

    test('expands when the viewport returns to the top', () {
      scrollDownTo(200);
      controller.handleScroll(
        pixels: TaskListHeaderCollapseController.expandNearTopOffset,
        maxScrollExtent: 1000,
      );
      expect(controller.collapsed, isFalse);
    });

    test('a bottom overscroll bounce cannot masquerade as an upward '
        'scroll', () {
      scrollDownTo(990);
      expect(controller.collapsed, isTrue);
      // Fling past the end (overscroll) and settle back: both frames touch
      // the overscroll zone, so neither may count as upward travel.
      controller
        ..handleScroll(pixels: 1050, maxScrollExtent: 1000)
        ..handleScroll(pixels: 1000, maxScrollExtent: 1000);
      expect(controller.collapsed, isTrue);

      // A genuine upward scroll from inside the range still expands.
      controller.handleScroll(pixels: 960, maxScrollExtent: 1000);
      expect(controller.collapsed, isFalse);
    });

    test('search focus expands but does NOT pin the header', () {
      scrollDownTo(200);
      controller.setSearchFocused(focused: true);
      expect(controller.collapsed, isFalse);

      // Desktop keeps a clicked field focused indefinitely; a later scroll
      // must still collapse (the page releases the focus alongside).
      controller
        ..handleScroll(pixels: 250, maxScrollExtent: 1000)
        ..handleScroll(pixels: 320, maxScrollExtent: 1000);
      expect(controller.collapsed, isTrue);
    });

    test('re-expands itself when content shrinks below scrollability', () {
      scrollDownTo(200);
      controller.handleContentDimensionsChanged(maxScrollExtent: 0);
      expect(controller.collapsed, isFalse);
    });

    test(
      'content-dimension changes leave a scrollable collapsed list alone',
      () {
        scrollDownTo(200);
        controller.handleContentDimensionsChanged(maxScrollExtent: 400);
        expect(controller.collapsed, isTrue);
      },
    );

    test('expand() collapsed -> expanded notifies exactly once', () {
      scrollDownTo(200);
      controller
        ..expand()
        ..expand();
      expect(controller.collapsed, isFalse);
      expect(notifications, 2);
    });

    test('repeated downward frames notify only on the first transition', () {
      scrollDownTo(200);
      controller
        ..handleScroll(pixels: 400, maxScrollExtent: 1000)
        ..handleScroll(pixels: 600, maxScrollExtent: 1000);
      expect(notifications, 1);
    });

    // Invariant: whatever offset the collapse happened at, a sustained upward
    // scroll (further than the travel threshold) always restores the header —
    // the user can never be trapped collapsed.
    Glados2(any.intInRange(100, 1900), any.intInRange(300, 2000)).test(
      'a sustained upward scroll always expands, regardless of prior state',
      (pixels, maxScrollExtent) {
        final extent = maxScrollExtent.toDouble();
        final start = pixels.toDouble().clamp(100.0, extent);
        final c = TaskListHeaderCollapseController()
          ..handleScroll(pixels: 0, maxScrollExtent: extent)
          ..handleScroll(pixels: start, maxScrollExtent: extent)
          ..handleScroll(
            pixels: start - TaskListHeaderCollapseController.expandUpwardTravel,
            maxScrollExtent: extent,
          );
        expect(c.collapsed, isFalse);
        c.dispose();
      },
      tags: 'glados',
    );

    // Invariant: a list that cannot fund a post-collapse scroll never
    // collapses — otherwise no gesture could bring the header back.
    Glados2(any.intInRange(0, 2000), any.intInRange(0, 240)).test(
      'short lists never collapse on downward scrolls',
      (pixels, maxScrollExtent) {
        final shortExtent = maxScrollExtent
            .toDouble()
            .clamp(0, TaskListHeaderCollapseController.minCollapsibleExtent - 1)
            .toDouble();
        final c = TaskListHeaderCollapseController()
          ..handleScroll(pixels: 0, maxScrollExtent: shortExtent)
          ..handleScroll(
            pixels: pixels.toDouble(),
            maxScrollExtent: shortExtent,
          );
        expect(c.collapsed, isFalse);
        c.dispose();
      },
      tags: 'glados',
    );
  });

  group('CollapsingTaskListHeader', () {
    Widget subject({required bool collapsed, bool reduceMotion = false}) {
      return makeTestableWidgetNoScroll(
        Scaffold(
          body: Column(
            children: [
              CollapsingTaskListHeader(
                collapsed: collapsed,
                reduceMotion: reduceMotion,
                expandedHeader: const SizedBox(
                  height: 200,
                  child: Text('expanded header'),
                ),
                compactBar: const SizedBox(
                  height: 48,
                  child: Text('compact bar'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('shows the expanded header while not collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(subject(collapsed: false));
      await tester.pumpAndSettle();

      final crossFade = tester.widget<AnimatedCrossFade>(
        find.byKey(CollapsingTaskListHeaderKeys.root),
      );
      expect(crossFade.crossFadeState, CrossFadeState.showFirst);
      // The settled header occupies its full expanded height.
      expect(
        tester.getSize(find.byKey(CollapsingTaskListHeaderKeys.root)).height,
        200,
      );
    });

    testWidgets('collapsing animates the height down to the compact bar', (
      tester,
    ) async {
      await tester.pumpWidget(subject(collapsed: false));
      await tester.pumpAndSettle();

      await tester.pumpWidget(subject(collapsed: true));
      // Mid-animation the height sits strictly between the two extremes —
      // the reflow is a tween, not a jump.
      await tester.pump(const Duration(milliseconds: 125));
      final midHeight = tester
          .getSize(find.byKey(CollapsingTaskListHeaderKeys.root))
          .height;
      expect(midHeight, lessThan(200));
      expect(midHeight, greaterThan(48));

      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(CollapsingTaskListHeaderKeys.root)).height,
        48,
      );
      // Both children stay mounted, so typed search input survives collapse.
      expect(find.text('expanded header'), findsOneWidget);
      expect(find.text('compact bar'), findsOneWidget);
    });

    testWidgets('reduced motion swaps instantly without a tween', (
      tester,
    ) async {
      await tester.pumpWidget(subject(collapsed: false, reduceMotion: true));
      await tester.pump();
      await tester.pumpWidget(subject(collapsed: true, reduceMotion: true));
      await tester.pump();

      expect(
        tester.getSize(find.byKey(CollapsingTaskListHeaderKeys.root)).height,
        48,
      );
    });

    testWidgets('both header states share one seat hairline on the wrapper', (
      tester,
    ) async {
      await tester.pumpWidget(subject(collapsed: false));
      await tester.pumpAndSettle();

      final decorated = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byKey(CollapsingTaskListHeaderKeys.root),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final border = (decorated.decoration as BoxDecoration).border! as Border;
      expect(border.bottom, isNot(BorderSide.none));
    });

    testWidgets('the hidden expanded header is excluded from semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(subject(collapsed: true));
      await tester.pumpAndSettle();

      // Screen readers must only ever reach one header representation.
      expect(
        find.bySemanticsLabel('expanded header'),
        findsNothing,
      );
      expect(find.bySemanticsLabel('compact bar'), findsOneWidget);
      handle.dispose();
    });
  });

  group('TaskListCompactHeaderBar', () {
    late int expandRequests;
    late int searchRequests;
    late int filterRequests;

    setUp(() {
      expandRequests = 0;
      searchRequests = 0;
      filterRequests = 0;
    });

    Widget subject({
      bool filtersActive = false,
      bool searchActive = false,
      int activeFilterCount = 0,
      String? contextLabel,
    }) {
      return makeTestableWidgetNoScroll(
        Scaffold(
          body: TaskListCompactHeaderBar(
            title: 'Tasks',
            searchTooltip: 'Search tasks…',
            filterTooltip: 'Filter tasks',
            expandSemanticHint: 'Show search and filters',
            filtersActive: filtersActive,
            activeFilterCount: activeFilterCount,
            searchActive: searchActive,
            contextLabel: contextLabel,
            onExpandRequested: () => expandRequests++,
            onSearchRequested: () => searchRequests++,
            onFilterPressed: () => filterRequests++,
          ),
        ),
      );
    }

    IconButton buttonOf(WidgetTester tester, Key key) =>
        tester.widget<IconButton>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(IconButton),
          ),
        );

    testWidgets('title tap requests expansion', (tester) async {
      await tester.pumpWidget(subject());
      await tester.tap(find.byKey(CollapsingTaskListHeaderKeys.compactTitle));
      expect(expandRequests, 1);
      expect(searchRequests, 0);
    });

    testWidgets('search button requests expand-and-focus', (tester) async {
      await tester.pumpWidget(subject());
      await tester.tap(
        find.byKey(CollapsingTaskListHeaderKeys.compactSearchButton),
      );
      expect(searchRequests, 1);
    });

    testWidgets('filter button opens filters without expanding', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.tap(
        find.byKey(CollapsingTaskListHeaderKeys.compactFilterButton),
      );
      expect(filterRequests, 1);
      expect(expandRequests, 0);
    });

    testWidgets('icons stay neutral when nothing narrows the list', (
      tester,
    ) async {
      await tester.pumpWidget(subject());

      expect(
        buttonOf(
          tester,
          CollapsingTaskListHeaderKeys.compactFilterButton,
        ).style,
        isNull,
      );
      expect(
        buttonOf(
          tester,
          CollapsingTaskListHeaderKeys.compactSearchButton,
        ).style,
        isNull,
      );
      // No clauses -> no badge.
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets(
      'active filters and search carry the activated fill so a narrowed '
      'list is never invisible while collapsed',
      (tester) async {
        await tester.pumpWidget(
          subject(filtersActive: true, searchActive: true),
        );

        expect(
          buttonOf(
            tester,
            CollapsingTaskListHeaderKeys.compactFilterButton,
          ).style?.backgroundColor,
          isNotNull,
        );
        expect(
          buttonOf(
            tester,
            CollapsingTaskListHeaderKeys.compactSearchButton,
          ).style?.backgroundColor,
          isNotNull,
        );
      },
    );

    testWidgets(
      'the filter button carries the active-clause count so magnitude '
      'survives the collapse',
      (tester) async {
        await tester.pumpWidget(
          subject(filtersActive: true, activeFilterCount: 4),
        );

        expect(
          find.descendant(
            of: find.byKey(CollapsingTaskListHeaderKeys.compactFilterButton),
            matching: find.text('4'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('the compact bar sits on a one-step raised surface', (
      tester,
    ) async {
      await tester.pumpWidget(subject());

      final colored = tester.widget<ColoredBox>(
        find
            .ancestor(
              of: find.byKey(CollapsingTaskListHeaderKeys.compactBar),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(colored.color, isNot(Colors.transparent));
    });

    testWidgets('renders the context label (saved view / query) after the '
        'title', (tester) async {
      await tester.pumpWidget(subject(contextLabel: 'Errands'));

      expect(
        find.textContaining('Errands', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('tapping beside the title label still expands (full-width '
        'tap area, bounded ink)', (tester) async {
      await tester.pumpWidget(subject());

      final area = tester.getRect(
        find.byKey(CollapsingTaskListHeaderKeys.compactTitleTapArea),
      );
      // Tap far to the right of the label text, inside the leading region.
      await tester.tapAt(Offset(area.right - 8, area.center.dy));
      expect(expandRequests, 1);
    });

    testWidgets('all tap targets meet the 44pt minimum', (tester) async {
      await tester.pumpWidget(subject());

      for (final key in [
        CollapsingTaskListHeaderKeys.compactTitleTapArea,
        CollapsingTaskListHeaderKeys.compactSearchButton,
        CollapsingTaskListHeaderKeys.compactFilterButton,
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
      }
    });

    testWidgets('exposes buttons and tooltips to assistive tech', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(subject());

      expect(find.bySemanticsLabel('Tasks'), findsOneWidget);
      // IconButton tooltips surface to assistive tech as semantic tooltips.
      expect(find.byTooltip('Search tasks…'), findsOneWidget);
      expect(find.byTooltip('Filter tasks'), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
      'the title button carries a TAP ACTION, not just a hint — the inner '
      'targets are excluded from semantics, so a screen reader can only '
      'expand the header through this node',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(subject());
        final before = expandRequests;

        expect(
          tester.getSemantics(find.bySemanticsLabel('Tasks')),
          matchesSemantics(
            label: 'Tasks',
            hint: 'Show search and filters',
            isButton: true,
            hasTapAction: true,
          ),
        );

        await tester.tap(find.bySemanticsLabel('Tasks'));
        await tester.pump();

        expect(expandRequests, before + 1);
        handle.dispose();
      },
    );
  });
}
