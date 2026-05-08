import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/projects/ui/pages/project_create_page.dart';
import 'package:lotti/features/projects/ui/pages/project_details_page.dart';
import 'package:lotti/features/projects/ui/pages/projects_tab_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

class ProjectsLocation extends BeamLocation<BeamState> {
  ProjectsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/projects',
    '/projects/create',
    '/projects/:projectId',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final projectId = state.pathParameters['projectId'];
    final isCreate = state.uri.path == '/projects/create';
    final navService = getIt<NavService>();
    final isDesktop = navService.isDesktopMode;

    // The literal `/projects/create` route shares the `/projects/:projectId`
    // pattern, so Beamer hands back `projectId == 'create'`. Treat that as
    // the create flow and skip the desktop detail-pane sync — there is no
    // project to select yet.
    if (isDesktop && !isCreate) {
      navService.desktopSelectedProjectId.value = projectId;
    }

    return [
      const BeamPage(
        key: ValueKey('projects'),
        title: 'Projects',
        child: ProjectsTabPage(),
      ),
      if (isCreate)
        BeamPage(
          key: const ValueKey('project-create'),
          title: 'New Project',
          child: ProjectCreatePage(
            categoryId: state.uri.queryParameters['categoryId'],
          ),
        ),
      if (!isDesktop && !isCreate && projectId != null)
        BeamPage(
          key: ValueKey('project-details-$projectId'),
          title: 'Project Details',
          child: ProjectDetailsPage(projectId: projectId),
        ),
    ];
  }
}
