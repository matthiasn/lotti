import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/projects_location.dart';
import 'package:lotti/features/projects/ui/pages/project_create_page.dart';
import 'package:lotti/features/projects/ui/pages/project_details_page.dart';
import 'package:lotti/features/projects/ui/pages/projects_tab_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

class _MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('ProjectsLocation', () {
    late _MockBuildContext mockBuildContext;

    late MockNavService mockNavService;

    setUp(() {
      mockBuildContext = _MockBuildContext();
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
      final location = ProjectsLocation(
        RouteInformation(uri: Uri.parse('/projects')),
      );

      expect(location.pathPatterns, [
        '/projects',
        '/projects/create',
        '/projects/:projectId',
      ]);
    });

    test('buildPages builds the projects tab root page', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/projects'));
      final location = ProjectsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);

      final pages = location.buildPages(mockBuildContext, beamState);

      expect(pages, hasLength(1));
      expect(pages.first.child, isA<ProjectsTabPage>());
    });

    test('buildPages stacks the detail page on top of the projects tab', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/projects/project-123'),
      );
      final location = ProjectsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(
        routeInformation,
      ).copyWith(pathParameters: {'projectId': 'project-123'});

      final pages = location.buildPages(mockBuildContext, beamState);

      expect(pages, hasLength(2));
      expect(pages.first.child, isA<ProjectsTabPage>());
      expect(pages.last.child, isA<ProjectDetailsPage>());

      final detailPage = pages.last.child as ProjectDetailsPage;
      expect(detailPage.projectId, 'project-123');
    });

    test(
      'in desktop mode, buildPages returns only root page '
      'and does not push detail page',
      () {
        final desktopSelectedProjectId = ValueNotifier<String?>(null);

        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.desktopSelectedProjectId,
        ).thenReturn(desktopSelectedProjectId);

        final routeInformation = RouteInformation(
          uri: Uri.parse('/projects/project-123'),
        );
        final location = ProjectsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(
          routeInformation,
        ).copyWith(pathParameters: {'projectId': 'project-123'});

        final pages = location.buildPages(mockBuildContext, beamState);

        expect(pages, hasLength(1));
        expect(pages.first.child, isA<ProjectsTabPage>());
      },
    );

    test('buildPages stacks the create page on top of the projects tab', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/projects/create?categoryId=cat-1'),
      );
      final location = ProjectsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(
        routeInformation,
      ).copyWith(pathParameters: {'projectId': 'create'});

      final pages = location.buildPages(mockBuildContext, beamState);

      expect(pages, hasLength(2));
      expect(pages.first.child, isA<ProjectsTabPage>());
      expect(pages.last.child, isA<ProjectCreatePage>());

      final createPage = pages.last.child as ProjectCreatePage;
      expect(createPage.categoryId, 'cat-1');
    });

    test(
      'normalizes empty / whitespace categoryId query values to null so a '
      'stale `?categoryId=` link does not pin the new project to an '
      'unresolvable category id',
      () {
        for (final raw in const ['', '   ', '\t']) {
          final routeInformation = RouteInformation(
            uri: Uri.parse('/projects/create?categoryId=$raw'),
          );
          final location = ProjectsLocation(routeInformation);
          final beamState = BeamState.fromRouteInformation(
            routeInformation,
          ).copyWith(pathParameters: {'projectId': 'create'});

          final pages = location.buildPages(mockBuildContext, beamState);
          final createPage = pages.last.child as ProjectCreatePage;

          expect(
            createPage.categoryId,
            isNull,
            reason: 'expected `?categoryId=$raw` to map to null',
          );
        }
      },
    );

    test(
      'in desktop mode, /projects/create skips desktop project selection',
      () {
        final desktopSelectedProjectId = ValueNotifier<String?>('existing-id');

        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.desktopSelectedProjectId,
        ).thenReturn(desktopSelectedProjectId);

        final routeInformation = RouteInformation(
          uri: Uri.parse('/projects/create'),
        );
        final location = ProjectsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(
          routeInformation,
        ).copyWith(pathParameters: {'projectId': 'create'});

        final pages = location.buildPages(mockBuildContext, beamState);

        expect(pages, hasLength(2));
        expect(pages.first.child, isA<ProjectsTabPage>());
        expect(pages.last.child, isA<ProjectCreatePage>());
        // Selection notifier must not be touched on the create route —
        // 'create' is not a real project id and overwriting the
        // notifier would break the right-pane detail when the user
        // bounces back to the list.
        expect(desktopSelectedProjectId.value, 'existing-id');
      },
    );

    test(
      'in desktop mode, buildPages updates desktopSelectedProjectId',
      () {
        final desktopSelectedProjectId = ValueNotifier<String?>(null);

        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.desktopSelectedProjectId,
        ).thenReturn(desktopSelectedProjectId);

        final routeInformation = RouteInformation(
          uri: Uri.parse('/projects/project-123'),
        );
        final location = ProjectsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(
          routeInformation,
        ).copyWith(pathParameters: {'projectId': 'project-123'});

        location.buildPages(mockBuildContext, beamState);

        expect(desktopSelectedProjectId.value, 'project-123');
      },
    );
  });
}
