import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/ui/pages/daily_os_page.dart';
import 'package:lotti/features/daily_os/ui/pages/set_time_blocks_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';

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
        child: CalendarRoot(),
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

/// Branches between the current Daily OS surface and the next-gen
/// agentic Capture flow based on [dailyOsNextEnabledFlag].
///
/// Kept as a thin wrapper so the [BeamPage] key stays stable across
/// flag flips — pushing/popping inside Capture / Reconcile doesn't
/// blow away the calendar tab's navigation history.
@visibleForTesting
class CalendarRoot extends StatelessWidget {
  const CalendarRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: getIt<JournalDb>().watchConfigFlag(dailyOsNextEnabledFlag),
      initialData: false,
      builder: (context, snapshot) {
        final useNext = snapshot.data ?? false;
        return useNext ? const CapturePage() : const DailyOsPage();
      },
    );
  }
}
