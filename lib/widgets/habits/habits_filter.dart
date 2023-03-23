import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/color.dart';
import 'package:pie_chart/pie_chart.dart';

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

            if (dataMap.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.all(5),
              child: PieChart(
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
            );
          },
        );
      },
    );
  }
}
