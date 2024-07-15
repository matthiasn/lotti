import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphic/graphic.dart';
import 'package:lotti/features/tasks/state/time_by_category_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';

class TimeByCategoryChart extends ConsumerWidget {
  const TimeByCategoryChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(timeByDayChartProvider).value;

    return Column(
      children: [
        const SizedBox(height: 50),
        const Divider(),
        Text('Time by category:', style: searchLabelStyle()),
        if (data != null && data.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            height: 160,
            child: Chart(
              data: data,
              key: Key('${data.hashCode}'),
              variables: {
                'date': Variable(
                  accessor: (TimeByDayAndCategory item) => item.date.ymd,
                  scale: OrdinalScale(),
                ),
                'value': Variable(
                  accessor: (TimeByDayAndCategory item) =>
                      item.duration.inMinutes,
                  scale: LinearScale(
                    min: -600,
                    max: 600,
                  ),
                ),
                'formattedValue': Variable(
                  accessor: (TimeByDayAndCategory item) =>
                      formatHhMm(item.duration),
                ),
                'categoryId': Variable(
                  accessor: (TimeByDayAndCategory item) => item.categoryId,
                ),
                'name': Variable(
                  accessor: (TimeByDayAndCategory item) =>
                      item.categoryDefinition?.name ?? 'unassigned',
                ),
              },
              marks: [
                AreaMark(
                  position:
                      Varset('date') * Varset('value') / Varset('categoryId'),
                  shape: ShapeEncode(value: BasicAreaShape(smooth: true)),
                  color: ColorEncode(
                    encoder: (data) {
                      final categoryId = data['categoryId'] as String;
                      final categoryDefinition = getIt<EntitiesCacheService>()
                          .getCategoryById(categoryId);
                      return colorFromCssHex(
                        categoryDefinition?.color,
                        substitute: Colors.grey,
                      );
                    },
                  ),
                  modifiers: [
                    StackModifier(),
                    SymmetricModifier(),
                  ],
                ),
              ],
              selections: {
                'touchMove': PointSelection(
                  on: {
                    GestureType.scaleUpdate,
                    GestureType.tapDown,
                    GestureType.longPressMoveUpdate,
                  },
                  dim: Dim.x,
                  variable: 'date',
                ),
              },
              tooltip: TooltipGuide(
                followPointer: [false, true],
                align: Alignment.topLeft,
                offset: const Offset(-20, -20),
                multiTuples: true,
                variables: ['name', 'formattedValue'],
              ),
              crosshair: CrosshairGuide(followPointer: [false, true]),
            ),
          ),
      ],
    );
  }
}
