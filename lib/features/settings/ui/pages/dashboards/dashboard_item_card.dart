import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/config/dashboard_workout_config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/dashboard_item_modal.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DashboardItemCard extends StatelessWidget {
  DashboardItemCard({
    required this.index,
    required this.item,
    required this.updateItemFn,
    super.key,
  });

  final TagsService tagsService = getIt<TagsService>();
  final DashboardItem item;
  final int index;

  final void Function(DashboardItem item, int index) updateItemFn;

  @override
  Widget build(BuildContext context) {
    return item.map(
      measurement: (measurement) {
        return MeasurableItemCard(
          measurement: measurement,
          updateItemFn: updateItemFn,
          index: index,
        );
      },
      healthChart: (healthLineChart) {
        final type = healthLineChart.healthType;
        final itemName = healthTypes[type]?.displayName ?? type;
        return ItemCard(
          leadingIcon: MdiIcons.stethoscope,
          title: itemName,
        );
      },
      workoutChart: (workoutChart) {
        final workoutKey =
            '${workoutChart.workoutType}.${workoutChart.valueType.name}';
        final workoutType = workoutTypes[workoutKey];

        return ItemCard(
          leadingIcon: Icons.sports_gymnastics,
          title: workoutType?.displayName ?? workoutChart.displayName,
        );
      },
      surveyChart: (surveyChart) {
        return ItemCard(
          leadingIcon: MdiIcons.clipboardOutline,
          title: surveyChart.surveyName,
        );
      },
      habitChart: (habitItem) {
        return HabitItemCard(
          habitItem: habitItem,
        );
      },
      storyTimeChart: (item) {
        final tagEntity = tagsService.getTagById(item.storyTagId);
        return ItemCard(
          leadingIcon: MdiIcons.bookOutline,
          title: tagEntity?.tag ?? item.storyTagId,
        );
      },
      wildcardStoryTimeChart: (item) {
        return ItemCard(
          leadingIcon: MdiIcons.bookshelf,
          title: item.storySubstring,
        );
      },
    );
  }
}

class MeasurableItemCard extends StatelessWidget {
  const MeasurableItemCard({
    required this.measurement,
    required this.updateItemFn,
    required this.index,
    super.key,
  });

  final DashboardMeasurementItem measurement;
  final void Function(DashboardItem item, int index) updateItemFn;
  final int index;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MeasurableDataType>>(
      stream: getIt<JournalDb>().watchMeasurableDataTypes(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType>> snapshot,
      ) {
        final measurableTypes = snapshot.data ?? [];

        final matches = measurableTypes.where((m) => measurement.id == m.id);
        var title = '';
        if (matches.isNotEmpty) {
          final aggregationType = measurement.aggregationType;
          final aggregationTypeLabel = aggregationType != null
              ? ' [${EnumToString.convertToString(measurement.aggregationType)}]'
              : '';
          title = '${matches.first.displayName}$aggregationTypeLabel';
        }
        return ItemCard(
          leadingIcon: Icons.insights,
          title: title,
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              builder: (BuildContext context) {
                return DashboardItemModal(
                  item: measurement,
                  updateItemFn: updateItemFn,
                  title: title,
                  index: index,
                );
              },
            );
            updateItemFn(measurement, index);
          },
        );
      },
    );
  }
}

class HabitItemCard extends StatelessWidget {
  const HabitItemCard({
    required this.habitItem,
    super.key,
  });

  final DashboardHabitItem habitItem;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HabitDefinition?>(
      stream: getIt<JournalDb>().watchHabitById(habitItem.habitId),
      builder: (
        BuildContext context,
        AsyncSnapshot<HabitDefinition?> snapshot,
      ) {
        final habitDefinition = snapshot.data;

        return ItemCard(
          leadingIcon: MdiIcons.lightningBolt,
          title: habitDefinition?.name ?? habitItem.habitId,
        );
      },
    );
  }
}

class ItemCard extends StatelessWidget {
  const ItemCard({
    required this.title,
    required this.leadingIcon,
    this.onTap,
    super.key,
  });

  final void Function()? onTap;
  final String title;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        tileColor: context.colorScheme.secondaryContainer,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 16,
        ),
        leading: Icon(
          leadingIcon,
          size: 32,
          color: context.colorScheme.onSecondaryContainer,
        ),
        title: Text(
          title,
          softWrap: true,
          style: TextStyle(color: context.colorScheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
