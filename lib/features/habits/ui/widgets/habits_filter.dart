import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:tinycolor2/tinycolor2.dart';

class HabitsFilter extends ConsumerWidget {
  const HabitsFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = getIt<EntitiesCacheService>().sortedCategories;
    final state = ref.watch(habitsControllerProvider);

    final dataMap = <String, double>{};

    for (final habit in state.openNow) {
      final categoryId = habit.categoryId ?? 'undefined';
      dataMap[categoryId] = (dataMap[categoryId] ?? 0) + 1;
    }

    final colorList = dataMap.keys.map((categoryId) {
      final category =
          getIt<EntitiesCacheService>().getCategoryById(categoryId);

      return category != null ? colorFromCssHex(category.color) : Colors.grey;
    }).toList();

    return IconButton(
      key: const Key('habit_category_filter'),
      padding: const EdgeInsets.all(5),
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
          builder: (BuildContext modalContext) {
            return Consumer(
              builder: (context, ref, child) {
                final modalState = ref.watch(habitsControllerProvider);
                final modalController =
                    ref.read(habitsControllerProvider.notifier);

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
                          opacity: modalState.selectedCategoryIds
                                  .contains(category.id)
                              ? 1
                              : 0.4,
                          child: ActionChip(
                            onPressed: () =>
                                modalController.toggleSelectedCategoryIds(
                              category.id,
                            ),
                            label: Text(
                              category.name,
                              style: TextStyle(
                                color:
                                    color.isLight ? Colors.black : Colors.white,
                              ),
                            ),
                            backgroundColor: color,
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
