import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/calendar/state/day_view_controller.dart';
import 'package:lotti/features/calendar/state/time_by_category_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

class TimeByCategoryChartLegend extends ConsumerWidget {
  const TimeByCategoryChartLegend({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final data = ref.watch(timeChartSelectedDataProvider);
    final selectedDay = ref.watch(daySelectionControllerProvider);
    final categoriesCount = ref.watch(maxCategoriesCountProvider).value ?? 0;

    final minHeight = ((categoriesCount + 2) * 40.0) + 10;
    if (data.isEmpty) {
      return SizedBox(height: minHeight);
    }

    final nonEmptyValues = data.values.where((e) => e['value'] != 0);
    var totalMinutes = 0;

    for (final e in nonEmptyValues) {
      totalMinutes += e['value'] as int;
    }

    return Container(
      height: minHeight,
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        children: [
          Text(
            selectedDay.ymwd,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ResponsiveGridList(
            horizontalGridMargin: 10,
            verticalGridMargin: 20,
            minItemWidth: 180,
            maxItemsPerRow: 1,
            listViewBuilderOptions: ListViewBuilderOptions(
              shrinkWrap: true,
            ),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      height: 24,
                      width: 24,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.messages.timeByCategoryChartTotalLabel,
                    style: chartTitleStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Spacer(),
                  Text(
                    formatHhMm(Duration(minutes: totalMinutes)),
                    style: chartTitleStyleMonospace.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              ...nonEmptyValues.map((e) {
                final name = e['name'] as String;
                final formattedValue = e['formattedValue'] as String;
                final categoryId = e['categoryId'] as String;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CategoryColorIcon(categoryId),
                    const SizedBox(width: 10),
                    Text(
                      name,
                      style: chartTitleStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 10),
                    const Spacer(),
                    Text(
                      formattedValue,
                      style: chartTitleStyleMonospace,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
