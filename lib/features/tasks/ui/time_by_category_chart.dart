import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphic/graphic.dart';
import 'package:lotti/features/tasks/state/day_view_controller.dart';
import 'package:lotti/features/tasks/state/time_by_category_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';

class TimeByCategoryChart extends ConsumerStatefulWidget {
  const TimeByCategoryChart({super.key});

  @override
  ConsumerState<TimeByCategoryChart> createState() => _TimeByCategoryChart();
}

class _TimeByCategoryChart extends ConsumerState<TimeByCategoryChart> {
  Map<int, Map<String, dynamic>> selectedData = {};

  void _onSelectedDataChanged(Map<int, Map<String, dynamic>> data) {
    final selectedDate = selectedData.values.firstOrNull?['date'] as DateTime?;
    final newDate = data.values.firstOrNull?['date'] as DateTime?;

    if (selectedDate != newDate) {
      setState(() => selectedData = data);
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

    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TimeSpanSegmentedControl(
              timeSpanDays: timeSpanDays,
              onValueChanged: onValueChanged,
              segments: const [14, 30, 90],
            ),
          ),
          if (data != null && data.isNotEmpty)
            TapRegion(
              onTapOutside: (_) => setState(() {
                selectedData = {};
              }),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    height: 220,
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
                          accessor: (TimeByDayAndCategory item) =>
                              item.categoryId,
                        ),
                        'name': Variable(
                          accessor: (TimeByDayAndCategory item) =>
                              item.categoryDefinition?.name ?? 'unassigned',
                        ),
                      },
                      marks: [
                        AreaMark(
                          position: Varset('date') *
                              Varset('value') /
                              Varset('categoryId'),
                          shape:
                              ShapeEncode(value: BasicAreaShape(smooth: true)),
                          color: ColorEncode(
                            encoder: (data) {
                              final categoryId = data['categoryId'] as String;
                              final categoryDefinition =
                                  getIt<EntitiesCacheService>()
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
                            strokeColor:
                                Theme.of(context).textTheme.bodySmall?.color,
                            strokeWidth: 2,
                          ),
                          PaintStyle(strokeColor: Colors.transparent),
                        ],
                      ),
                      axes: [Defaults.horizontalAxis],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Legend(
                        selectedData: selectedData,
                        key: Key(selectedData.hashCode.toString()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class Legend extends ConsumerWidget {
  const Legend({
    required this.selectedData,
    super.key,
  });

  final Map<int, Map<String, dynamic>> selectedData;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    if (selectedData.isEmpty) {
      return const SizedBox.shrink();
    }

    final date = selectedData.values.first['date'] as DateTime;

    final nonEmptyValues = selectedData.values.where((e) => e['value'] != 0);
    var totalMinutes = 0;

    for (final e in nonEmptyValues) {
      totalMinutes += e['value'] as int;
    }

    return Container(
      constraints: const BoxConstraints(
        minHeight: 80,
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
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class CollapsibleTimeChart extends StatelessWidget {
  const CollapsibleTimeChart({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 20, left: 20, right: 20),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(),
        title: Center(child: Text('Time Chart')),
        children: [
          TimeByCategoryChart(),
        ],
      ),
    );
  }
}
