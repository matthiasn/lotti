import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';

class TimeByCategoryChartLegend extends ConsumerWidget {
  const TimeByCategoryChartLegend({
    required this.selectedData,
    super.key,
  });

  final Map<int, Map<String, dynamic>> selectedData;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    const minHeight = 160.0;
    if (selectedData.isEmpty) {
      return const SizedBox(height: minHeight);
    }

    final date = selectedData.values.first['date'] as DateTime;

    final nonEmptyValues = selectedData.values.where((e) => e['value'] != 0);
    var totalMinutes = 0;

    for (final e in nonEmptyValues) {
      totalMinutes += e['value'] as int;
    }

    return Container(
      constraints: const BoxConstraints(
        minHeight: minHeight,
        maxWidth: 320,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                date.ymwd,
                style: chartTitleStyleMonospace.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
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

            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  CategoryColorIcon(categoryId),
                  const SizedBox(width: 10),
                  Text(
                    name,
                    style: chartTitleStyleMonospace,
                  ),
                  const Spacer(),
                  Text(
                    formattedValue,
                    style: chartTitleStyleMonospace,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
