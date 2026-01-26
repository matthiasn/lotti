import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os/ui/pages/daily_os_page.dart';

class DailyOsLocation extends BeamLocation<BeamState> {
  DailyOsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/daily-os',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return [
      const BeamPage(
        key: ValueKey('daily_os_page'),
        child: DailyOsPage(),
      ),
    ];
  }
}
