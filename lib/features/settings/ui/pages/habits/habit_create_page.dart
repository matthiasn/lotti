import 'package:flutter/material.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
import 'package:lotti/utils/file_utils.dart';

/// Entry point for creating a habit.
///
/// Mints a fresh [habitId] and opens [HabitDetailsPage] in create mode; the
/// editor's controller seeds a blank definition under that id.
class CreateHabitPage extends StatelessWidget {
  CreateHabitPage({super.key}) : habitId = uuid.v1();

  final String habitId;

  @override
  Widget build(BuildContext context) {
    return HabitDetailsPage(habitId: habitId, isCreateMode: true);
  }
}
