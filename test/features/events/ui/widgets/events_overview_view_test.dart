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
  });
}
