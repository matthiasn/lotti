import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/projects/ui/pages/projects_tab_page.dart';

class ProjectsLocation extends BeamLocation<BeamState> {
  ProjectsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/projects',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return const [
      BeamPage(
        key: ValueKey('projects'),
        title: 'Projects',
        child: ProjectsTabPage(),
      ),
    ];
  }
}
