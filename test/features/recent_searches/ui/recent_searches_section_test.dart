import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/ui/recent_searches_section.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

const _fish = RecentSearch(
  surface: RecentSearchSurface.tasks,
  query: 'fish feeder',
);
const _run = RecentSearch(surface: RecentSearchSurface.habits, query: 'run');
const _waddle = RecentSearch(
  surface: RecentSearchSurface.projects,
  query: 'Project Waddle launch review and every follow-up it spawned',
);

const Map<RecentSearchSurface, RecentSearchSurfacePresentation> _surfaces = {
  RecentSearchSurface.tasks: RecentSearchSurfacePresentation(
    label: 'Tasks',
    icon: Icon(LottiIcons.list),
  ),
  RecentSearchSurface.habits: RecentSearchSurfacePresentation(
    label: 'Habits',
    icon: Icon(LottiIcons.checkAll),
  ),
  RecentSearchSurface.projects: RecentSearchSurfacePresentation(
    label: 'Projects',
    icon: Icon(LottiIcons.folder),
  ),
};

Future<FakeRecentSearchesController> _pump(
  WidgetTester tester, {
  required List<RecentSearch> searches,
  Map<RecentSearchSurface, RecentSearchSurfacePresentation> surfaces =
      _surfaces,
  ValueChanged<RecentSearch>? onSelected,
}) async {
  final controller = FakeRecentSearchesController(searches);
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(
        width: 280,
        child: RecentSearchesSection(
          surfaces: surfaces,
          onSelected: onSelected ?? (_) {},
        ),
      ),
      overrides: [fakeRecentSearches(controller)],
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  group('RecentSearchesSection', () {
    testWidgets('lists the searches newest first under the Recents heading', (
      tester,
    ) async {
      await _pump(tester, searches: const [_run, _fish]);

      expect(find.text('Recents'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('run')).dy,
        lessThan(tester.getTopLeft(find.text('fish feeder')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Recents')).dy,
        lessThan(tester.getTopLeft(find.text('run')).dy),
      );
    });

    testWidgets("marks each row with its destination's glyph, sized and "
        'tinted by the row', (tester) async {
      await _pump(tester, searches: const [_run, _fish]);

      Finder glyphOf(RecentSearch search) => find.descendant(
        of: find.byKey(RecentSearchesSectionKeys.row(search)),
        matching: find.byType(Icon),
      );

      expect(tester.widget<Icon>(glyphOf(_run)).icon, LottiIcons.checkAll);
      expect(tester.widget<Icon>(glyphOf(_fish)).icon, LottiIcons.list);

      final context = tester.element(glyphOf(_fish));
      final theme = IconTheme.of(context);
      expect(theme.size, IconSizes.m);
      expect(theme.color, context.designTokens.colors.text.lowEmphasis);
    });

    testWidgets('renders nothing at all when there is nothing to list', (
      tester,
    ) async {
      await _pump(tester, searches: const []);

      expect(find.text('Recents'), findsNothing);
      expect(find.byKey(RecentSearchesSectionKeys.clear), findsNothing);
      // No height at all: the host's spacing above the section is the only
      // trace it may leave in the rail.
      expect(tester.getSize(find.byType(RecentSearchesSection)).height, 0);
    });

    testWidgets('hides a search whose destination is not offered', (
      tester,
    ) async {
      await _pump(
        tester,
        searches: const [_run, _fish],
        surfaces: {
          RecentSearchSurface.tasks: _surfaces[RecentSearchSurface.tasks]!,
        },
      );

      expect(find.text('fish feeder'), findsOneWidget);
      expect(find.text('run'), findsNothing);
    });

    testWidgets('keeps Clear reachable when every remembered search is on a '
        'hidden destination', (tester) async {
      final controller = await _pump(
        tester,
        searches: const [_run],
        surfaces: {
          RecentSearchSurface.tasks: _surfaces[RecentSearchSurface.tasks]!,
        },
      );

      // No row leads anywhere, but the history is still on the device, so
      // the way to delete it stays on screen.
      expect(find.text('run'), findsNothing);
      expect(find.text('Recents'), findsOneWidget);

      await tester.tap(find.byKey(RecentSearchesSectionKeys.clear));
      await tester.pump();

      expect(controller.clearCalls, 1);
      expect(find.text('Recents'), findsNothing);
    });

    testWidgets('tapping a row hands that search to the host', (tester) async {
      final selected = <RecentSearch>[];
      await _pump(
        tester,
        searches: const [_run, _fish],
        onSelected: selected.add,
      );

      await tester.tap(find.text('fish feeder'));
      await tester.pump();

      expect(selected, [_fish]);
    });

    testWidgets('Clear forgets the list and takes the section with it', (
      tester,
    ) async {
      final controller = await _pump(tester, searches: const [_run, _fish]);

      await tester.tap(find.byKey(RecentSearchesSectionKeys.clear));
      await tester.pump();

      expect(controller.clearCalls, 1);
      expect(find.text('Recents'), findsNothing);
      expect(find.text('run'), findsNothing);
    });

    testWidgets('every row is a full touch target', (tester) async {
      await _pump(tester, searches: const [_run, _fish]);

      for (final search in const [_run, _fish]) {
        expect(
          tester
              .getSize(find.byKey(RecentSearchesSectionKeys.row(search)))
              .height,
          greaterThanOrEqualTo(TapTargets.minimum),
          reason: '$search',
        );
      }
    });

    testWidgets('a long query stays on one ellipsized line inside the rail', (
      tester,
    ) async {
      await _pump(tester, searches: const [_waddle, _run]);

      final long = tester.widget<Text>(find.text(_waddle.query));
      expect(long.maxLines, 1);
      expect(long.overflow, TextOverflow.ellipsis);
      // Same row height as a short query: the text did not wrap.
      expect(
        tester
            .getSize(find.byKey(RecentSearchesSectionKeys.row(_waddle)))
            .height,
        tester.getSize(find.byKey(RecentSearchesSectionKeys.row(_run))).height,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('names the destination and the query for assistive tech', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await _pump(tester, searches: const [_fish]);

        expect(
          tester.getSemantics(find.byKey(RecentSearchesSectionKeys.row(_fish))),
          matchesSemantics(
            label: 'Search Tasks for fish feeder',
            isButton: true,
            hasTapAction: true,
            hasFocusAction: true,
            isFocusable: true,
          ),
        );
        expect(
          find.bySemanticsLabel('Clear recent searches'),
          findsOneWidget,
        );
        final heading = tester.getSemantics(find.text('Recents'));
        expect(heading.flagsCollection.isHeader, isTrue);
      } finally {
        handle.dispose();
      }
    });
  });
}
