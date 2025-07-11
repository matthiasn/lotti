import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/calendar/state/day_view_controller.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';

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
    final nonEmptyValues = data.values.where((e) => e['value'] != 0);
    var totalMinutes = 0;

    for (final e in nonEmptyValues) {
      totalMinutes += e['value'] as int;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        children: [
          Text(
            selectedDay.ymwd,
            style: context.textTheme.titleSmall,
          ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            height: 32,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    height: 20,
                    width: 20,
                    color: context.colorScheme.outline.withAlpha(26),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  context.messages.timeByCategoryChartTotalLabel,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                const Spacer(),
                Text(
                  formatHhMm(Duration(minutes: totalMinutes)),
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...nonEmptyValues.map((e) {
            final name = e['name'] as String;
            final formattedValue = e['formattedValue'] as String;
            final categoryId = e['categoryId'] as String;
            return SizedBox(
              height: 32,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CategoryColorIcon(categoryId),
                  const SizedBox(width: 10),
                  Text(
                    name,
                    style: context.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 10),
                  const Spacer(),
                  Text(
                    formattedValue,
                    style: context.textTheme.titleSmall?.withTabularFigures,
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
