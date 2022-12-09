import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/widgets/charts/dashboard_survey_chart.dart';
import 'package:lotti/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/widgets/charts/empty_dashboards_widget.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_chart.dart';
import 'package:lotti/widgets/charts/stories/dashboard_story_chart.dart';
import 'package:lotti/widgets/charts/stories/wildcard_story_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.dashboardId,
    this.showBackButton = true,
  });

  final String dashboardId;
  final bool showBackButton;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final JournalDb _db = getIt<JournalDb>();

  double zoomStartScale = 10;
  double scale = 10;
  double horizontalPan = 0;
  bool zoomInProgress = false;
  int timeSpanDays = isDesktop ? 30 : 7;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // TODO: bring back or remove
    // final int shiftDays = max((horizontalPan / scale).floor(), 0);
    // final rangeStart = getRangeStart(
    //   context: context,
    //   scale: scale,
    //   shiftDays: shiftDays,
    // );
    // final rangeEnd = getRangeEnd(shiftDays: shiftDays);

    final rangeStart =
        getStartOfDay(DateTime.now().subtract(Duration(days: timeSpanDays)));
    final rangeEnd = getEndOfToday();

    return GestureDetector(
      // TODO: bring back or remove
      // onScaleStart: (_) {
      //   setState(() {
      //     zoomStartScale = scale;
      //     zoomInProgress = true;
      //   });
      // },
      // onScaleEnd: (_) {
      //   setState(() {
      //     zoomInProgress = false;
      //   });
      // },
      // onHorizontalDragUpdate: (DragUpdateDetails details) {
      //   setState(() {
      //     if (!zoomInProgress) {
      //       horizontalPan += details.delta.dx;
      //     }
      //   });
      // },
      // onScaleUpdate: (ScaleUpdateDetails details) {
      //   final horizontalScale = details.horizontalScale;
      //   setState(() {
      //     if (horizontalScale != 1) {
      //       scale = zoomStartScale * horizontalScale;
      //     }
      //   });
      // },
      child: StreamBuilder(
        stream: _db.watchDashboardById(widget.dashboardId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<DashboardDefinition>> snapshot,
        ) {
          if (!snapshot.hasData) {
            return EmptyScaffoldWithTitle(
              localizations.dashboardsLoadingHint,
              body: const LoadingDashboards(),
            );
          }

          DashboardDefinition? dashboard;
          final data = snapshot.data ?? [];
          if (data.isNotEmpty) {
            dashboard = data.first;
          }

          if (dashboard == null) {
            beamToNamed('/dashboards');
            return EmptyScaffoldWithTitle(
              localizations.dashboardNotFound,
            );
          }

          return Scaffold(
            backgroundColor: styleConfig().negspace,
            appBar: TitleAppBar(
              title: dashboard.name,
              showBackButton: widget.showBackButton,
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  TimeSpanSegmentedControl(
                    timeSpanDays: timeSpanDays,
                    onValueChanged: (int value) {
                      setState(() {
                        timeSpanDays = value;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  DashboardWidget(
                    dashboard: dashboard,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    dashboardId: widget.dashboardId,
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

class DaysSegment extends StatelessWidget {
  const DaysSegment(this.days, {super.key});

  final String days;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Text(
        days,
        style: segmentItemStyle,
      ),
    );
  }
}

class DashboardWidget extends StatelessWidget {
  const DashboardWidget({
    super.key,
    required this.dashboard,
    required this.rangeStart,
    required this.rangeEnd,
    required this.dashboardId,
    this.showTitle = false,
  });

  final DashboardDefinition dashboard;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String dashboardId;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final items = dashboard.items.map((DashboardItem dashboardItem) {
      return dashboardItem.map(
        measurement: (DashboardMeasurementItem measurement) {
          return DashboardMeasurablesChart(
            measurableDataTypeId: measurement.id,
            dashboardId: dashboardId,
            aggregationType: measurement.aggregationType,
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
        wildcardStoryTimeChart: (WildcardStoryTimeItem storyChart) {
          return Column(
            children: [
              WildcardStoryChart(
                chartConfig: storyChart,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
              const SizedBox(height: 10),
              WildcardStoryWeeklyChart(
                chartConfig: storyChart,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
            ],
          );
        },
        surveyChart: (DashboardSurveyItem surveyChart) {
          return DashboardSurveyChart(
            chartConfig: surveyChart,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );
        },
        habitChart: (DashboardHabitItem habitItem) {
          return DashboardHabitsChart(
            habitId: habitItem.habitId,
            dashboardId: dashboardId,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );
        },
      );
    });

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          if (showTitle)
            Text(
              dashboard.name,
              style: taskTitleStyle(),
            ),
          ...intersperse(const SizedBox(height: 16), items),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    dashboard.description,
                    style: chartTitleStyle(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.dashboard_customize_outlined),
                color: styleConfig().primaryTextColor,
                hoverColor: Colors.transparent,
                onPressed: () =>
                    beamToNamed('/settings/dashboards/$dashboardId'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
