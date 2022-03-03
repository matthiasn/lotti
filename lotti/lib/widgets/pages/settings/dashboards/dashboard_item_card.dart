import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DashboardItemCard extends StatelessWidget {
  final DashboardItem item;
  final List<MeasurableDataType> measurableTypes;

  const DashboardItemCard({
    Key? key,
    required this.item,
    required this.measurableTypes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String itemName = item.map(
      measurement: (measurement) {
        Iterable<MeasurableDataType> matches =
            measurableTypes.where((m) => measurement.id == m.id);
        if (matches.isNotEmpty) {
          return matches.first.displayName;
        }
        return '';
      },
      healthChart: (healthLineChart) {
        String type = healthLineChart.healthType;
        String itemName = healthTypes[type]?.displayName ?? type;
        return itemName;
      },
      surveyChart: (surveyChart) {
        return surveyChart.surveyName;
      },
      workoutChart: (workoutChart) {
        return workoutChart.displayName;
      },
    );

    return Card(
      color: AppColors.headerBgColor,
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 16,
        ),
        leading: item.map(
          measurement: (_) => Icon(
            MdiIcons.tapeMeasure,
            size: 32,
            color: AppColors.entryTextColor,
          ),
          healthChart: (_) => Icon(
            MdiIcons.stethoscope,
            size: 32,
            color: AppColors.entryTextColor,
          ),
          workoutChart: (_) => Icon(
            Icons.sports_gymnastics,
            size: 32,
            color: AppColors.entryTextColor,
          ),
          surveyChart: (_) => Icon(
            MdiIcons.clipboardOutline,
            size: 32,
            color: AppColors.entryTextColor,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              itemName,
              style: TextStyle(
                color: AppColors.entryTextColor,
                fontFamily: 'Oswald',
                fontSize: 20.0,
              ),
            ),
          ],
        ),
        enabled: true,
      ),
    );
  }
}
