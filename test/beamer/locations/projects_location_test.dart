import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/projects_location.dart';
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
      getIt.allowReassignment = true;
      getIt.registerSingleton<NavService>(mockNavService);
    });

    tearDown(() {
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      getIt.allowReassignment = false;
    });

    test('pathPatterns are correct', () {
      final location = ProjectsLocation(
        RouteInformation(uri: Uri.parse('/projects')),
      );

      expect(location.pathPatterns, ['/projects', '/projects/:projectId']);
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
  });
}
