import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/pages/habits/habits_page.dart';
import 'package:lotti/utils/uuid.dart';

class HabitsLocation extends BeamLocation<BeamState> {
  HabitsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/habits',
        '/habits/complete/:habitId',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final habitId = state.pathParameters['habitId'];

    final pages = [
      BeamPage(
        key: const ValueKey('habits'),
        title: 'Habits',
        type: BeamPageType.noTransition,
        child: BlocProvider<HabitsCubit>(
          create: (BuildContext context) => HabitsCubit(),
          child: const HabitsTabPage(),
        ),
      ),
      if (habitId != null && isUuid(habitId))
        BeamPage(
          routeBuilder: (
            BuildContext context,
            RouteSettings settings,
            Widget child,
          ) {
            return ModalBottomSheetRoute<void>(
              builder: (context) => child,
              isScrollControlled: true,
              settings: settings,
            );
          },
          key: ValueKey('habits-complete-$habitId'),
          child: HabitDialog(
            habitId: habitId,
            beamerDelegate: habitsBeamerDelegate,
            data: data.toString(),
          ),
          onPopPage: (context, delegate, _, page) {
            habitsBeamerDelegate.beamBack();
            return false;
          },
        ),
    ];

    return pages;
  }
}
