import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:tinycolor2/tinycolor2.dart';

class DashboardsFilter extends ConsumerWidget {
  const DashboardsFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<CategoryDefinition>>(
      stream: getIt<JournalDb>().watchCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? <CategoryDefinition>[];
        final categoriesById = <String, CategoryDefinition>{};

        for (final category in categories) {
          categoriesById[category.id] = category;
        }

        final filteredSortedDashboards =
            ref.watch(filteredSortedDashboardsProvider);

        final dataMap = <String, double>{};

        for (final dashboard in filteredSortedDashboards) {
          final categoryId = dashboard.categoryId ?? 'undefined';
          dataMap[categoryId] = (dataMap[categoryId] ?? 0) + 1;
        }

        final colorList = dataMap.keys.map((categoryId) {
          final category = categoriesById[categoryId];

          return category != null
              ? colorFromCssHex(category.color)
              : Colors.grey;
        }).toList();

        return IconButton(
          key: const Key('dashboard_category_filter'),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          icon: dataMap.isEmpty
              ? Icon(
                  Icons.filter_alt_off_outlined,
                  color: context.colorScheme.outline,
                )
              : PieChart(
                  dataMap: dataMap,
                  animationDuration: const Duration(milliseconds: 800),
                  chartRadius: 25,
                  colorList: colorList,
                  initialAngleInDegree: 0,
                  chartType: ChartType.ring,
                  ringStrokeWidth: 10,
                  legendOptions: const LegendOptions(showLegends: false),
                  chartValuesOptions: const ChartValuesOptions(
                    showChartValueBackground: false,
                    showChartValues: false,
                  ),
                ),
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              builder: (BuildContext context) {
                return _DashboardsFilterModal(categories: categories);
              },
            );
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

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 20,
        horizontal: 10,
      ),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
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
