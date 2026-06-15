import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class DashboardsFilter extends ConsumerWidget {
  const DashboardsFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(dashboardCategoriesProvider);
    final selectedCategoryIds = ref.watch(selectedCategoryIdsProvider);
    final categories = categoriesAsync.value ?? [];
    final tokens = context.designTokens;
    final hasActiveFilter = selectedCategoryIds.isNotEmpty;

    return IconButton(
      key: const Key('dashboard_category_filter'),
      icon: Icon(
        hasActiveFilter ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
        color: hasActiveFilter
            ? tokens.colors.text.highEmphasis
            : tokens.colors.text.lowEmphasis,
      ),
      onPressed: () async {
        final notifier = ref.read(selectedCategoryIdsProvider.notifier);
        final result = await showCategoryMultiPicker(
          context: context,
          title: context.messages.dashboardCategoryLabel,
          initialSelectedIds: selectedCategoryIds,
          options: categories,
        );
        if (result == null || !result.changed) return;
        notifier.setAll(result.ids);
      },
    );
  }
}
