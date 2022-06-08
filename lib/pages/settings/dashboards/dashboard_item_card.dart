import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_item_modal.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DashboardItemCard extends StatelessWidget {
  final TagsService tagsService = getIt<TagsService>();
  final DashboardItem item;
  final int index;
  final List<MeasurableDataType> measurableTypes;
  final void Function(DashboardItem item, int index) updateItemFn;

  DashboardItemCard({
    Key? key,
    required this.index,
    required this.item,
    required this.measurableTypes,
    required this.updateItemFn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String itemName = item.map(
      measurement: (measurement) {
        Iterable<MeasurableDataType> matches =
            measurableTypes.where((m) => measurement.id == m.id);
        if (matches.isNotEmpty) {
          AggregationType? aggregationType = measurement.aggregationType;
          String aggregationTypeLabel = aggregationType != null
              ? '[${EnumToString.convertToString(measurement.aggregationType)}]'
              : '';
          return '${matches.first.displayName} $aggregationTypeLabel';
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
      storyTimeChart: (DashboardStoryTimeItem item) {
        TagEntity? tagEntity = tagsService.getTagById(item.storyTagId);
        return tagEntity?.tag ?? item.storyTagId;
      },
    );

    return Card(
      color: AppColors.headerBgColor,
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
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
          storyTimeChart: (_) => Icon(
            MdiIcons.bookOutline,
            size: 32,
            color: AppColors.entryTextColor,
          ),
        ),
        title: Text(
          itemName,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 20.0,
          ),
        ),
        enabled: true,
      ),
    );
  }
}
