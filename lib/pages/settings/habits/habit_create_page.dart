import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/pages/settings/habits/habit_details_page.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:showcaseview/showcaseview.dart';

class CreateHabitPage extends StatelessWidget {
  CreateHabitPage({super.key});

  final _habitDefinition = HabitDefinition(
    id: uuid.v1(),
    name: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    description: '',
    private: false,
    vectorClock: null,
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
    version: '',
    active: true,
  );

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => BlocProvider<HabitSettingsCubit>(
        create: (_) => HabitSettingsCubit(
          _habitDefinition,
          context: context,
        ),
        child: const HabitDetailsPage(),
      ),
    );
  }
}
