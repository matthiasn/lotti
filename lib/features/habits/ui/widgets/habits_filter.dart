import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habits_tool_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Category filter button for the habits tab — a plain filter glyph in the
/// header tool cluster (active when a category subset is selected). Tapping
/// opens the multi-category picker and commits the chosen set via
/// [HabitsController.setSelectedCategoryIds] (only when the selection changed).
class HabitsFilter extends ConsumerWidget {
  const HabitsFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitsControllerProvider);
    final isFiltering = state.selectedCategoryIds.isNotEmpty;

    return HabitsToolButton(
      key: const Key('habit_category_filter'),
      icon: isFiltering ? Icons.filter_alt : Icons.filter_alt_outlined,
      active: isFiltering,
      semanticLabel: context.messages.habitCategoryLabel,
      onPressed: () async {
        final controller = ref.read(habitsControllerProvider.notifier);
        final result = await showCategoryMultiPicker(
          context: context,
          title: context.messages.habitCategoryLabel,
          initialSelectedIds: state.selectedCategoryIds,
        );
        if (result == null || !result.changed) return;
        controller.setSelectedCategoryIds(result.ids);
      },
    );
  }
}
