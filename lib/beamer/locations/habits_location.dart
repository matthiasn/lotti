import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_page.dart';

class HabitsLocation extends BeamLocation<BeamState> {
  HabitsLocation(RouteInformation super.routeInformation);

  static const createPath = '/habits/create';
  static String editPath(String habitId) => '/habits/edit/$habitId';

  @override
  List<String> get pathPatterns => [
    '/habits',
    '/habits/create',
    '/habits/edit/:habitId',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final habitId = state.pathParameters['habitId'];
    return [
      const BeamPage(
        key: ValueKey('habits'),
        title: 'Habits',
        child: HabitsTabPage(),
      ),
      if (state.uri.path == createPath)
        const BeamPage(
          key: ValueKey('habits-create'),
          title: 'Habits',
          popToNamed: '/habits',
          child: HabitEditorPage(),
        ),
      if (habitId != null && state.uri.path.startsWith('/habits/edit/'))
        BeamPage(
          key: ValueKey('habits-edit-$habitId'),
          title: 'Habits',
          popToNamed: '/habits',
          child: HabitEditorPage(habitId: habitId),
        ),
    ];
  }
}
