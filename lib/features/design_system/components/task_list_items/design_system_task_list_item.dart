import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Priority level for a task list item.
enum DesignSystemTaskPriority {
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
class DesignSystemTaskListItem extends StatefulWidget {
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
  State<DesignSystemTaskListItem> createState() =>
      _DesignSystemTaskListItemState();
}

class _DesignSystemTaskListItemState extends State<DesignSystemTaskListItem> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant DesignSystemTaskListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forcedState != widget.forcedState ||
        (oldWidget.onTap == null) != (widget.onTap == null)) {
      _hovered = false;
      _pressed = false;
    }
  }

  DesignSystemTaskListItemVisualState _resolveVisualState() {
    if (widget.forcedState != null) return widget.forcedState!;
    if (_pressed) return DesignSystemTaskListItemVisualState.pressed;
    if (_hovered) return DesignSystemTaskListItemVisualState.hover;
    return DesignSystemTaskListItemVisualState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _TaskListItemSpec.fromTokens(tokens);
    final enabled = widget.onTap != null;
    final visualState = _resolveVisualState();

    final backgroundColor = switch (visualState) {
      DesignSystemTaskListItemVisualState.idle => Colors.transparent,
      DesignSystemTaskListItemVisualState.hover =>
        tokens.colors.surface.selected,
      DesignSystemTaskListItemVisualState.pressed =>
        tokens.colors.surface.focusPressed,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(color: backgroundColor),
            child: InkWell(
              onTap: widget.onTap,
              onHover: widget.forcedState == null && enabled
                  ? (value) => setState(() => _hovered = value)
                  : null,
              onHighlightChanged: widget.forcedState == null && enabled
                  ? (value) => setState(() => _pressed = value)
                  : null,
              child: Semantics(
                button: widget.onTap != null,
                label: widget.semanticsLabel,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spec.horizontalPadding,
                    vertical: spec.verticalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopRow(
                        title: widget.title,
                        category: widget.category,
                        status: widget.status,
                        statusLabel: widget.statusLabel,
                        spec: spec,
                        tokens: tokens,
                      ),
                      SizedBox(height: spec.rowGap),
                      _BottomRow(
                        priority: widget.priority,
                        timeRange: widget.timeRange,
                        spec: spec,
                        tokens: tokens,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: tokens.colors.decorative.level01,
          ),
      ],
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.spec,
    required this.tokens,
    this.category,
  });

  final String title;
  final DesignSystemTaskCategory? category;
  final DesignSystemTaskStatus status;
  final String statusLabel;
  final _TaskListItemSpec spec;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
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
          ),
        ),
        SizedBox(width: spec.itemGap),
        _StatusIndicator(
          status: status,
          statusLabel: statusLabel,
          spec: spec,
          tokens: tokens,
        ),
      ],
    );
  }
}

class _BottomRow extends StatelessWidget {
  const _BottomRow({
    required this.priority,
    required this.spec,
    required this.tokens,
    this.timeRange,
  });

  final DesignSystemTaskPriority priority;
  final String? timeRange;
  final _TaskListItemSpec spec;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PriorityIndicator(
          priority: priority,
          spec: spec,
          tokens: tokens,
        ),
        if (timeRange != null) ...[
          SizedBox(width: spec.metaGap),
          Icon(
            Icons.access_time,
            size: spec.metaIconSize,
            color: tokens.colors.text.mediumEmphasis,
          ),
          SizedBox(width: spec.metaIconGap),
          Text(
            timeRange!,
            style: spec.metaStyle,
          ),
        ],
      ],
    );
  }
}

class _PriorityIndicator extends StatelessWidget {
  const _PriorityIndicator({
    required this.priority,
    required this.spec,
    required this.tokens,
  });

  final DesignSystemTaskPriority priority;
  final _TaskListItemSpec spec;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (priority) {
      DesignSystemTaskPriority.p1 => (
        tokens.colors.alert.error.defaultColor,
        'P1',
      ),
      DesignSystemTaskPriority.p2 => (
        tokens.colors.alert.warning.defaultColor,
        'P2',
      ),
      DesignSystemTaskPriority.p3 => (
        tokens.colors.text.mediumEmphasis,
        'P3',
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: spec.priorityDotSize,
          color: color,
        ),
        SizedBox(width: spec.metaIconGap),
        Text(
          label,
          style: spec.metaStyle.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
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
      DesignSystemTaskStatus.blocked => Icons.warning_amber,
      DesignSystemTaskStatus.onHold => Icons.remove_circle_outline,
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
        SizedBox(width: spec.metaIconGap),
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
      statusIconSize: tokens.typography.lineHeight.caption,
      titleStyle: tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
      metaStyle: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
      statusStyle: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
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
  final TextStyle titleStyle;
  final TextStyle metaStyle;
  final TextStyle statusStyle;
}
