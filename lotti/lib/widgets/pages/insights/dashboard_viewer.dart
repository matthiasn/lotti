import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_barchart.dart';
import 'package:lotti/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardViewerRoute extends StatelessWidget {
  const DashboardViewerRoute({
    Key? key,
    required this.dashboard,
  }) : super(key: key);

  final DashboardDefinition dashboard;

  @override
  Widget build(BuildContext context) {
    final DateTime rangeStart = getRangeStart(context);
    final DateTime rangeEnd = getRangeEnd();

    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: AppBar(
        foregroundColor: AppColors.appBarFgColor,
        title: Text(
          dashboard.name,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
          ),
        ),
        backgroundColor: AppColors.headerBgColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              ...dashboard.items.map((DashboardItem dashboardItem) {
                return dashboardItem.map(
                  measurement: (DashboardMeasurementItem measurement) {
                    return DashboardBarChart(
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
                );
              }),
              Text(
                dashboard.description,
                style: formLabelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
