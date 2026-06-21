import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_card.dart';
import 'package:lotti/features/events/ui/widgets/event_feature_card.dart';
import 'package:lotti/features/events/ui/widgets/events_overview_view.dart';

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

const _categories = <EventCategoryFilter>[
  EventCategoryFilter(id: null, label: 'All', color: eventPink),
  EventCategoryFilter(id: 'friends', label: 'Friends', color: eventPink),
  EventCategoryFilter(id: 'family', label: 'Family', color: eventBlue),
];

void main() {
  group('EventsOverviewView', () {
    testWidgets('renders title, subtitle, search bar and create button', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventsOverviewView(
          sections: _sections(),
          subtitle: '47 events',
          categories: _categories,
          onCreate: () {},
          onSearch: () {},
        ),
        size: _desktop,
      );

      expect(find.text('Events'), findsOneWidget);
      expect(find.text('47 events'), findsOneWidget);
      expect(find.text('Search events'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'New event'), findsOneWidget);
    });

    testWidgets('renders section headers, featured banner and grid cards', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventsOverviewView(sections: _sections(), categories: _categories),
        size: _desktop,
      );

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.byType(EventFeatureCard), findsOneWidget);
      // The two non-featured 2026 events render as grid cards.
      expect(find.byType(EventCard), findsNWidgets(2));
      expect(find.text('Team Offsite'), findsOneWidget);
    });

    testWidgets('omits the chip row and subtitle when not provided', (
      tester,
    ) async {
      await pumpEventScreen(
        tester,
        EventsOverviewView(sections: _sections()),
        size: _desktop,
      );
      expect(find.text('All'), findsNothing);
      expect(find.text('47 events'), findsNothing);
    });

    testWidgets('invokes onOpenEvent with the tapped event', (tester) async {
      EventCardData? opened;
      await pumpEventScreen(
        tester,
        EventsOverviewView(
          sections: _sections(),
          categories: _categories,
          onOpenEvent: (e) => opened = e,
        ),
        size: _desktop,
      );
      await tester.tap(find.text('Team Offsite'));
      expect(opened?.id, 'e2');
    });

    testWidgets('invokes onSelectCategory with the chip id', (tester) async {
      String? selected = 'none';
      await pumpEventScreen(
        tester,
        EventsOverviewView(
          sections: _sections(),
          categories: _categories,
          onSelectCategory: (id) => selected = id,
        ),
        size: _desktop,
      );
      await tester.tap(find.text('Family'));
      expect(selected, 'family');
    });

    testWidgets('invokes onCreate and onSearch', (tester) async {
      var created = false;
      var searched = false;
      await pumpEventScreen(
        tester,
        EventsOverviewView(
          sections: _sections(),
          categories: _categories,
          onCreate: () => created = true,
          onSearch: () => searched = true,
        ),
        size: _desktop,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'New event'));
      await tester.tap(find.text('Search events'));
      expect(created, isTrue);
      expect(searched, isTrue);
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
