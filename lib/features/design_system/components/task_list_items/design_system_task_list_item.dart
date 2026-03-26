import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Priority level for a task list item.
///
/// [p0] is the highest priority (urgent/critical).
enum DesignSystemTaskPriority {
  p0,
  p1,
  p2,
  p3,
}

/// Status of a task list item.
enum DesignSystemTaskStatus {
  open,
  blocked,
  onHold,
}

/// Visual interaction state for forced preview (e.g. widgetbook).
enum DesignSystemTaskListItemVisualState {
  idle,
  hover,
  pressed,
}

/// A category badge displayed alongside the task title.
class DesignSystemTaskCategory {
  const DesignSystemTaskCategory({
    required this.label,
    this.badgeTone = DesignSystemBadgeTone.primary,
  });

  final String label;
  final DesignSystemBadgeTone badgeTone;
}

/// A task list item showing title, category, priority, time range, and status.
///
/// Designed to be stacked in a list with dividers between items.
class DesignSystemTaskListItem extends StatelessWidget {
  const DesignSystemTaskListItem({
    required this.title,
    required this.priority,
    required this.status,
    required this.statusLabel,
    this.category,
    this.timeRange,
    this.onTap,
    this.showDivider = false,
    this.forcedState,
    this.semanticsLabel,
    super.key,
  });

  final String title;
  final DesignSystemTaskPriority priority;
  final DesignSystemTaskStatus status;
  final String statusLabel;
  final DesignSystemTaskCategory? category;
  final String? timeRange;
  final VoidCallback? onTap;
  final bool showDivider;
  final DesignSystemTaskListItemVisualState? forcedState;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _TaskListItemSpec.fromTokens(tokens);
    return DesignSystemListItem(
      titleContent: _TaskTitleContent(
        title: title,
        category: category,
        spec: spec,
      ),
      subtitleSpans: _taskMetadataSpans(
        priority: priority,
        timeRange: timeRange,
        spec: spec,
        tokens: tokens,
      ),
      trailing: _StatusIndicator(
        status: status,
        statusLabel: statusLabel,
        spec: spec,
        tokens: tokens,
      ),
      showDivider: showDivider,
      onTap: onTap,
      semanticsLabel: semanticsLabel,
      forcedState: switch (forcedState) {
        DesignSystemTaskListItemVisualState.idle =>
          DesignSystemListItemVisualState.idle,
        DesignSystemTaskListItemVisualState.hover =>
          DesignSystemListItemVisualState.hover,
        DesignSystemTaskListItemVisualState.pressed =>
          DesignSystemListItemVisualState.pressed,
        null => null,
      },
      hoverBackgroundColor: tokens.colors.surface.selected,
      pressedBackgroundColor: tokens.colors.surface.focusPressed,
    );
  }
}

class _TaskTitleContent extends StatelessWidget {
  const _TaskTitleContent({
    required this.title,
    required this.spec,
    this.category,
  });

  final String title;
  final DesignSystemTaskCategory? category;
  final _TaskListItemSpec spec;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: spec.titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (category != null) ...[
          SizedBox(width: spec.itemGap),
          DesignSystemBadge.filled(
            label: category!.label,
            tone: category!.badgeTone,
          ),
        ],
      ],
    );
  }
}

List<InlineSpan> _taskMetadataSpans({
  required DesignSystemTaskPriority priority,
  required _TaskListItemSpec spec,
  required DsTokens tokens,
  String? timeRange,
}) {
  final (
    priorityColor,
    priorityLabel,
    priorityIcon,
    iconSize,
  ) = switch (priority) {
    DesignSystemTaskPriority.p0 => (
      tokens.colors.alert.error.defaultColor,
      'P0',
      Icons.priority_high_rounded,
      spec.metaIconSize,
    ),
    DesignSystemTaskPriority.p1 => (
      tokens.colors.alert.error.defaultColor,
      'P1',
      Icons.local_fire_department_rounded,
      spec.metaIconSize,
    ),
    DesignSystemTaskPriority.p2 => (
      tokens.colors.alert.warning.defaultColor,
      'P2',
      Icons.circle,
      spec.priorityDotSize,
    ),
    DesignSystemTaskPriority.p3 => (
      tokens.colors.text.mediumEmphasis,
      'P3',
      Icons.circle,
      spec.priorityDotSize,
    ),
  };

  return [
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(
        priorityIcon,
        size: iconSize,
        color: priorityColor,
      ),
    ),
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: SizedBox(width: spec.metaIconGap),
    ),
    TextSpan(
      text: priorityLabel,
      style: spec.metaStyle.copyWith(
        color: priorityColor,
        fontWeight: tokens.typography.weight.semiBold,
      ),
    ),
    if (timeRange != null) ...[
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(width: spec.metaGap),
      ),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(
          Icons.access_time,
          size: spec.metaIconSize,
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(width: spec.metaIconGap),
      ),
      TextSpan(
        text: timeRange,
        style: spec.metaStyle,
      ),
    ],
  ];
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.status,
    required this.statusLabel,
    required this.spec,
    required this.tokens,
  });

  final DesignSystemTaskStatus status;
  final String statusLabel;
  final _TaskListItemSpec spec;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      DesignSystemTaskStatus.open => Icons.circle_outlined,
      DesignSystemTaskStatus.blocked => Icons.warning_amber_rounded,
      DesignSystemTaskStatus.onHold => Icons.pause_rounded,
    };

    final iconColor = switch (status) {
      DesignSystemTaskStatus.blocked =>
        tokens.colors.alert.warning.defaultColor,
      _ => tokens.colors.text.mediumEmphasis,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: spec.statusIconSize, color: iconColor),
        SizedBox(width: spec.statusIconGap),
        Text(
          statusLabel,
          style: spec.statusStyle,
        ),
      ],
    );
  }
}

class _TaskListItemSpec {
  const _TaskListItemSpec({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.rowGap,
    required this.itemGap,
    required this.metaGap,
    required this.metaIconGap,
    required this.metaIconSize,
    required this.priorityDotSize,
    required this.statusIconSize,
    required this.statusIconGap,
    required this.titleStyle,
    required this.metaStyle,
    required this.statusStyle,
  });

  factory _TaskListItemSpec.fromTokens(DsTokens tokens) {
    return _TaskListItemSpec(
      horizontalPadding: tokens.spacing.step5,
      verticalPadding: tokens.spacing.step4,
      rowGap: tokens.spacing.step2,
      itemGap: tokens.spacing.step3,
      metaGap: tokens.spacing.step5,
      metaIconGap: tokens.spacing.step1,
      metaIconSize: tokens.typography.lineHeight.caption,
      priorityDotSize: tokens.spacing.step3,
      statusIconSize: tokens.spacing.step5,
      statusIconGap: tokens.spacing.step2,
      titleStyle: tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
      metaStyle: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
      statusStyle: tokens.typography.styles.body.bodyMedium.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
  }

  final double horizontalPadding;
  final double verticalPadding;
  final double rowGap;
  final double itemGap;
  final double metaGap;
  final double metaIconGap;
  final double metaIconSize;
  final double priorityDotSize;
  final double statusIconSize;
  final double statusIconGap;
  final TextStyle titleStyle;
  final TextStyle metaStyle;
  final TextStyle statusStyle;
}
