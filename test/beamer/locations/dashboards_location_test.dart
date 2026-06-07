import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/dashboards_location.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboard_page.dart';
import 'package:lotti/features/dashboards/ui/pages/dashboards_list_page.dart';
import 'package:lotti/features/insights/ui/time_analysis_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../mocks/mocks.dart';

void main() {
  group('DashboardsLocation', () {
    late MockBuildContext mockBuildContext;

    late MockNavService mockNavService;

    setUp(() {
      mockBuildContext = MockBuildContext();
      mockNavService = MockNavService();
      when(() => mockNavService.isDesktopMode).thenReturn(false);
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      getIt.registerSingleton<NavService>(mockNavService);
    });

    tearDown(() {
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
    });

    test('pathPatterns are correct', () {
      final location = DashboardsLocation(
        RouteInformation(uri: Uri.parse('/dashboards')),
      );
      expect(location.pathPatterns, [
        '/dashboards',
        '/dashboards/:dashboardId',
      ]);
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
      final routeInformation = RouteInformation(
        uri: Uri.parse('/dashboards/$dashboardId'),
      );
      final location = DashboardsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(
        routeInformation,
      );
      final newPathParameters = Map<String, String>.from(
        beamState.pathParameters,
      );
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

    test(
      'in desktop mode, buildPages returns only root page '
      'and does not push detail page',
      () {
        final dashboardId = const Uuid().v4();
        final desktopSelectedDashboardId = ValueNotifier<String?>(null);
        final desktopShowTimeAnalysis = ValueNotifier<bool>(false);

        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.desktopSelectedDashboardId,
        ).thenReturn(desktopSelectedDashboardId);
        when(
          () => mockNavService.desktopShowTimeAnalysis,
        ).thenReturn(desktopShowTimeAnalysis);

        final routeInformation = RouteInformation(
          uri: Uri.parse('/dashboards/$dashboardId'),
        );
        final location = DashboardsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final newBeamState = beamState.copyWith(
          pathParameters: {
            ...beamState.pathParameters,
            'dashboardId': dashboardId,
          },
        );

        final pages = location.buildPages(mockBuildContext, newBeamState);

        expect(pages.length, 1);
        expect(pages[0].child, isA<DashboardsListPage>());
      },
    );

    test(
      'in desktop mode, buildPages updates desktopSelectedDashboardId',
      () {
        final dashboardId = const Uuid().v4();
        final desktopSelectedDashboardId = ValueNotifier<String?>(null);
        final desktopShowTimeAnalysis = ValueNotifier<bool>(true);

        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.desktopSelectedDashboardId,
        ).thenReturn(desktopSelectedDashboardId);
        when(
          () => mockNavService.desktopShowTimeAnalysis,
        ).thenReturn(desktopShowTimeAnalysis);

        final routeInformation = RouteInformation(
          uri: Uri.parse('/dashboards/$dashboardId'),
        );
        final location = DashboardsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final newBeamState = beamState.copyWith(
          pathParameters: {
            ...beamState.pathParameters,
            'dashboardId': dashboardId,
          },
        );

        location.buildPages(mockBuildContext, newBeamState);

        expect(desktopSelectedDashboardId.value, dashboardId);
        // A dashboard selection always clears the time-analysis flag —
        // the URL is the single writer for the pane selection.
        expect(desktopShowTimeAnalysis.value, isFalse);
      },
    );

    test(
      'in desktop mode, /dashboards/time selects time analysis and clears '
      'any dashboard selection',
      () {
        final desktopSelectedDashboardId = ValueNotifier<String?>(
          const Uuid().v4(),
        );
        final desktopShowTimeAnalysis = ValueNotifier<bool>(false);

        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.desktopSelectedDashboardId,
        ).thenReturn(desktopSelectedDashboardId);
        when(
          () => mockNavService.desktopShowTimeAnalysis,
        ).thenReturn(desktopShowTimeAnalysis);

        final routeInformation = RouteInformation(
          uri: Uri.parse('/dashboards/time'),
        );
        final location = DashboardsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final newBeamState = beamState.copyWith(
          pathParameters: {...beamState.pathParameters, 'dashboardId': 'time'},
        );

        final pages = location.buildPages(mockBuildContext, newBeamState);

        expect(pages.length, 1);
        expect(desktopShowTimeAnalysis.value, isTrue);
        expect(desktopSelectedDashboardId.value, isNull);
      },
    );

    test('on mobile, /dashboards/time pushes the TimeAnalysisPage', () {
      when(() => mockNavService.isDesktopMode).thenReturn(false);

      final routeInformation = RouteInformation(
        uri: Uri.parse('/dashboards/time'),
      );
      final location = DashboardsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final newBeamState = beamState.copyWith(
        pathParameters: {...beamState.pathParameters, 'dashboardId': 'time'},
      );

      final pages = location.buildPages(mockBuildContext, newBeamState);

      expect(pages.length, 2);
      expect(pages[1].child, isA<TimeAnalysisPage>());
    });
  });
}
