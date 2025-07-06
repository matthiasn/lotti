import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/calendar/ui/pages/day_view_page.dart';

class CalendarLocation extends BeamLocation<BeamState> {
  CalendarLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/calendar',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return [
      const BeamPage(
        key: ValueKey('calendar_page'),
        child: DayViewPage(),
      ),
    ];
  }
}
