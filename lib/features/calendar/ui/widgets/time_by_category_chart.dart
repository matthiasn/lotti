import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphic/graphic.dart';
import 'package:lotti/features/calendar/state/day_view_controller.dart';
import 'package:lotti/features/calendar/state/time_by_category_controller.dart';
import 'package:lotti/features/calendar/ui/widgets/time_by_category_chart_legend.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:visibility_detector/visibility_detector.dart';

class TimeByCategoryChart extends ConsumerStatefulWidget {
  const TimeByCategoryChart({
    this.showLegend = true,
    this.showTimeframeSelector = true,
    this.height = 220,
    super.key,
  });

  final bool showTimeframeSelector;
  final bool showLegend;
  final double height;

  @override
  ConsumerState<TimeByCategoryChart> createState() => _TimeByCategoryChart();
}

class _TimeByCategoryChart extends ConsumerState<TimeByCategoryChart> {
  Map<int, Map<String, dynamic>> selectedData = {};

  void _onSelectedDataChanged(Map<int, Map<String, dynamic>> data) {
    final selectedDate = selectedData.values.firstOrNull?['date'] as DateTime?;
    final newDate = data.values.firstOrNull?['date'] as DateTime?;

    if (selectedDate != newDate) {
      selectedData = data;

      ref
          .read(timeChartSelectedDataProvider.notifier)
          .updateSelection(selectedData);

      if (newDate != null) {
        ref.read(daySelectionControllerProvider.notifier).selectDay(newDate);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(timeByDayChartProvider).value;
    final provider = timeFrameControllerProvider;
    final timeSpanDays = ref.watch(provider);
    final onValueChanged = ref.read(provider.notifier).onValueChanged;

    return VisibilityDetector(
      key: const Key('time_by_category_chart'),
      onVisibilityChanged: ref
          .read(timeByCategoryControllerProvider.notifier)
          .onVisibilityChanged,
      child: Column(
        children: [
          if (widget.showTimeframeSelector)
            Align(
              alignment: Alignment.centerRight,
              child: TimeSpanSegmentedControl(
                timeSpanDays: timeSpanDays,
                onValueChanged: onValueChanged,
                segments: const [14, 30, 90],
              ),
            ),
          if (data != null && data.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.only(right: 20),
              height: widget.height,
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
                    shape: ShapeEncode(
                      value: BasicAreaShape(smooth: true),
                    ),
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
                    _onSelectedDataChanged(data);
                    return <MarkElement>[];
                  },
                ),
                crosshair: CrosshairGuide(
                  followPointer: [true, true],
                  styles: [
                    PaintStyle(
                      strokeColor: context.textTheme.bodySmall?.color,
                      strokeWidth: 2,
                    ),
                    PaintStyle(strokeColor: Colors.transparent),
                  ],
                ),
                axes: [
                  AxisGuide(
                    line: PaintStyle(
                      strokeColor: context.colorScheme.onSurface,
                      strokeWidth: 0.5,
                    ),
                    label: LabelStyle(
                      textStyle: context.textTheme.labelSmall,
                      offset: const Offset(0, 7.5),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showLegend) ...[
              const SizedBox(height: 20),
              const TimeByCategoryChartLegend(),
            ],
          ],
        ],
      ),
    );
  }
}
