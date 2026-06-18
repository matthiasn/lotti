import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_controller.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_data.dart';
import 'package:lotti/features/habits/ui/widgets/heatmap/habit_heatmap_card.dart';
import 'package:lotti/features/habits/ui/widgets/heatmap/habit_heatmap_grid.dart';
import 'package:lotti/utils/device_region.dart';

import '../../../../../widget_test_utils.dart';

/// Serves a fixed [HabitHeatmapData] without touching the database-backed
/// production controller.
class _FakeHeatmapController extends HabitHeatmapController {
  _FakeHeatmapController(this._data);

  final HabitHeatmapData _data;

  @override
  HabitHeatmapData build() => _data;
}

void main() {
  const sampleDays = [
    HeatmapDay(
      ymd: '2024-06-10',
      successCount: 1,
      activeCount: 1,
      isToday: false,
    ),
    HeatmapDay(
      ymd: '2024-06-11',
      successCount: 0,
      activeCount: 1,
      isToday: false,
    ),
    HeatmapDay(
      ymd: '2024-06-12',
      successCount: 1,
      activeCount: 1,
      isToday: true,
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required HabitHeatmapData data,
    Object firstDay = 1,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const HabitHeatmapCard(),
        overrides: [
          habitHeatmapControllerProvider.overrideWith(
            () => _FakeHeatmapController(data),
          ),
          if (firstDay == 'loading')
            firstDayOfWeekIndexProvider.overrideWith(
              (ref) => Completer<int>().future,
            )
          else
            firstDayOfWeekIndexProvider.overrideWith((ref) => firstDay as int),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('renders title, grid and legend when habits exist', (
    tester,
  ) async {
    await pump(
      tester,
      data: const HabitHeatmapData(
        days: sampleDays,
        hasHabits: true,
        isLoading: false,
      ),
    );
    expect(find.text('Consistency'), findsOneWidget);
    expect(find.byType(HabitHeatmapGrid), findsOneWidget);
    expect(find.text('Less'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('narrow width stacks the legend below the title', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        // < 460 forces the header into a Column (title above legend).
        const SizedBox(width: 400, child: HabitHeatmapCard()),
        overrides: [
          habitHeatmapControllerProvider.overrideWith(
            () => _FakeHeatmapController(
              const HabitHeatmapData(
                days: sampleDays,
                hasHabits: true,
                isLoading: false,
              ),
            ),
          ),
          firstDayOfWeekIndexProvider.overrideWith((ref) => 1),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Consistency'), findsOneWidget);
    expect(find.text('Less'), findsOneWidget);
    // The legend dropped below the title instead of sitting beside it.
    expect(
      tester.getTopLeft(find.text('Less')).dy,
      greaterThan(tester.getTopLeft(find.text('Consistency')).dy),
    );
  });

  testWidgets('shows the empty placeholder and no grid when no habits exist', (
    tester,
  ) async {
    await pump(
      tester,
      data: const HabitHeatmapData(
        days: sampleDays,
        hasHabits: false,
        isLoading: false,
      ),
    );
    expect(find.byType(HabitHeatmapGrid), findsNothing);
    expect(
      find.text('Add a habit to start building your consistency'),
      findsOneWidget,
    );
    // No legend without a grid.
    expect(find.text('Less'), findsNothing);
  });

  testWidgets('first loading frame reserves space without grid or CTA', (
    tester,
  ) async {
    await pump(tester, data: HabitHeatmapData.empty());
    expect(find.text('Consistency'), findsOneWidget);
    expect(find.byType(HabitHeatmapGrid), findsNothing);
    expect(
      find.text('Add a habit to start building your consistency'),
      findsNothing,
    );
    expect(find.text('Less'), findsNothing);
  });

  testWidgets('falls back to Monday-first when the region is unresolved', (
    tester,
  ) async {
    await pump(
      tester,
      data: const HabitHeatmapData(
        days: sampleDays,
        hasHabits: true,
        isLoading: false,
      ),
      firstDay: 'loading',
    );
    final grid = tester.widget<HabitHeatmapGrid>(find.byType(HabitHeatmapGrid));
    expect(grid.firstDayOfWeekIndex, DateTime.monday % 7); // 1
  });
}
