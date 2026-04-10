import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:tinycolor2/tinycolor2.dart';

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
      onPressed: () {
        ModalUtils.showBottomSheet<void>(
          context: context,
          builder: (BuildContext context) {
            return _DashboardsFilterModal(categories: categories);
          },
        );
      },
    );
  }
}

class _DashboardsFilterModal extends ConsumerWidget {
  const _DashboardsFilterModal({required this.categories});

  final List<CategoryDefinition> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategoryIds = ref.watch(selectedCategoryIdsProvider);

    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: tokens.spacing.step5,
        horizontal: tokens.spacing.step3,
      ),
      child: Wrap(
        spacing: tokens.spacing.step2,
        runSpacing: tokens.spacing.step2,
        children: [
          ...categories.map((category) {
            final color = colorFromCssHex(category.color);

            return Opacity(
              opacity: selectedCategoryIds.contains(category.id) ? 1 : 0.4,
              child: ActionChip(
                onPressed: () => ref
                    .read(selectedCategoryIdsProvider.notifier)
                    .toggle(category.id),
                label: Text(
                  category.name,
                  style: TextStyle(
                    color: color.isLight ? Colors.black : Colors.white,
                  ),
                ),
                backgroundColor: color,
              ),
            );
          }),
        ],
      ),
    );
  }
}
