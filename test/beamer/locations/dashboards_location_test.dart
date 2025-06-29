import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/dashboards_location.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboards_list_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('DashboardsLocation', () {
    late MockBuildContext mockBuildContext;

    setUp(() {
      mockBuildContext = MockBuildContext();
    });

    test('pathPatterns are correct', () {
      final location =
          DashboardsLocation(RouteInformation(uri: Uri.parse('/dashboards')));
      expect(
          location.pathPatterns, ['/dashboards', '/dashboards/:dashboardId']);
    });

    test('buildPages builds DashboardsListPage', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/dashboards'));
      final location = DashboardsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<DashboardsListPage>());
    });

    test('buildPages builds DashboardPage', () {
      final dashboardId = const Uuid().v4();
      final routeInformation =
          RouteInformation(uri: Uri.parse('/dashboards/$dashboardId'));
      final location = DashboardsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(
        routeInformation,
      );
      final newPathParameters =
          Map<String, String>.from(beamState.pathParameters);
      newPathParameters['dashboardId'] = dashboardId;
      final newBeamState = beamState.copyWith(
        pathParameters: newPathParameters,
      );
      final pages = location.buildPages(
        mockBuildContext,
        newBeamState,
      );
      expect(pages.length, 2);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<DashboardsListPage>());
      expect(pages[1].key, isA<ValueKey<String>>());
      expect(pages[1].child, isA<DashboardPage>());
      final dashboardPage = pages[1].child as DashboardPage;
      expect(dashboardPage.dashboardId, dashboardId);
    });
  });
}
