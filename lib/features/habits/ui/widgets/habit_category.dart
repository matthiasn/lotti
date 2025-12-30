import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';
import 'package:lotti/features/habits/state/habit_settings_controller.dart';

class SelectCategoryWidget extends ConsumerWidget {
  const SelectCategoryWidget({
    required this.habitId,
    super.key,
  });

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitSettingsControllerProvider(habitId));

    return CategoryField(
      categoryId: state.habitDefinition.categoryId,
      onSave: (category) {
        ref
            .read(habitSettingsControllerProvider(habitId).notifier)
            .setCategory(category?.id);
      },
    );
  }
}
