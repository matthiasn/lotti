import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_card.dart';
import 'package:lotti/features/events/ui/widgets/event_feature_card.dart';
import 'package:lotti/features/events/ui/widgets/events_overview_view.dart';
import 'package:material_ui/material_ui.dart';

import '../../test_utils.dart';

const _desktop = Size(1280, 900);

List<EventSection> _sections() => [
  EventSection(
    title: 'Upcoming',
    featured: true,
    events: [
      buildEventCardData(
        id: 'u1',
        title: 'Marathon 2026',
        status: EventStatus.planned,
        stars: 0,
        photoCount: 0,
        coverImage: testImage(),
        summary: 'Goal: sub-4:00.',
        location: 'Berlin',
      ),
    ],
  ),
  EventSection(
    title: '2026',
    events: [
      buildEventCardData(
        id: 'e2',
        title: 'Team Offsite',
        coverImage: testImage(),
      ),
      buildEventCardData(
        id: 'e3',
        title: 'The Wedding',
        coverImage: testImage(),
      ),
    ],
  ),
];

const _friends = EventCategoryFilter(
  id: 'friends',
  label: 'Friends',
  color: eventPink,
);
const _family = EventCategoryFilter(
  id: 'family',
  label: 'Family',
  color: eventBlue,
);

bool _funnelActive(WidgetTester tester) =>
    tester.widget<TabHeaderIconButton>(find.byType(TabHeaderIconButton)).active;

void main() {
  group('EventsOverviewView', () {
    testWidgets('uses the shared tab header with a resting filter funnel', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventsOverviewView(sections: _sections()),
        size: _desktop,
      );

      expect(find.byType(TabSectionHeader), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Search events'), findsOneWidget);
      expect(_funnelActive(tester), isFalse);
      expect(find.byType(ActiveFilterChip), findsNothing);
    });

    testWidgets('typing reports every edit, clearing reports empty', (
      tester,
    ) async {
      final queries = <String>[];
      await pumpEventScreen(
        tester,
        EventsOverviewView(sections: _sections(), onQueryChanged: queries.add),
        size: _desktop,
      );

      await tester.enterText(find.byType(TextField), 'gala');
      await tester.pump();
      await tester.tap(find.byIcon(LottiIcons.closeCircled));
      await tester.pump();

      // The field reports the clear as an edit to '' as well as a clear;
      // both land on the same empty query.
      expect(queries.first, 'gala');
      expect(queries.skip(1), everyElement(isEmpty));
      expect(queries.length, greaterThan(1));
    });

    testWidgets('the search glyph submits the typed query', (tester) async {
      final queries = <String>[];
      await pumpEventScreen(
        tester,
        EventsOverviewView(sections: _sections(), onQueryChanged: queries.add),
        size: _desktop,
      );
      await tester.enterText(find.byType(TextField), 'gala');
      queries.clear();

      await tester.tap(find.byIcon(LottiIcons.search));
      await tester.pump();

      expect(queries, ['gala']);
    });

    testWidgets('seeds the search field with the current query', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventsOverviewView(sections: _sections(), query: 'wedding'),
        size: _desktop,
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'wedding',
      );
    });

    testWidgets('the funnel opens the filter', (tester) async {
      var opened = 0;
      await pumpEventScreen(
        tester,
        EventsOverviewView(
          sections: _sections(),
          onFilterPressed: () => opened++,
        ),
        size: _desktop,
      );

      await tester.tap(find.byType(TabHeaderIconButton));

      expect(opened, 1);
    });

    testWidgets(
      'active categories tint the funnel and render removable chips',
      (tester) async {
        final removed = <String>[];
        await pumpEventScreen(
          tester,
          EventsOverviewView(
            sections: _sections(),
            activeCategories: const [_family],
            onRemoveCategory: removed.add,
            onClearFilters: () {},
          ),
          size: _desktop,
        );

        expect(_funnelActive(tester), isTrue);
        final chip = tester.widget<ActiveFilterChip>(
          find.byType(ActiveFilterChip),
        );
        expect(chip.label, 'Family');
        // The chip wears the category's own colour, as its cards do.
        expect(chip.accentColor, eventBlue);
        // A single narrowing is ended by its own chip — no "Clear all".
        expect(find.text('Clear all'), findsNothing);

        await tester.tap(find.text('Family'));

        expect(removed, ['family']);
      },
    );

    testWidgets('offers "Clear all" from two categories', (tester) async {
      var cleared = 0;
      await pumpEventScreen(
        tester,
        EventsOverviewView(
          sections: _sections(),
          activeCategories: const [_friends, _family],
          onClearFilters: () => cleared++,
        ),
        size: _desktop,
      );

      expect(find.byType(ActiveFilterChip), findsNWidgets(2));
      await tester.tap(find.text('Clear all'));

      expect(cleared, 1);
    });

    testWidgets('a query counts toward "Clear all"', (tester) async {
      await pumpEventScreen(
        tester,
        EventsOverviewView(
          sections: _sections(),
          query: 'gala',
          activeCategories: const [_family],
          onClearFilters: () {},
        ),
        size: _desktop,
      );

      expect(find.text('Clear all'), findsOneWidget);
    });

    testWidgets('a filter matching nothing offers to clear it', (
      tester,
    ) async {
      var cleared = 0;
      await pumpEventScreen(
        tester,
        EventsOverviewView(
          sections: const [],
          query: 'nothing like this',
          onClearFilters: () => cleared++,
        ),
        size: _desktop,
      );

      expect(find.text('No matching events'), findsOneWidget);
      await tester.tap(find.text('Clear all'));

      expect(cleared, 1);
    });

    testWidgets('an empty archive without a filter shows no "no match" state', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        const EventsOverviewView(sections: []),
        size: _desktop,
      );

      expect(find.text('No matching events'), findsNothing);
    });

    testWidgets('creates from the floating action button', (tester) async {
      var created = 0;
      await pumpEventScreen(
        tester,
        EventsOverviewView(sections: _sections(), onCreate: () => created++),
        size: _desktop,
      );

      await tester.tap(find.byType(DesignSystemFloatingActionButton));

      expect(created, 1);
    });

    testWidgets('floats no create button without a create action', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventsOverviewView(sections: _sections()),
        size: _desktop,
      );

      expect(find.byType(DesignSystemFloatingActionButton), findsNothing);
    });

    testWidgets(
      'header and grid share one capped content column on desktop',
      (tester) async {
        const wide = Size(1600, 900);
        await pumpEventScreen(
          tester,
          EventsOverviewView(sections: _sections()),
          size: wide,
        );

        final title = tester.getRect(find.text('Events'));
        final search = tester.getRect(find.byType(TextField));
        final firstCard = tester.getRect(find.byType(EventCard).first);
        final lastCard = tester.getRect(find.byType(EventCard).last);
        // One left edge for the title, the search field and the cards.
        expect(firstCard.left, title.left);
        expect(search.left, greaterThanOrEqualTo(title.left));
        // The column is capped and centred rather than spanning the window.
        expect(
          lastCard.right - firstCard.left,
          lessThan(kDetailContentMaxWidth),
        );
        expect(
          firstCard.left,
          greaterThan((wide.width - kDetailContentMaxWidth) / 2),
        );
      },
    );

    testWidgets('renders section headers, featured banner and grid cards', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventsOverviewView(sections: _sections()),
        size: _desktop,
      );

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.byType(EventFeatureCard), findsOneWidget);
      // The two non-featured 2026 events render as grid cards.
      expect(find.byType(EventCard), findsNWidgets(2));
      expect(find.text('Team Offsite'), findsOneWidget);
    });

    testWidgets('invokes onOpenEvent with the tapped event', (tester) async {
      EventCardData? opened;
      await pumpEventScreen(
        tester,
        EventsOverviewView(
          sections: _sections(),
          onOpenEvent: (e) => opened = e,
        ),
        size: _desktop,
      );
      await tester.tap(find.text('Team Offsite'));
      expect(opened?.id, 'e2');
    });

    testWidgets(
      'builds grid cards lazily so a large event set does not mount them all',
      (tester) async {
        // The overview can hold hundreds of events. Eager rendering would build
        // every card and fire every full-resolution cover decode at once, which
        // OOM-kills the app on phones. The grid must build lazily.
        final manyEvents = [
          for (var i = 0; i < 200; i++)
            buildEventCardData(
              id: 'e$i',
              title: 'Event $i',
              coverImage: testImage(),
            ),
        ];
        // pumpEventScreen defaults to a 390x844 phone viewport.
        await pumpEventScreen(
          tester,
          EventsOverviewView(
            sections: [EventSection(title: '2026', events: manyEvents)],
          ),
        );

        // Only a viewport's worth (plus the sliver cache) is instantiated — far
        // fewer than the 200 events. Eager rendering would build all 200.
        final built = find.byType(EventCard).evaluate().length;
        expect(built, greaterThan(0));
        expect(built, lessThan(50));
      },
    );

    testWidgets('fires onLoadMore when scrolled near the bottom', (
      tester,
    ) async {
      var loadMoreCalls = 0;
      final events = [
        for (var i = 0; i < 12; i++)
          buildEventCardData(
            id: 'e$i',
            title: 'Event $i',
            coverImage: testImage(),
          ),
      ];
      await pumpEventScreen(
        tester,
        EventsOverviewView(
          sections: [EventSection(title: '2026', events: events)],
          onLoadMore: () => loadMoreCalls++,
        ),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pump();

      expect(loadMoreCalls, greaterThan(0));
    });

    testWidgets('shows a trailing progress indicator while loading more', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventsOverviewView(
          sections: [
            EventSection(
              title: '2026',
              events: [buildEventCardData(coverImage: testImage())],
            ),
          ],
          onLoadMore: () {},
          isLoadingMore: true,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
