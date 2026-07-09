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

/// Renders one chart row in the dashboard editor, dispatching on the
/// [DashboardItem] variant.
///
/// Measurement and habit items resolve their display name from the database
/// (so they stay editable / reorderable) via [MeasurableItemCard] /
/// [HabitItemCard]; health, workout, and survey items resolve from the
/// static config maps and render a read-only [ItemCard]. [updateItemFn] is
/// invoked with the edited item + [index] when a measurement row's modal
/// changes its aggregation.
class DashboardItemCard extends StatelessWidget {
  const DashboardItemCard({
    required this.index,
    required this.item,
    required this.updateItemFn,
    this.removeItemFn,
    super.key,
  });

  final DashboardItem item;
  final int index;

  final void Function(DashboardItem item, int index) updateItemFn;
  final VoidCallback? removeItemFn;

  @override
  Widget build(BuildContext context) {
    switch (item) {
      case final DashboardMeasurementItem measurement:
        return MeasurableItemCard(
          measurement: measurement,
          updateItemFn: updateItemFn,
          index: index,
          onRemove: removeItemFn,
        );
      case DashboardHealthItem(:final healthType):
        final type = healthType;
        final itemName = healthTypes[type]?.displayName ?? type;
        return ItemCard(
          leadingIcon: MdiIcons.stethoscope,
          title: itemName,
          reorderIndex: index,
          onRemove: removeItemFn,
        );
      case DashboardWorkoutItem(:final workoutType, :final valueType):
        final workoutKey = '$workoutType.${valueType.name}';
        final workout = workoutTypes[workoutKey];
        return ItemCard(
          leadingIcon: Icons.sports_gymnastics,
          title: workout?.displayName ?? workoutKey,
          reorderIndex: index,
          onRemove: removeItemFn,
        );
      case DashboardSurveyItem(:final surveyName):
        return ItemCard(
          leadingIcon: MdiIcons.clipboardOutline,
          title: surveyName,
          reorderIndex: index,
          onRemove: removeItemFn,
        );
      case final DashboardHabitItem habitItem:
        return HabitItemCard(
          habitItem: habitItem,
          index: index,
          onRemove: removeItemFn,
        );
    }
  }
}

/// Chart row for a measurement item. Looks up the referenced
/// [MeasurableDataType] to show its display name plus the aggregation suffix
/// (falling back to the raw id when the type was deleted), and opens the
/// aggregation-editing modal on tap.
class MeasurableItemCard extends StatelessWidget {
  const MeasurableItemCard({
    required this.measurement,
    required this.updateItemFn,
    required this.index,
    this.onRemove,
    super.key,
  });

  final DashboardMeasurementItem measurement;
  final void Function(DashboardItem item, int index) updateItemFn;
  final int index;
  final VoidCallback? onRemove;

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
              reorderIndex: index,
              onRemove: onRemove,
              editSemanticsLabel:
                  context.messages.dashboardEditAggregationLabel,
              onTap: () {
                ModalUtils.showSinglePageModal<void>(
                  context: context,
                  title: context.messages.dashboardAggregationTitle,
                  padding: EdgeInsets.all(
                    context.designTokens.spacing.cardPadding,
                  ),
                  builder: (BuildContext context) {
                    return DashboardItemModal(
                      item: measurement,
                      updateItemFn: updateItemFn,
                      index: index,
                      chartTitle: title,
                    );
                  },
                );
              },
            );
          },
    );
  }
}

/// Chart row for a habit item. Resolves the referenced habit's name from
/// the database (falling back to the raw habit id if it's gone).
class HabitItemCard extends StatelessWidget {
  const HabitItemCard({
    required this.habitItem,
    required this.index,
    this.onRemove,
    super.key,
  });

  final DashboardHabitItem habitItem;
  final int index;
  final VoidCallback? onRemove;

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
              reorderIndex: index,
              onRemove: onRemove,
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
    this.reorderIndex,
    this.onTap,
    this.onRemove,
    this.editSemanticsLabel,
    super.key,
  });

  final void Function()? onTap;
  final VoidCallback? onRemove;
  final String title;
  final IconData leadingIcon;
  final int? reorderIndex;
  final String? editSemanticsLabel;

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
                if (onTap != null) ...[
                  _ChartRowIconButton(
                    icon: Icons.tune_rounded,
                    color: tokens.colors.text.mediumEmphasis,
                    tooltip:
                        editSemanticsLabel ??
                        context.messages.dashboardAggregationTitle,
                    onPressed: onTap!,
                  ),
                  SizedBox(width: spacing.step2),
                ],
                if (onRemove != null) ...[
                  _ChartRowIconButton(
                    icon: Icons.close_rounded,
                    color: tokens.colors.alert.error.defaultColor,
                    tooltip: context.messages.dashboardRemoveChartLabel,
                    onPressed: onRemove!,
                  ),
                  SizedBox(width: spacing.step2),
                ],
                finalDragHandle(
                  Icons.drag_indicator,
                  index: reorderIndex,
                  size: spacing.step5,
                  targetSize: spacing.step8,
                  color: tokens.colors.text.mediumEmphasis,
                  semanticsLabel: context.messages.dashboardReorderChartLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget finalDragHandle(
    IconData icon, {
    required int? index,
    required double size,
    required double targetSize,
    required Color color,
    required String semanticsLabel,
  }) {
    final child = SizedBox.square(
      dimension: targetSize,
      child: Center(
        child: Icon(icon, size: size, color: color),
      ),
    );
    if (index == null) return child;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: ReorderableDragStartListener(
        index: index,
        child: child,
      ),
    );
  }
}

class _ChartRowIconButton extends StatelessWidget {
  const _ChartRowIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;

    return IconButton(
      icon: Icon(icon, color: color, size: spacing.step5),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: spacing.step8,
        minHeight: spacing.step8,
      ),
    );
  }
}
