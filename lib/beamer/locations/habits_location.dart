import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';

class HabitsLocation extends BeamLocation<BeamState> {
  HabitsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/habits',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final pages = [
      const BeamPage(
        key: ValueKey('habits'),
        title: 'Habits',
        child: HabitsTabPage(),
      ),
    ];

    return pages;
  }
}
