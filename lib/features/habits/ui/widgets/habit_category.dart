import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_cubit.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_state.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';

class SelectCategoryWidget extends StatelessWidget {
  const SelectCategoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HabitSettingsCubit, HabitSettingsState>(
      builder: (
        context,
        HabitSettingsState state,
      ) {
        final habitDefinition = state.habitDefinition;

        return CategoryField(
          categoryId: habitDefinition.categoryId,
          onSave: (category) {
            context.read<HabitSettingsCubit>().setCategory(category?.id);
          },
        );
      },
    );
  }
}
