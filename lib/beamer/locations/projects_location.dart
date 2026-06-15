import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/projects/ui/pages/project_details_page.dart';
import 'package:lotti/features/projects/ui/pages/projects_tab_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

/// Reserved slug left over from the retired full-screen create route.
///
/// Project creation now happens in a modal launched from the list FAB (see
/// `showProjectCreateModal`), so there is no `/projects/create` page. The
/// `/projects/:projectId` pattern would still greedily match a stale
/// `/projects/create` deep link, so this slug is treated as "no project" and
/// the list is shown instead of a detail page rendered against a non-id.
const String _reservedCreateSlug = 'create';

class ProjectsLocation extends BeamLocation<BeamState> {
  ProjectsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/projects',
    '/projects/:projectId',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final rawProjectId = state.pathParameters['projectId'];
    final isStaleCreateSlug = rawProjectId == _reservedCreateSlug;
    final projectId = isStaleCreateSlug ? null : rawProjectId;
    final navService = getIt<NavService>();
    final isDesktop = navService.isDesktopMode;

    // Skip the desktop detail-pane sync for the stale create slug — it is not
    // a real project id, and overwriting the notifier would clear the current
    // right-pane selection when the user bounces back to the list.
    if (isDesktop && !isStaleCreateSlug) {
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
