import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/celebration/completion_celebration.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// Two-lane metadata block under the title. The first lane holds the
/// task's *structured attributes* led by the **status** pill — status,
/// priority, due date, time-estimate — and the second lane holds the
/// free-form **labels**. Both lanes pack left-to-right and wrap with a
/// consistent run spacing.
///
/// Status leads the attribute lane (rather than being pinned to a trailing
/// edge) so it has one stable, predictable home that never opens a horizontal
/// dead zone next to a short chip cluster and never gets marooned when the row
/// wraps. The due date and time-estimate are bonded into one wrap unit (see
/// [_timeGroup]) so the optional estimate can never strand alone on its own
/// near-empty wrap row. Separating attributes from labels gives the eye an
/// instant "what state / when / how big" read distinct from the user's own
/// taxonomy.
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
    // Inter-chip gap (step2 = 4) is kept deliberately tighter than each pill's
    // own internal horizontal padding (step3 = 8) so the chips read as one
    // anchored cluster rather than scattered tokens.
    final chipGap = tokens.spacing.step2;
    final attributes = <Widget>[
      TaskHeaderStatusPill(status: status, onTap: onStatusTap),
      _PriorityPill(priority: priority, onTap: onPriorityTap),
      _timeGroup(chipGap),
      // With no labels yet, the "Add Label" affordance rides the END of the
      // attribute lane rather than orphaning on its own near-empty second
      // line — the dedicated label lane only materialises once there is real
      // taxonomy to hold.
      if (labels.isEmpty)
        DsGhostChip(
          label: context.messages.tasksAddLabelButton,
          onTap: onAddLabelTap,
        ),
    ];
    final attributeLane = Wrap(
      spacing: chipGap,
      runSpacing: chipGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: attributes,
    );
    if (labels.isEmpty) return attributeLane;

    final labelLane = Wrap(
      spacing: chipGap,
      runSpacing: chipGap,
      children: <Widget>[
        for (final label in labels)
          _LabelPill(
            label: label,
            onTap: onLabelTap == null ? null : () => onLabelTap!(label),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        attributeLane,
        // The lane separation (step4 = 12) is a full "context break" step —
        // the same gap used between the breadcrumb and the title — so it reads
        // as a clearly larger rhythmic step than the intra-lane chip gutter
        // (step2 = 4). That vertical step alone signals the free-form label
        // taxonomy as a distinct register from the structured attributes above
        // it (rather than leaning only on the chips' colour dots), without
        // needing a divider.
        SizedBox(height: tokens.spacing.step4),
        labelLane,
      ],
    );
  }

  /// Bonds the two *time* attributes — the due date (**when**) and the optional
  /// time estimate (**how big**) — into a single wrap unit. When the attribute
  /// lane wraps on a narrow viewport this keeps the estimate travelling with
  /// the due chip instead of stranding it alone on a near-empty second row
  /// beneath a full row (a lone orphaned chip). The inner [Wrap] reuses the
  /// same chip gap, so the pair looks identical to two adjacent chips on wide
  /// screens, and only ever breaks apart internally at extreme widths — it
  /// never overflows. With no estimate the group collapses to the bare due
  /// chip.
  Widget _timeGroup(double chipGap) {
    final due = _DuePill(dueDate: dueDate, onTap: onDueDateTap);
    final slot = estimateSlot;
    if (slot == null) return due;
    return Wrap(
      spacing: chipGap,
      runSpacing: chipGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [due, slot],
    );
  }
}

/// The task **status** select, presented as a tinted pill and wrapped in the
/// [CompletionCelebration] so closing a task fires the staged glow + spark
/// burst + heavy haptic. Lives at the trailing edge of the title line, giving
/// status a single, predictable home that is decoupled from how the metadata
/// chips below it wrap.
class TaskHeaderStatusPill extends ConsumerWidget {
  const TaskHeaderStatusPill({
    required this.status,
    this.onTap,
    super.key,
  });

  final TaskStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CompletionCelebration(
      completed: status is TaskDone,
      burstOrigin: Alignment.center,
      anchorScale: true,
      // The heavy haptic still fires; the glow + burst + pop honour the
      // user's "celebrate task completion" switch.
      animate: ref.watch(celebrationPreferencesProvider).tasks,
      onCelebrate: () => unawaited(HapticFeedback.heavyImpact()),
      child: _StatusPill(status: status, onTap: onTap),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority, this.onTap});

  final TaskPriority priority;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Priority shares the neutral filled shell with due/estimate. Within the
    // lane's hierarchy it is a *quick-glance* attribute, so its label sits at
    // medium emphasis — a tier below the status pill and the due date — while
    // its urgency colour rides the glyph (red P0 → green P3), keeping the
    // signal without a second out-shouting solid fill.
    return DsPill(
      variant: DsPillVariant.filled,
      label: priority.short,
      labelColor: TaskShowcasePalette.mediumText(context),
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
    // Normal due dates render as a subtle *filled* metadata chip — the same
    // grammar as the estimate and label chips — so the row carries one
    // coherent chip language instead of a lone outlined pill. Urgency
    // (today / overdue) escalates to a tinted accent so it still reads as a
    // warning at a glance.
    final urgent = dueDate.urgency != DesktopTaskHeaderDueUrgency.normal;
    final accent = switch (dueDate.urgency) {
      DesktopTaskHeaderDueUrgency.overdue => TaskShowcasePalette.error(context),
      DesktopTaskHeaderDueUrgency.today => TaskShowcasePalette.warning(context),
      DesktopTaskHeaderDueUrgency.normal => TaskShowcasePalette.mediumText(
        context,
      ),
    };
    return DsPill(
      variant: urgent ? DsPillVariant.tinted : DsPillVariant.filled,
      color: urgent ? accent : null,
      label: dueDate.label,
      // The due date is the most decision-relevant attribute after status, so
      // its label reads at high emphasis (a tier above priority / estimate);
      // an urgent due date escalates to the tinted accent instead.
      labelColor: urgent ? null : TaskShowcasePalette.highText(context),
      leading: Icon(Icons.calendar_today_outlined, size: 12, color: accent),
      onTap: onTap,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.onTap});

  final TaskStatus status;
  final VoidCallback? onTap;

  // Match the shared chip height so the status pill sits on the same baseline
  // as the priority / due / estimate chips it leads — a uniform attribute lane
  // rather than an over-tall lead pill.
  static const double _height = DsPill.height;

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

  /// The pill's translucent fill — a low-alpha wash of the status accent.
  final Color background;

  /// The pill's label colour. Kept at high contrast against the fill (the
  /// status accent itself is too low-contrast as text on its own tint — a
  /// WCAG failure); the status's *colour* identity is instead carried by the
  /// tinted fill and the per-status glyph.
  final Color foreground;
}

_StatusTint _statusTint(BuildContext context, TaskStatus status) {
  final high = TaskShowcasePalette.highText(context);
  _StatusTint tinted(Color accent) =>
      _StatusTint(background: accent.withValues(alpha: 0.18), foreground: high);
  return switch (status) {
    TaskInProgress() => tinted(TaskShowcasePalette.info(context)),
    TaskBlocked() => tinted(TaskShowcasePalette.error(context)),
    TaskOnHold() => tinted(TaskShowcasePalette.warning(context)),
    TaskGroomed() => tinted(context.designTokens.colors.interactive.enabled),
    TaskDone() => tinted(TaskShowcasePalette.success(context)),
    // Rejected reads as dismissed — a neutral wash with medium-emphasis
    // (still legible) struck-through text rather than the high-emphasis label
    // an active status gets.
    TaskRejected() => _StatusTint(
      background: TaskShowcasePalette.lowText(context).withValues(alpha: 0.14),
      foreground: TaskShowcasePalette.mediumText(context),
    ),
    TaskOpen() => _StatusTint(
      background: TaskShowcasePalette.mediumText(
        context,
      ).withValues(alpha: 0.12),
      foreground: high,
    ),
  };
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
    // Labels are the user's free-form taxonomy, secondary to the structured
    // attributes in the lane above — so their text reads at medium emphasis,
    // a step quieter than the high-emphasis attribute chips, with the colour
    // carried by the leading dot.
    return DsPill(
      variant: DsPillVariant.filled,
      label: label.name,
      labelColor: TaskShowcasePalette.mediumText(context),
      leading: _LabelDot(color: label.color),
      onTap: onTap,
      onLongPress: _hasDescription ? () => _showDescription(context) : null,
    );
  }
}
