import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// Single chip row holding actionable metadata + the right-pinned status
/// pill. On wide viewports the chips wrap on the left and status sits at
/// the far right; below the breakpoint the chips wrap above and status
/// drops to its own right-aligned line.
class MetaRow extends StatelessWidget {
  const MetaRow({
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.labels,
    required this.estimateSlot,
    required this.onPriorityTap,
    required this.onStatusTap,
    required this.onDueDateTap,
    required this.onLabelTap,
    required this.onAddLabelTap,
    super.key,
  });

  final TaskPriority priority;
  final TaskStatus status;
  final DesktopTaskHeaderDueDate? dueDate;
  final List<LabelDefinition> labels;
  final Widget? estimateSlot;
  final VoidCallback? onPriorityTap;
  final VoidCallback? onStatusTap;
  final VoidCallback? onDueDateTap;
  final ValueChanged<LabelDefinition>? onLabelTap;
  final VoidCallback? onAddLabelTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final children = <Widget>[
      _PriorityPillTinted(priority: priority, onTap: onPriorityTap),
      _DuePill(dueDate: dueDate, onTap: onDueDateTap),
      ?estimateSlot,
      if (labels.isEmpty)
        DsGhostChip(
          label: context.messages.tasksAddLabelButton,
          onTap: onAddLabelTap,
        )
      else
        for (final label in labels)
          _LabelPill(
            label: label,
            onTap: onLabelTap == null ? null : () => onLabelTap!(label),
          ),
    ];

    return TrailingAlignedWrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        ...children,
        _StatusPill(status: status, onTap: onStatusTap),
      ],
    );
  }
}

class _PriorityPillTinted extends StatelessWidget {
  const _PriorityPillTinted({required this.priority, this.onTap});

  final TaskPriority priority;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      TaskPriority.p0Urgent => TaskShowcasePalette.error(context),
      TaskPriority.p1High => TaskShowcasePalette.warning(context),
      TaskPriority.p2Medium => TaskShowcasePalette.info(context),
      TaskPriority.p3Low => TaskShowcasePalette.success(context),
    };
    return DsPill(
      variant: DsPillVariant.tinted,
      color: color,
      label: priority.short,
      leading: TaskShowcasePriorityGlyph(priority: priority, size: 14),
      onTap: onTap,
    );
  }
}

class _DuePill extends StatelessWidget {
  const _DuePill({required this.dueDate, this.onTap});

  final DesktopTaskHeaderDueDate? dueDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dueDate = this.dueDate;
    if (dueDate == null) {
      return DsPill(
        variant: DsPillVariant.muted,
        label: context.messages.taskNoDueDateLabel,
        leading: Icon(
          Icons.calendar_today_outlined,
          size: 12,
          color: TaskShowcasePalette.lowText(context),
        ),
        onTap: onTap,
      );
    }
    final color = switch (dueDate.urgency) {
      DesktopTaskHeaderDueUrgency.overdue => TaskShowcasePalette.error(context),
      DesktopTaskHeaderDueUrgency.today => TaskShowcasePalette.warning(context),
      DesktopTaskHeaderDueUrgency.normal => TaskShowcasePalette.mediumText(
        context,
      ),
    };
    return DsPill(
      variant: DsPillVariant.outline,
      color: color,
      label: dueDate.label,
      leading: Icon(Icons.calendar_today_outlined, size: 12, color: color),
      onTap: onTap,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.onTap});

  final TaskStatus status;
  final VoidCallback? onTap;

  static const double _height = 32;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tint = _statusTint(context, status);
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final label = status.localizedLabel(context);
    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: tint.foreground,
      height: 1,
      decoration: status is TaskRejected ? TextDecoration.lineThrough : null,
    );
    final content = SizedBox(
      height: _height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TaskShowcaseStatusGlyph(status: status, size: 14),
            SizedBox(width: tokens.spacing.step2),
            Text(label, style: labelStyle),
            SizedBox(width: tokens.spacing.step2),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: TaskShowcasePalette.lowText(context),
            ),
          ],
        ),
      ),
    );
    final shaped = DecoratedBox(
      decoration: BoxDecoration(
        color: tint.background,
        borderRadius: radius,
      ),
      child: content,
    );
    if (onTap == null) return shaped;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: shaped,
      ),
    );
  }
}

class _StatusTint {
  const _StatusTint({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

_StatusTint _statusTint(BuildContext context, TaskStatus status) {
  return switch (status) {
    TaskInProgress() => _tintFromAccent(
      TaskShowcasePalette.info(context),
      bgAlpha: 0.18,
    ),
    TaskBlocked() => _tintFromAccent(
      TaskShowcasePalette.error(context),
      bgAlpha: 0.18,
    ),
    TaskOnHold() => _tintFromAccent(
      TaskShowcasePalette.warning(context),
      bgAlpha: 0.18,
    ),
    TaskGroomed() => _tintFromAccent(
      context.designTokens.colors.interactive.enabled,
      bgAlpha: 0.18,
    ),
    TaskDone() => _tintFromAccent(
      TaskShowcasePalette.success(context),
      bgAlpha: 0.18,
    ),
    TaskRejected() => _StatusTint(
      background: TaskShowcasePalette.lowText(
        context,
      ).withValues(alpha: 0.14),
      foreground: TaskShowcasePalette.lowText(context),
    ),
    TaskOpen() => _StatusTint(
      background: TaskShowcasePalette.mediumText(
        context,
      ).withValues(alpha: 0.12),
      foreground: TaskShowcasePalette.highText(context),
    ),
  };
}

_StatusTint _tintFromAccent(Color accent, {required double bgAlpha}) {
  return _StatusTint(
    background: accent.withValues(alpha: bgAlpha),
    foreground: accent,
  );
}

/// 8px circle filled with the label's own color. Used as the leading dot in
/// label pills so the label color stays visible while the chip text remains
/// high-emphasis.
class _LabelDot extends StatelessWidget {
  const _LabelDot({required this.color});

  final String color;

  @override
  Widget build(BuildContext context) {
    final fillColor = colorFromCssHex(
      color,
      substitute: TaskShowcasePalette.mediumText(context),
    );
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Label-specific pill: a filled `DsPill` with the label's color dot, and a
/// long-press dialog showing the label description (when one is set). The
/// long-press affordance was carried over from the previous classification
/// row where label descriptions weren't otherwise reachable.
class _LabelPill extends StatelessWidget {
  const _LabelPill({required this.label, this.onTap});

  final LabelDefinition label;
  final VoidCallback? onTap;

  bool get _hasDescription {
    final description = label.description?.trim();
    return description != null && description.isNotEmpty;
  }

  Future<void> _showDescription(BuildContext context) async {
    final description = label.description?.trim();
    if (description == null || description.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label.name),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.messages.tasksLabelsDialogClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DsPill(
      variant: DsPillVariant.filled,
      label: label.name,
      leading: _LabelDot(color: label.color),
      onTap: onTap,
      onLongPress: _hasDescription ? () => _showDescription(context) : null,
    );
  }
}
