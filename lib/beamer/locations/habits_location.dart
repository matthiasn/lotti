import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
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
      BeamPage(
        key: const ValueKey('habits'),
        title: 'Habits',
        child: BlocProvider<HabitsCubit>(
          create: (BuildContext context) => HabitsCubit(),
          child: const HabitsTabPage(),
        ),
      ),
    ];

    return pages;
  }
}
