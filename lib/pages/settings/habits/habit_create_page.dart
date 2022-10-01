import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/habits/habit_details_page.dart';
import 'package:lotti/utils/file_utils.dart';

class CreateHabitPage extends StatefulWidget {
  const CreateHabitPage({super.key});

  @override
  State<CreateHabitPage> createState() => _CreateHabitPageState();
}

class _CreateHabitPageState extends State<CreateHabitPage> {
  HabitDefinition? _habitDefinition;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _habitDefinition = HabitDefinition(
      id: uuid.v1(),
      name: '',
      createdAt: now,
      updatedAt: now,
      description: '',
      private: false,
      vectorClock: null,
      habitSchedule: HabitSchedule.daily(requiredCompletions: 1),
      version: '',
      active: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_habitDefinition == null) {
      return const EmptyScaffoldWithTitle('');
    }

    return HabitDetailsPage(habitDefinition: _habitDefinition!);
  }
}
