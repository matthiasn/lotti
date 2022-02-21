import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_barchart.dart';

class DashboardViewerRoute extends StatelessWidget {
  const DashboardViewerRoute({
    Key? key,
    required this.dashboard,
  }) : super(key: key);

  final DashboardDefinition dashboard;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: AppColors.headerBgColor,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      ...dashboard.items.map(
                        (DashboardItem e) => DashboardBarChart(
                          measurableDataTypeId: e.id,
                        ),
                      ),
                      Text(
                        dashboard.description,
                        style: formLabelStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
