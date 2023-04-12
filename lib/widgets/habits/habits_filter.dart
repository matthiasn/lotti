import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:tinycolor2/tinycolor2.dart';

class HabitsFilter extends StatelessWidget {
  const HabitsFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoryDefinition>>(
      stream: getIt<JournalDb>().watchCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? <CategoryDefinition>[];
        final categoriesById = <String, CategoryDefinition>{};

        for (final category in categories) {
          categoriesById[category.id] = category;
        }

        return BlocBuilder<HabitsCubit, HabitsState>(
          builder: (context, HabitsState state) {
            final dataMap = <String, double>{};
            final cubit = context.read<HabitsCubit>();

            for (final habit in state.openNow) {
              final categoryId = habit.categoryId ?? 'undefined';
              dataMap[categoryId] = (dataMap[categoryId] ?? 0) + 1;
            }

            final colorList = dataMap.keys.map((categoryId) {
              final category = categoriesById[categoryId];

              return category != null
                  ? colorFromCssHex(category.color)
                  : Colors.grey;
            }).toList();

            return IconButton(
              padding: const EdgeInsets.all(5),
              icon: dataMap.isEmpty
                  ? Icon(
                      Icons.filter_alt_off_outlined,
                      color: styleConfig().secondaryTextColor,
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
                  useRootNavigator: true,
                  builder: (BuildContext context) {
                    return BlocProvider.value(
                      value: cubit,
                      child: BlocBuilder<HabitsCubit, HabitsState>(
                        builder: (context, HabitsState state) {
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
                                    opacity: state.selectedCategoryIds
                                            .contains(category.id)
                                        ? 1
                                        : 0.4,
                                    child: ActionChip(
                                      onPressed: () =>
                                          cubit.toggleSelectedCategoryIds(
                                        category.id,
                                      ),
                                      label: Text(
                                        category.name,
                                        style: TextStyle(
                                          color: color.isLight
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                      backgroundColor: color,
                                    ),
                                  );
                                })
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
