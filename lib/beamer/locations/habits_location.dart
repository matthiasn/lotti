import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/pages/habits/habits_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/uuid.dart';

class HabitsLocation extends BeamLocation<BeamState> {
  HabitsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/habits',
        '/habits/complete_habit/:habitId',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final habitId = state.pathParameters['habitId'];

    final pages = [
      const BeamPage(
        key: ValueKey('habits'),
        title: 'Habits',
        type: BeamPageType.noTransition,
        child: HabitsTabPage(),
      ),
      if (habitId != null && isUuid(habitId))
        BeamPage(
          routeBuilder: (
            BuildContext context,
            RouteSettings settings,
            Widget child,
          ) {
            return DialogRoute<void>(
              context: context,
              builder: (context) => child,
              settings: settings,
              barrierColor: styleConfig().negspace.withOpacity(0.54),
            );
          },
          key: ValueKey('habits-complete-$habitId'),
          child: HabitDialog(habitId: habitId),
          onPopPage: (context, delegate, _, page) {
            dashboardsBeamerDelegate.beamBack();
            return false;
          },
        ),
    ];

    return pages;
  }
}
