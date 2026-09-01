import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/celebration/completion_celebration.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// One glyph size for every read-out in the metadata summary — status and
/// priority glyphs, the due-date glyph, and the Details trigger's icons.
/// Deliberately between the design system's `IconSizes.xs` (12, inline
/// caption glyphs) and `IconSizes.s` (16, list rows): the tags cap their
/// labels at the 12pt caption, and a 16px glyph out-weighed that text inside
/// a 28px shell.
const double kTaskChipGlyphSize = 14;

/// The compact metadata summary under the title: a single lane of quiet,
/// **informational** read-outs (status, priority, due date, estimate, labels)
/// followed
/// by the one interactive element — the "Details" trigger that opens the
/// metadata fly-out where every value is edited. A null [onOpenDetails] drops
/// both the trigger and the tags' hit targets: that is the state where the
/// details are already on screen as their own column.
///
/// The read-outs wear the tight [DsPillShape.tag] corners (radius 4) so they
/// cannot be mistaken for the fully-rounded filter/action pills elsewhere on
/// the page; tapping anywhere on them still opens the fly-out, but the shape
/// says "fact", not "button". Metadata that is set once and rarely changed
/// does not earn permanent button chrome — the fly-out holds the full
/// label + value detail and the editing affordances.
class TaskMetaSummaryLine extends StatelessWidget {
  const TaskMetaSummaryLine({
    required this.status,
    required this.priority,
    required this.dueDate,
    required this.labels,
    required this.onOpenDetails,
    this.estimate,
    this.aiCostSlot,
    this.blockedBySlot,
    this.showSetCategory = false,
    this.onCategoryTap,
    super.key,
  });

  final TaskStatus status;
  final TaskPriority priority;
  final DesktopTaskHeaderDueDate? dueDate;

  /// The task's time estimate, shown as its own read-out so it is legible at
  /// the same glance as the due date rather than one fly-out away. Null or
  /// zero drops the tag — the lane makes no "Not set" claim, matching how a
  /// missing due date or an empty label list leave no trace either.
  final Duration? estimate;
  final List<LabelDefinition> labels;

  /// Opens the metadata fly-out. Wired to the Details trigger and to every
  /// read-out tag, so a tap on the fact lands on its editor too.
  final VoidCallback? onOpenDetails;

  /// Whether to offer the dashed "Set category" chip. True exactly when the
  /// task has no category — the crumb then shows no category segment, so this
  /// chip is the header's inline category affordance (the fly-out's Category
  /// row is one tap further away, and an uncategorized task is the state
  /// worth an inline offer).
  final bool showSetCategory;

  /// Opens the category picker directly — the same callback the crumb's
  /// category segment uses once a category exists.
  final VoidCallback? onCategoryTap;

  /// The task's lifetime AI cost, as the shared leaf-and-amount indicator.
  /// Null (or a widget that renders nothing) leaves the lane unchanged, which
  /// is the state of every task that has never used AI.
  final Widget? aiCostSlot;

  /// Optional "Blocked by" chip (link-derived readiness, ADR 0042 §4 —
  /// independent of [status]). An alarm, not routine metadata, so it stays on
  /// the page rather than moving into the fly-out. Null (or a chip that
  /// renders nothing) keeps the lane unchanged for unblocked tasks.
  final Widget? blockedBySlot;

  /// How many label names spell out in the summary before the remainder
  /// compress into a "+N" suffix.
  static const int maxNamedLabels = 2;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Inter-tag gap (step2 = 4) tighter than each tag's own horizontal
    // padding (step3 = 8) so the lane reads as one anchored cluster; the run
    // gap one step looser so a wrapped lane still shows its row break.
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TaskStatusSummaryTag(status: status, onTap: onOpenDetails),
        ?blockedBySlot,
        _SummaryTag(
          leading: TaskShowcasePriorityGlyph(
            priority: priority,
            size: kTaskChipGlyphSize,
          ),
          label: priority.localizedLabel(context),
          onTap: onOpenDetails,
        ),
        if (dueDate case final dueDate?)
          _DueSummaryTag(dueDate: dueDate, onTap: onOpenDetails),
        if (estimate case final estimate? when estimate > Duration.zero)
          _EstimateSummaryTag(estimate: estimate, onTap: onOpenDetails),
        if (labels.isNotEmpty)
          _LabelsSummaryTag(labels: labels, onTap: onOpenDetails),
        // What the AI has cost on this task, at the same glance as its status
        // — a fact about the task, sitting with the other facts, rather than
        // something a reader has to open a panel to learn. Renders nothing
        // until the task has recorded AI calls.
        ?aiCostSlot,
        // An offer, not a read-out: dashed muted shell on the fully-rounded
        // interactive radius, opening the category picker directly. Verb
        // form, matching the grammar the old add-lane established.
        if (showSetCategory)
          DsPill(
            variant: DsPillVariant.muted,
            label: context.messages.taskSetCategoryLabel,
            leading: Icon(
              LottiIcons.category,
              size: kTaskChipGlyphSize,
              color: TaskShowcasePalette.mediumText(context),
            ),
            onTap: onCategoryTap,
          ),
        // Only where there is a fly-out to open: with the details column
        // mounted beside the task, the connector passes null and the lane
        // ends at its facts rather than offering the same panel twice.
        if (onOpenDetails case final openDetails?)
          _DetailsTrigger(onTap: openDetails),
      ],
    );
  }
}

/// A quiet informational read-out: filled + bordered [DsPill] on the tight
/// tag radius, caption label at medium emphasis.
class _SummaryTag extends StatelessWidget {
  const _SummaryTag({
    required this.label,
    this.leading,
    this.labelColor,
    this.tintColor,
    this.onTap,
    super.key,
  });

  final String label;
  final Widget? leading;
  final Color? labelColor;

  /// When set, renders the tinted variant (urgent due dates) instead of the
  /// neutral filled shell.
  final Color? tintColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = tintColor;
    if (tint != null) {
      return DsPill(
        variant: DsPillVariant.tinted,
        shape: DsPillShape.tag,
        color: tint,
        label: label,
        labelColor: labelColor,
        leading: leading,
        onTap: onTap,
      );
    }
    return DsPill(
      variant: DsPillVariant.filled,
      shape: DsPillShape.tag,
      bordered: true,
      label: label,
      labelColor: labelColor ?? TaskShowcasePalette.mediumText(context),
      leading: leading,
      onTap: onTap,
    );
  }
}

/// The status read-out, wrapped in the [CompletionCelebration] so closing a
/// task still fires the staged glow + spark burst + heavy haptic it always
/// had on the old status pill.
///
/// Active statuses keep their tinted wash (the same 18% accent the old pill
/// painted); the neutral Open state and the dismissed Rejected state use the
/// filled + bordered shell the other read-outs wear, Rejected additionally
/// struck through at medium emphasis.
class TaskStatusSummaryTag extends ConsumerWidget {
  const TaskStatusSummaryTag({
    required this.status,
    this.onTap,
    super.key,
  });

  final TaskStatus status;
  final VoidCallback? onTap;

  /// The status accent for the tinted variant, or null for the two states
  /// that render on the neutral filled shell.
  Color? _accent(BuildContext context) => switch (status) {
    TaskInProgress() => TaskShowcasePalette.info(context),
    TaskBlocked() => TaskShowcasePalette.error(context),
    TaskOnHold() => TaskShowcasePalette.warning(context),
    TaskGroomed() => context.designTokens.colors.interactive.enabled,
    TaskDone() => TaskShowcasePalette.success(context),
    TaskRejected() || TaskOpen() => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final prefs = ref.watch(celebrationPreferencesProvider);
    final accent = _accent(context);
    final rejected = status is TaskRejected;
    final glyph = TaskShowcaseStatusGlyph(
      status: status,
      size: kTaskChipGlyphSize,
    );
    final Widget tag;
    if (accent != null) {
      tag = DsPill(
        variant: DsPillVariant.tinted,
        shape: DsPillShape.tag,
        color: accent,
        // The status accent itself is too low-contrast as text on its own
        // tint (a WCAG failure); the colour identity rides the tint and the
        // glyph.
        labelColor: TaskShowcasePalette.highText(context),
        label: status.localizedLabel(context),
        leading: glyph,
        onTap: onTap,
      );
    } else {
      tag = DsPill(
        variant: DsPillVariant.filled,
        shape: DsPillShape.tag,
        bordered: true,
        // Rejected reads as dismissed — struck-through, medium-emphasis
        // (still legible) — while Open keeps the plain high-emphasis label.
        labelWidget: rejected
            ? Text(
                status.localizedLabel(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: TaskShowcasePalette.mediumText(context),
                  height: 1,
                  decoration: TextDecoration.lineThrough,
                ),
              )
            : null,
        label: rejected ? null : status.localizedLabel(context),
        labelColor: rejected ? null : TaskShowcasePalette.highText(context),
        leading: glyph,
        onTap: onTap,
      );
    }
    return CompletionCelebration(
      completed: status is TaskDone,
      burstOrigin: Alignment.center,
      anchorScale: true,
      selection: prefs.tasksSelection,
      paramsFor: prefs.paramsFor,
      // The visual celebration honours the master switch + the task switch;
      // the heavy haptic honours the independent haptics switch.
      animate: prefs.animateTasks,
      onCelebrate: prefs.haptics
          ? () => unawaited(HapticFeedback.heavyImpact())
          : null,
      child: tag,
    );
  }
}

/// The due-date read-out. Urgency escalates to the tinted alert shell so an
/// overdue or due-today task still reads as a warning at a glance.
class _DueSummaryTag extends StatelessWidget {
  const _DueSummaryTag({required this.dueDate, this.onTap});

  final DesktopTaskHeaderDueDate dueDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final urgent = dueDate.urgency != DesktopTaskHeaderDueUrgency.normal;
    final accent = switch (dueDate.urgency) {
      DesktopTaskHeaderDueUrgency.overdue => TaskShowcasePalette.errorInk(
        context,
      ),
      DesktopTaskHeaderDueUrgency.today => TaskShowcasePalette.warningInk(
        context,
      ),
      DesktopTaskHeaderDueUrgency.normal => TaskShowcasePalette.mediumText(
        context,
      ),
    };
    return _SummaryTag(
      label: dueDate.label,
      tintColor: urgent ? accent : null,
      // The due date is the most decision-relevant read-out after status, so
      // its label reads at high emphasis; an urgent due date escalates to the
      // tinted accent instead (labelColor stays null so the tinted shell
      // paints its own ink).
      labelColor: urgent ? null : TaskShowcasePalette.highText(context),
      leading: Icon(
        LottiIcons.today,
        size: kTaskChipGlyphSize,
        color: accent,
      ),
      onTap: onTap,
    );
  }
}

/// The estimate read-out: the planned time as compact units ("45m", "1h 30m")
/// behind the timer glyph, on the same neutral shell as priority. Tracked
/// time against the estimate stays in the fly-out and details column, which
/// have room for the progress bar; the lane only answers "how big is this?".
class _EstimateSummaryTag extends StatelessWidget {
  const _EstimateSummaryTag({required this.estimate, this.onTap});

  final Duration estimate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _SummaryTag(
      key: const ValueKey('task-estimate-summary-tag'),
      label: formatRangeDuration(estimate),
      leading: Icon(
        LottiIcons.timer,
        size: kTaskChipGlyphSize,
        color: TaskShowcasePalette.mediumText(context),
      ),
      onTap: onTap,
    );
  }
}

/// The labels read-out: up to [TaskMetaSummaryLine.maxNamedLabels] names plus
/// a "+N" suffix, led by the first labels' colour dots — the user's taxonomy
/// compressed to one glanceable tag instead of a lane of pills.
class _LabelsSummaryTag extends StatelessWidget {
  const _LabelsSummaryTag({required this.labels, this.onTap});

  final List<LabelDefinition> labels;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final named = labels
        .take(TaskMetaSummaryLine.maxNamedLabels)
        .map((label) => label.name);
    final overflow = labels.length - TaskMetaSummaryLine.maxNamedLabels;
    final text = overflow > 0
        ? '${named.join(', ')} '
              '${context.messages.taskLabelsMoreCount(overflow)}'
        : named.join(', ');
    return _SummaryTag(
      label: text,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final label in labels.take(
            TaskMetaSummaryLine.maxNamedLabels,
          )) ...[
            _LabelDot(color: label.color),
            SizedBox(width: tokens.spacing.step1),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

/// The one interactive element in the lane: opens the metadata fly-out. As a
/// control it keeps the fully-rounded pill shape — the corner-radius grammar
/// that separates levers from the square-cornered facts beside it.
class _DetailsTrigger extends StatelessWidget {
  const _DetailsTrigger({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DsPill(
      variant: DsPillVariant.muted,
      label: context.messages.taskMetaDetailsButton,
      leading: Icon(
        LottiIcons.tune,
        size: kTaskChipGlyphSize,
        color: TaskShowcasePalette.mediumText(context),
      ),
      trailing: Icon(
        LottiIcons.expand,
        size: kTaskChipGlyphSize,
        color: TaskShowcasePalette.mediumText(context),
      ),
      onTap: onTap,
    );
  }
}

/// 8px circle filled with the label's own color. Kept from the old label
/// pills so the taxonomy colours stay visible in the compressed summary.
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
