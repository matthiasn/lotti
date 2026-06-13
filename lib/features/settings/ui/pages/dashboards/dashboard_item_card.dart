import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/config/dashboard_workout_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/aggregation_label.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/widgets/charts/dashboard_item_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class DashboardItemCard extends StatelessWidget {
  const DashboardItemCard({
    required this.index,
    required this.item,
    required this.updateItemFn,
    super.key,
  });

  final DashboardItem item;
  final int index;

  final void Function(DashboardItem item, int index) updateItemFn;

  @override
  Widget build(BuildContext context) {
    switch (item) {
      case final DashboardMeasurementItem measurement:
        return MeasurableItemCard(
          measurement: measurement,
          updateItemFn: updateItemFn,
          index: index,
        );
      case DashboardHealthItem(:final healthType):
        final type = healthType;
        final itemName = healthTypes[type]?.displayName ?? type;
        return ItemCard(
          leadingIcon: MdiIcons.stethoscope,
          title: itemName,
        );
      case DashboardWorkoutItem(:final workoutType, :final valueType):
        final workoutKey = '$workoutType.${valueType.name}';
        final workout = workoutTypes[workoutKey];
        return ItemCard(
          leadingIcon: Icons.sports_gymnastics,
          title: workout?.displayName ?? workoutKey,
        );
      case DashboardSurveyItem(:final surveyName):
        return ItemCard(
          leadingIcon: MdiIcons.clipboardOutline,
          title: surveyName,
        );
      case final DashboardHabitItem habitItem:
        return HabitItemCard(
          habitItem: habitItem,
        );
    }
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
      stream: notificationDrivenStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {measurablesNotification, privateToggleNotification},
        fetcher: getIt<JournalDb>().getAllMeasurableDataTypes,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<MeasurableDataType>> snapshot,
          ) {
            final measurableTypes = snapshot.data ?? [];

            final matches = measurableTypes.where(
              (m) => measurement.id == m.id,
            );
            // Fall back to the id when the referenced measurable type is
            // missing (e.g. deleted) so the row isn't visually blank.
            var title = measurement.id;
            if (matches.isNotEmpty) {
              final aggregationType = measurement.aggregationType;
              final aggregationSuffix = aggregationType != null
                  ? ' — ${aggregationTypeLabel(context.messages, aggregationType)}'
                  : '';
              title = '${matches.first.displayName}$aggregationSuffix';
            }
            return ItemCard(
              leadingIcon: Icons.insights,
              title: title,
              onTap: () {
                ModalUtils.showBottomSheet<void>(
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
      stream: notificationDrivenItemStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {habitsNotification, privateToggleNotification},
        fetcher: () => getIt<JournalDb>().getHabitById(habitItem.habitId),
      ),
      builder:
          (
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

/// Reorderable chart row in the dashboard editor's Charts section.
///
/// Rendered in the settings design language — `background.level03` fill,
/// `radii.s` corners, medium-emphasis leading glyph, body text title — with
/// an explicit low-emphasis drag handle so the reorderable affordance is
/// visible instead of implied.
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
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final radius = BorderRadius.circular(tokens.radii.s);

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.step2),
      child: Material(
        color: tokens.colors.background.level03,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.step4,
              vertical: spacing.step3,
            ),
            child: Row(
              children: [
                Icon(
                  leadingIcon,
                  size: spacing.step6,
                  color: tokens.colors.text.mediumEmphasis,
                ),
                SizedBox(width: spacing.step3),
                Expanded(
                  child: Text(
                    title,
                    softWrap: true,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                SizedBox(width: spacing.step3),
                Icon(
                  Icons.drag_indicator,
                  size: spacing.step5,
                  color: tokens.colors.text.lowEmphasis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
