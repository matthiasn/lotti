import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/event_status_colors.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('EventStatusColors.colorForBrightness', () {
    test('uses the deeper task icon shades on a light surface', () {
      expect(
        {
          for (final status in EventStatus.values)
            status: status.colorForBrightness(Brightness.light),
        },
        {
          EventStatus.tentative: taskIconColorDarkGrey,
          EventStatus.planned: taskIconColorDarkBlue,
          EventStatus.ongoing: taskIconColorDarkOrange,
          EventStatus.completed: taskIconColorDarkGreen,
          EventStatus.cancelled: taskIconColorDarkRed,
          EventStatus.postponed: taskIconColorDarkOrange,
          EventStatus.rescheduled: taskIconColorDarkBlue,
          EventStatus.missed: taskIconColorDarkRed,
        },
      );
    });

    test('uses the muted task icon shades on a dark surface', () {
      expect(
        {
          for (final status in EventStatus.values)
            status: status.colorForBrightness(Brightness.dark),
        },
        {
          EventStatus.tentative: taskIconColorGrey,
          EventStatus.planned: taskIconColorBlue,
          EventStatus.ongoing: taskIconColorOrange,
          EventStatus.completed: taskIconColorGreen,
          EventStatus.cancelled: taskIconColorRed,
          EventStatus.postponed: taskIconColorOrange,
          EventStatus.rescheduled: taskIconColorBlue,
          EventStatus.missed: taskIconColorRed,
        },
      );
    });

    test('every status changes shade between light and dark', () {
      for (final status in EventStatus.values) {
        expect(
          status.colorForBrightness(Brightness.light),
          isNot(status.colorForBrightness(Brightness.dark)),
          reason: status.name,
        );
      }
    });

    test('every shade is fully opaque', () {
      for (final brightness in Brightness.values) {
        for (final status in EventStatus.values) {
          expect(
            status.colorForBrightness(brightness).a,
            1.0,
            reason: '${status.name} / ${brightness.name}',
          );
        }
      }
    });
  });
}
