import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/widgets/charts/dashboard_story_chart.dart';
import 'package:lotti/widgets/charts/dashboard_survey_chart.dart';
import 'package:lotti/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    Key? key,
    @PathParam() required this.dashboardId,
  }) : super(key: key);

  final String dashboardId;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final JournalDb _db = getIt<JournalDb>();

  double zoomStartScale = 10.0;
  double scale = 10.0;
  double horizontalPan = 0.0;

  @override
  Widget build(BuildContext context) {
    int daysBack = (horizontalPan / scale).floor();

    final DateTime rangeStart = getRangeStart(
      context: context,
      scale: scale,
      daysBack: daysBack,
    );
    final DateTime rangeEnd = getRangeEnd(daysBack: daysBack);
    return GestureDetector(
      onScaleStart: (_) {
        zoomStartScale = scale;
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        setState(() {
          horizontalPan += details.delta.dx;
        });
      },
      onScaleUpdate: (ScaleUpdateDetails details) {
        double horizontalScale = details.horizontalScale;
        setState(() {
          if (horizontalScale != 1.0) {
            scale = zoomStartScale * horizontalScale;
          }
        });
      },
      child: StreamBuilder(
        stream: _db.watchDashboardById(widget.dashboardId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<DashboardDefinition>> snapshot,
        ) {
          DashboardDefinition? dashboard;
          var data = snapshot.data ?? [];
          if (data.isNotEmpty) {
            dashboard = data.first;
          }

          if (dashboard == null) {
            return const SizedBox.shrink();
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(dashboard.name, style: formLabelStyle),
                  ),
                  ...dashboard.items.map((DashboardItem dashboardItem) {
                    return dashboardItem.map(
                      measurement: (DashboardMeasurementItem measurement) {
                        return DashboardMeasurablesChart(
                          measurableDataTypeId: measurement.id,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                          enableCreate: true,
                        );
                      },
                      healthChart: (DashboardHealthItem healthChart) {
                        return DashboardHealthChart(
                          chartConfig: healthChart,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                        );
                      },
                      workoutChart: (DashboardWorkoutItem workoutChart) {
                        return DashboardWorkoutChart(
                          chartConfig: workoutChart,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                        );
                      },
                      storyTimeChart: (DashboardStoryTimeItem storyChart) {
                        return DashboardStoryChart(
                          chartConfig: storyChart,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                        );
                      },
                      surveyChart: (DashboardSurveyItem surveyChart) {
                        return DashboardSurveyChart(
                          chartConfig: surveyChart,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                        );
                      },
                    );
                  }),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          dashboard.description,
                          style: formLabelStyle,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        color: AppColors.entryTextColor,
                        onPressed: () {
                          context.router.pushNamed(
                              '/settings/dashboards/${widget.dashboardId}');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
