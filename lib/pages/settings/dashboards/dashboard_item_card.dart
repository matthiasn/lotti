import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_item_modal.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DashboardItemCard extends StatelessWidget {
  DashboardItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.measurableTypes,
    required this.updateItemFn,
  });

  final TagsService tagsService = getIt<TagsService>();
  final DashboardItem item;
  final int index;
  final List<MeasurableDataType> measurableTypes;
  final void Function(DashboardItem item, int index) updateItemFn;

  @override
  Widget build(BuildContext context) {
    final itemName = item.map(
      measurement: (measurement) {
        final matches = measurableTypes.where((m) => measurement.id == m.id);
        if (matches.isNotEmpty) {
          final aggregationType = measurement.aggregationType;
          final aggregationTypeLabel = aggregationType != null
              ? ' [${EnumToString.convertToString(measurement.aggregationType)}]'
              : '';
          return '${matches.first.displayName}$aggregationTypeLabel';
        }
        return '';
      },
      healthChart: (healthLineChart) {
        final type = healthLineChart.healthType;
        final itemName = healthTypes[type]?.displayName ?? type;
        return itemName;
      },
      surveyChart: (surveyChart) {
        return surveyChart.surveyName;
      },
      workoutChart: (workoutChart) {
        return workoutChart.displayName;
      },
      storyTimeChart: (DashboardStoryTimeItem item) {
        final tagEntity = tagsService.getTagById(item.storyTagId);
        return tagEntity?.tag ?? item.storyTagId;
      },
    );

    return Card(
      color: colorConfig().headerBgColor,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: () {
          if (item is DashboardMeasurementItem) {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              builder: (BuildContext context) {
                return DashboardItemModal(
                  item: item as DashboardMeasurementItem,
                  updateItemFn: updateItemFn,
                  title: itemName,
                  index: index,
                );
              },
            );
            updateItemFn(item, index);
          }
        },
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 16,
        ),
        leading: item.map(
          measurement: (_) => Icon(
            Icons.insights,
            size: 32,
            color: colorConfig().entryTextColor,
          ),
          healthChart: (_) => Icon(
            MdiIcons.stethoscope,
            size: 32,
            color: colorConfig().entryTextColor,
          ),
          workoutChart: (_) => Icon(
            Icons.sports_gymnastics,
            size: 32,
            color: colorConfig().entryTextColor,
          ),
          surveyChart: (_) => Icon(
            MdiIcons.clipboardOutline,
            size: 32,
            color: colorConfig().entryTextColor,
          ),
          storyTimeChart: (_) => Icon(
            MdiIcons.bookOutline,
            size: 32,
            color: colorConfig().entryTextColor,
          ),
        ),
        title: Text(
          itemName,
          style: TextStyle(
            color: colorConfig().entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}
