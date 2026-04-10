import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/projects/ui/pages/project_details_page.dart';
import 'package:lotti/features/projects/ui/pages/projects_tab_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

class ProjectsLocation extends BeamLocation<BeamState> {
  ProjectsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/projects',
    '/projects/:projectId',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final projectId = state.pathParameters['projectId'];
    final navService = getIt<NavService>();
    final isDesktop = navService.isDesktopMode;

    if (isDesktop) {
      navService.desktopSelectedProjectId.value = projectId;
    }

    return [
      const BeamPage(
        key: ValueKey('projects'),
        title: 'Projects',
        child: ProjectsTabPage(),
      ),
      if (!isDesktop && projectId != null)
        BeamPage(
          key: ValueKey('project-details-$projectId'),
          title: 'Project Details',
          child: ProjectDetailsPage(projectId: projectId),
        ),
    ];
  }
}
