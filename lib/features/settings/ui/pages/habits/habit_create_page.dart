import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
import 'package:lotti/utils/file_utils.dart';

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
    return BlocProvider<HabitSettingsCubit>(
      create: (ctx) => HabitSettingsCubit(
        _habitDefinition,
        context: ctx,
      ),
      child: const HabitDetailsPage(),
    );
  }
}
