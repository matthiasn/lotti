import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';

import '../../test_utils.dart';

void main() {
  group('EventCardData.isUpcoming', () {
    test('is true for planned and tentative', () {
      expect(
        buildEventCardData(status: EventStatus.planned).isUpcoming,
        isTrue,
      );
      expect(
        buildEventCardData(status: EventStatus.tentative).isUpcoming,
        isTrue,
      );
    });

    test('is false for completed/ongoing/cancelled/postponed', () {
      for (final status in [
        EventStatus.completed,
        EventStatus.ongoing,
        EventStatus.cancelled,
        EventStatus.postponed,
        EventStatus.rescheduled,
        EventStatus.missed,
      ]) {
        expect(
          buildEventCardData(status: status).isUpcoming,
          isFalse,
          reason: '$status should not be upcoming',
        );
      }
    });
  });

  test('EventSection defaults featured to false', () {
    const section = EventSection(title: '2026', events: []);
    expect(section.featured, isFalse);
    expect(
      const EventSection(
        title: 'Upcoming',
        events: [],
        featured: true,
      ).featured,
      isTrue,
    );
  });

  test('EventCategoryFilter with null id represents "All"', () {
    const all = EventCategoryFilter(id: null, label: 'All', color: eventPink);
    expect(all.id, isNull);
    expect(all.label, 'All');
  });

  test('EventPhoto defaults cropX to centre', () {
    expect(EventPhoto(testImage()).cropX, 0.5);
    expect(EventPhoto(testImage(), cropX: 0.2).cropX, 0.2);
  });
}
