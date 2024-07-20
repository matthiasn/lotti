import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphic/graphic.dart';
import 'package:lotti/features/tasks/state/time_by_category_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';

class TimeByCategoryChart extends ConsumerWidget {
  const TimeByCategoryChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(timeByDayChartProvider).value;
    final provider = timeFrameControllerProvider;

    final textStyle = TextStyle(
      color: secondaryTextColor,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w300,
    );

    final timeSpanDays = ref.watch(provider);
    final onValueChanged = ref.read(provider.notifier).onValueChanged;

    return Column(
      children: [
        const SizedBox(height: 50),
        const Divider(),
        Text('Time by category:', style: searchLabelStyle()),
        const SizedBox(height: 20),
        TimeSpanSegmentedControl(
          timeSpanDays: timeSpanDays,
          onValueChanged: onValueChanged,
          segments: const [14, 30, 90],
        ),
        if (data != null && data.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            height: 200,
            child: Chart(
              data: data,
              key: Key('${data.hashCode}'),
              variables: {
                'date': Variable(
                  accessor: (TimeByDayAndCategory item) => item.date,
                  scale: TimeScale(
                    tickCount: 5,
                    min: DateTime.now()
                        .subtract(Duration(days: timeSpanDays))
                        .dayAtNoon,
                    max: DateTime.now().dayAtNoon,
                    formatter: (DateTime dt) => dt.md,
                  ),
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
                renderer: (size, offset, data) {
                  return <MarkElement>[
                    LabelElement(
                      text: '${data.values.first['date']}',
                      anchor: offset,
                      style: LabelStyle(
                        textStyle: textStyle.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    ...data.values
                        .where((e) => e['value'] != 0)
                        .mapIndexed((i, e) {
                      return LabelElement(
                        text: '${e['name']} - ${e['formattedValue']}',
                        anchor: offset + Offset(0, (i + 1) * 16),
                        style: LabelStyle(
                          textStyle: textStyle,
                        ),
                      );
                    }),
                  ];
                },
              ),
              crosshair: CrosshairGuide(followPointer: [true, true]),
              axes: [
                Defaults.horizontalAxis,
              ],
            ),
          ),
      ],
    );
  }
}
