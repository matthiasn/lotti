import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/calendar_location.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('CalendarLocation.buildPages', () {
    late _MockBuildContext mockBuildContext;

    setUp(() {
      mockBuildContext = _MockBuildContext();
    });

    test('exposes the calendar path patterns', () {
      final location = CalendarLocation(
        RouteInformation(uri: Uri.parse('/calendar')),
      );
      expect(location.pathPatterns, [
        '/calendar',
        '/calendar/set-time-blocks',
      ]);
    });

    test('builds a single CalendarRoot page for /calendar', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/calendar'));
      final location = CalendarLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(mockBuildContext, beamState);
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      // The child branches between the current and next-gen Daily OS
      // surfaces at runtime — see [CalendarRoot] for the flag wiring.
      // Widget-level branching is covered separately in the
      // CalendarRoot widget test.
      expect(pages[0].child, isA<CalendarRoot>());
    });

    test('pushes the set-time-blocks page on the nested route', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/calendar/set-time-blocks'),
      );
      final location = CalendarLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(mockBuildContext, beamState);
      expect(pages.length, 2);
      expect(pages[0].child, isA<CalendarRoot>());
    });
  });
}
