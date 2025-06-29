import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/calendar_location.dart';
import 'package:lotti/features/calendar/ui/pages/day_view_page.dart';
import 'package:mocktail/mocktail.dart';

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('CalendarLocation', () {
    late MockBuildContext mockBuildContext;

    setUp(() {
      mockBuildContext = MockBuildContext();
    });

    test('pathPatterns are correct', () {
      final location =
          CalendarLocation(RouteInformation(uri: Uri.parse('/calendar')));
      expect(location.pathPatterns, ['/calendar']);
    });

    test('buildPages builds DayViewPage with default values', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/calendar'));
      final location = CalendarLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<DayViewPage>());
      final dayViewPage = pages[0].child as DayViewPage;
      expect(dayViewPage.initialDayYmd, 'null');
      expect(dayViewPage.timeSpanDays, 30);
    });

    test('buildPages builds DayViewPage with provided values', () {
      final routeInformation = RouteInformation(
          uri: Uri.parse('/calendar?ymd=2023-01-01&timeSpanDays=7'));
      final location = CalendarLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<DayViewPage>());
      final dayViewPage = pages[0].child as DayViewPage;
      expect(dayViewPage.initialDayYmd, '2023-01-01');
      expect(dayViewPage.timeSpanDays, 7);
    });
  });
}
