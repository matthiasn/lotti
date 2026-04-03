import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os/ui/pages/daily_os_page.dart';
import 'package:lotti/features/daily_os/ui/pages/set_time_blocks_page.dart';

class CalendarLocation extends BeamLocation<BeamState> {
  CalendarLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/calendar',
    '/calendar/set-time-blocks',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final pages = [
      const BeamPage(
        key: ValueKey('calendar_page'),
        child: DailyOsPage(),
      ),
    ];

    if (state.uri.path == '/calendar/set-time-blocks') {
      pages.add(
        const BeamPage(
          key: ValueKey('set_time_blocks_page'),
          child: SetTimeBlocksPage(),
        ),
      );
    }

    return pages;
  }
}
