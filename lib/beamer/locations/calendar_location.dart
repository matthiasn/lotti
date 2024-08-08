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
    final ymd = state.queryParameters['ymd'];
    final timeSpanDays = state.queryParameters['timeSpanDays'];

    return [
      BeamPage(
        key: const ValueKey('calendar_page'),
        child: DayViewPage(
          initialDayYmd: '$ymd',
          timeSpanDays: int.tryParse(timeSpanDays ?? '30') ?? 30,
        ),
      ),
    ];
  }
}
