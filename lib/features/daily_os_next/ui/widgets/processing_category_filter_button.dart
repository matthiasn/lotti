import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/daily_os_next/logic/day_plan_availability.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';

class ProcessingCategoryFilterButton extends ConsumerWidget {
  const ProcessingCategoryFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(dailyOsPreferencesControllerProvider);
    final hasExclusions = prefs.excludedCategoryIds.isNotEmpty;
    return IconButton(
      icon: Icon(
        LottiIcons.filter,
        // Lucide is stroke-only, so the filled/outlined swap this used to
        // rely on has no counterpart. Colour carries the state instead —
        // without it the button gave no sign that a filter was narrowing
        // the list at all.
        color: hasExclusions
            ? context.designTokens.colors.interactive.enabled
            : null,
      ),
      tooltip: context.messages.dailyOsNextCategoryFilterTooltip,
      onPressed: () => _showProcessingCategories(context, ref),
    );
  }

  Future<void> _showProcessingCategories(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final prefs = ref.read(dailyOsPreferencesControllerProvider);
    final notifier = ref.read(dailyOsPreferencesControllerProvider.notifier);
    // Day-plan universe: strictly opt-in via the category's day-plan switch.
    final categories = filterDayPlanCategories(
      getIt<EntitiesCacheService>().sortedCategories,
    );
    final allCategoryIds = categories.map((category) => category.id).toSet();

    final result = await showCategoryMultiPicker(
      context: context,
      title: context.messages.dailyOsNextCategoryFilterTitle,
      // The picker selects the INCLUDED categories; seed from those currently
      // allowed. On Apply the controller inverts this back to the excluded set.
      initialSelectedIds: allCategoryIds.where(prefs.allowsCategoryId).toSet(),
      options: categories,
      allowCreate: false,
    );
    if (result == null) return;

    notifier.setIncludedCategoryIds(
      includedCategoryIds: result.ids,
      allCategoryIds: allCategoryIds,
    );
  }
}
