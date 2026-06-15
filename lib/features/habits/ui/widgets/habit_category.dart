import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/habits/state/habit_settings_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// Category picker for the habit editor, rendered as a
/// [SettingsPickerField] so it matches the design-system fields around
/// it. Selection happens in [CategoryPickerSheet].
class SelectCategoryWidget extends ConsumerWidget {
  const SelectCategoryWidget({
    required this.habitId,
    super.key,
  });

  /// Chip size inside a picker field (the field is `spacing.step9` tall).
  static const double _fieldChipSize = 28;

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitSettingsControllerProvider(habitId));
    final notifier = ref.read(
      habitSettingsControllerProvider(habitId).notifier,
    );
    final categoryId = state.habitDefinition.categoryId;
    final category = getIt<EntitiesCacheService>().getCategoryById(categoryId);

    Future<void> onTap() async {
      final result = await showCategoryPicker(
        context: context,
        title: context.messages.habitCategoryLabel,
        currentCategoryId: categoryId,
      );
      if (result == null) return;
      notifier.setCategory(result.categoryOrNull?.id);
    }

    return SettingsPickerField(
      label: context.messages.optionalCategoryLabel,
      valueText: category?.name,
      hintText: context.messages.habitCategoryHint,
      // Same rounded-square chip language as the list rows — one
      // category identity mark everywhere.
      leading: category != null
          ? CategoryIconChip(category: category, size: _fieldChipSize)
          : null,
      onClear: category != null ? () => notifier.setCategory(null) : null,
      onTap: onTap,
    );
  }
}
