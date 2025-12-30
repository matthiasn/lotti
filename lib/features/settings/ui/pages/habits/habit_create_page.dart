import 'package:flutter/material.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
import 'package:lotti/utils/file_utils.dart';

class CreateHabitPage extends StatelessWidget {
  CreateHabitPage({super.key}) : habitId = uuid.v1();

  final String habitId;

  @override
  Widget build(BuildContext context) {
    return HabitDetailsPage(habitId: habitId);
  }
}
