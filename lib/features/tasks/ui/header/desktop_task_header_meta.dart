import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// One glyph size for every chip in the metadata lane — status and priority
/// glyphs, disclosure carets, and the dashed add-chips' leading icons. The
/// lane used to split 12 vs 14 across eight call sites, which is exactly the
/// kind of per-widget improvisation that drifts. Deliberately between the
/// design system's `IconSizes.xs` (12, inline caption glyphs) and
/// `IconSizes.s` (16, list rows): the chips cap their labels at the 12pt
/// caption, and a 16px glyph out-weighed that text inside a 28px pill.
const double kTaskChipGlyphSize = 14;

/// The metadata block under the title, in up to three lanes. The first lane
/// holds the *set* attributes led by the **status** pill — status, priority,
/// and whichever of due date / estimate carry real values; the second holds
/// the dashed **add-affordances** for everything still unset (category, due
/// date, estimate, first label); the third holds the free-form **labels**.
/// All lanes pack left-to-right and wrap with a consistent run spacing.
///
/// The set/unset split is semantic, not arithmetic. One mixed Wrap broke
/// wherever the measure said — at the first-run page's 520pt it wrapped 4+1
/// and stranded a lone dashed chip on its own line, the loudest remaining
/// "nobody looked at this width" cue on the page. Two runs give the lane a
/// stable rhythm at every breakpoint: solid facts first, dashed offers below,
/// each group wrapping only within itself.
///
/// Status leads the set lane (rather than being pinned to a trailing edge) so
/// it has one stable, predictable home that never opens a horizontal dead
/// zone next to a short chip cluster and never gets marooned when the row
/// wraps. Every attribute is its own wrap unit.
/// Beyond a small cap the free-form labels collapse behind a tappable "+N"
/// affordance so a long taxonomy never floods the lane. Separating attributes
/// from labels gives the eye an
/// instant "what state / when / how big" read distinct from the user's own
/// taxonomy.
class MetaRow extends StatefulWidget {
  const MetaRow({
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.labels,
    required this.estimateSlot,
    required this.consumptionSlot,
    required this.blockedBySlot,
    required this.onPriorityTap,
    required this.onStatusTap,
    required this.onDueDateTap,
    required this.onLabelTap,
    required this.onAddLabelTap,
    this.showSetCategory = false,
    this.onCategoryTap,
    this.estimateIsSet = true,
    super.key,
  });

  final TaskPriority priority;
  final TaskStatus status;
  final DesktopTaskHeaderDueDate? dueDate;
  final List<LabelDefinition> labels;
  final Widget? estimateSlot;

  /// Whether to offer the dashed "Set category" chip in the add-lane. True
  /// exactly when the task has no category — the crumb above then shows no
  /// category segment, so this chip is the *only* category affordance and the
  /// two can never disagree about whose turn it is.
  final bool showSetCategory;
  final VoidCallback? onCategoryTap;

  /// Which lane the [estimateSlot] joins. The slot stays an opaque widget
  /// (see [DesktopTaskHeader.estimateIsSet] for why the caller answers this).
  final bool estimateIsSet;

  /// Optional "Blocked by" chip (link-derived readiness, ADR 0042 §4 —
  /// independent of [status]). Rendered right after the status pill, part of
  /// the "what state" cluster, ahead of priority/due/estimate. Null (or a
  /// chip that renders nothing) keeps the lane unchanged for unblocked tasks.
  final Widget? blockedBySlot;

  /// Optional AI-consumption pill (cost/energy/CO₂e), rendered after the time
  /// group. Null (or a chip that renders nothing) keeps the lane unchanged for
  /// tasks without AI usage.
  final Widget? consumptionSlot;
  final VoidCallback? onPriorityTap;
  final VoidCallback? onStatusTap;
  final VoidCallback? onDueDateTap;
  final ValueChanged<LabelDefinition>? onLabelTap;
  final VoidCallback? onAddLabelTap;

  @override
  State<MetaRow> createState() => _MetaRowState();
}

class _MetaRowState extends State<MetaRow> {
  /// Below this lane width a four-chip add-lane breaks 2+2 instead of
  /// wrapping greedily. Sits between the phone lane (~358 at a 390 viewport
  /// inside the page's step5 gutters) and the capped first-run measure
  /// (520 - 32 = 488), where all four chips fit one line.
  static const double _addLaneBalanceBreakpoint = 460;

  /// How many label chips show before the remainder collapse behind a "+N"
  /// affordance, so a long taxonomy never floods the lane with a wall of
  /// equal-weight chips competing with the title (the dominant overwhelm cue
  /// for attention-sensitive users).
  static const int _maxVisibleLabels = 4;

  /// Whether the user has expanded the collapsed label overflow.
  bool _labelsExpanded = false;

  @override
  void didUpdateWidget(MetaRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different task's labels start collapsed again.
    if (!listEquals(oldWidget.labels, widget.labels)) {
      _labelsExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Inter-chip gap (step2 = 4) is kept deliberately tighter than each pill's
    // own internal horizontal padding (step3 = 8) so the chips read as one
    // anchored cluster rather than scattered tokens.
    final chipGap = tokens.spacing.step2;
    // Run spacing is a step LOOSER than the inter-chip gutter. At the same
    // step2 the wrapped rows sat closer to each other than the chips within a
    // row did, so a two-row lane read as one crowded slab; step3 lets the eye
    // find the row break while the lane still holds together as one block.
    final laneRunGap = tokens.spacing.step3;
    final labels = widget.labels;
    final dueIsSet = widget.dueDate != null;
    // Solid facts only: everything here states a value the task actually has.
    final attributes = <Widget>[
      TaskHeaderStatusPill(status: widget.status, onTap: widget.onStatusTap),
      if (widget.blockedBySlot != null) widget.blockedBySlot!,
      _PriorityPill(priority: widget.priority, onTap: widget.onPriorityTap),
      if (dueIsSet)
        _DuePill(dueDate: widget.dueDate!, onTap: widget.onDueDateTap),
      if (widget.estimateSlot != null && widget.estimateIsSet)
        widget.estimateSlot!,
      if (widget.consumptionSlot != null) widget.consumptionSlot!,
    ];
    // Dashed offers only: where the task lives, when it is due, how it is
    // tagged, how big it is.
    final addChips = <Widget>[
      if (widget.showSetCategory)
        DsPill(
          variant: DsPillVariant.muted,
          // Verb form, matching the other unset chips — see `_DuePill`.
          label: context.messages.taskSetCategoryLabel,
          // mediumText, matching the muted pill's label contract — a glyph a
          // step fainter than its own caption vanished for low-vision users
          // in dark theme.
          leading: Icon(
            Icons.category_outlined,
            size: kTaskChipGlyphSize,
            color: TaskShowcasePalette.mediumText(context),
          ),
          onTap: widget.onCategoryTap,
        ),
      if (!dueIsSet)
        DsPill(
          variant: DsPillVariant.muted,
          // A verb, not a report. "No due date" is a statement of fact, and
          // reviewers read it as one — a label describing the task rather
          // than a control offering to fix it — so they never tapped it.
          label: context.messages.taskSetDueDateLabel,
          leading: Icon(
            Icons.calendar_today_outlined,
            size: kTaskChipGlyphSize,
            color: TaskShowcasePalette.mediumText(context),
          ),
          onTap: widget.onDueDateTap,
        ),
      // With no labels yet, the "Add Label" affordance rides the add-lane
      // with its fellow offers — the dedicated label lane only materialises
      // once there is real taxonomy to hold. It sits BEFORE the estimate
      // chip: the lane wraps at the measure's mercy, and when a row breaks
      // the short label chip packs beside its neighbours while the widest
      // chip takes the new row. An object glyph like its three siblings —
      // the bare "+" made it the one chip in the lane wearing a different
      // grammar.
      if (labels.isEmpty)
        DsPill(
          variant: DsPillVariant.muted,
          label: context.messages.tasksAddLabelButton,
          leading: Icon(
            Icons.label_outline_rounded,
            size: kTaskChipGlyphSize,
            color: TaskShowcasePalette.mediumText(context),
          ),
          onTap: widget.onAddLabelTap,
        ),
      if (widget.estimateSlot != null && !widget.estimateIsSet)
        widget.estimateSlot!,
    ];
    Wrap lane(List<Widget> children) => Wrap(
      spacing: chipGap,
      runSpacing: laneRunGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
    // The add-lane on a phone: four chips greedily wrap 3+1, stranding the
    // widest chip alone under a full row — the raggedness that undermines
    // the two-run grammar on every narrow viewport. Below the balance
    // breakpoint a four-offer lane breaks at its own midpoint instead, a
    // deliberate 2+2. The full first-run set is the only population this
    // needs; fewer chips fit a phone row outright, and the wide measure
    // holds all four on one line.
    Widget addLane(List<Widget> chips, double maxWidth) {
      if (chips.length < 4 || maxWidth >= _addLaneBalanceBreakpoint) {
        return lane(chips);
      }
      final midpoint = chips.length ~/ 2;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          lane(chips.sublist(0, midpoint)),
          SizedBox(height: laneRunGap),
          lane(chips.sublist(midpoint)),
        ],
      );
    }

    final attributeLane = lane(attributes);
    if (addChips.isEmpty && labels.isEmpty) return attributeLane;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        attributeLane,
        if (addChips.isNotEmpty) ...[
          // A full step4 below the set lane — one step looser than the
          // intra-lane run gap — so the semantic split between facts and
          // offers is carried by space as well as by border style, without
          // growing into the sectionGap that would break the block apart.
          SizedBox(height: tokens.spacing.step4),
          LayoutBuilder(
            builder: (context, constraints) =>
                addLane(addChips, constraints.maxWidth),
          ),
        ],
        if (labels.isNotEmpty) ...[
          // The lane separation (step4 = 12) is a full "context break" step —
          // the same gap used between the breadcrumb and the title — so it
          // reads as a clearly larger rhythmic step than the intra-lane chip
          // gutter (step2 = 4). That vertical step alone signals the
          // free-form label taxonomy as a distinct register from the
          // structured attributes above it (rather than leaning only on the
          // chips' colour dots), without needing a divider.
          SizedBox(height: tokens.spacing.step4),
          _buildLabelLane(context, chipGap, laneRunGap, labels),
        ],
      ],
    );
  }

  /// The free-form label lane. Beyond [_maxVisibleLabels] the remainder
  /// collapse behind a tappable "+N" chip; expanding swaps in a "Show fewer"
  /// chip so the lane can be re-collapsed.
  Widget _buildLabelLane(
    BuildContext context,
    double chipGap,
    double runGap,
    List<LabelDefinition> labels,
  ) {
    final hasOverflow = labels.length > _maxVisibleLabels;
    final collapsed = hasOverflow && !_labelsExpanded;
    final visible = collapsed ? labels.take(_maxVisibleLabels) : labels;
    return Wrap(
      spacing: chipGap,
      runSpacing: runGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final label in visible)
          _LabelPill(
            label: label,
            onTap: widget.onLabelTap == null
                ? null
                : () => widget.onLabelTap!(label),
          ),
        if (collapsed)
          _LabelOverflowChip(
            label: context.messages.taskLabelsMoreCount(
              labels.length - _maxVisibleLabels,
            ),
            onTap: () => setState(() => _labelsExpanded = true),
          )
        else if (hasOverflow)
          _LabelOverflowChip(
            label: context.messages.taskLabelsShowFewer,
            onTap: () => setState(() => _labelsExpanded = false),
          ),
      ],
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
    final prefs = ref.watch(celebrationPreferencesProvider);
    return CompletionCelebration(
      completed: status is TaskDone,
      burstOrigin: Alignment.center,
      anchorScale: true,
      selection: prefs.tasksSelection,
      paramsFor: prefs.paramsFor,
      // The visual celebration honours the master switch + the task switch; the
      // heavy haptic honours the independent haptics switch.
      animate: prefs.animateTasks,
      onCelebrate: prefs.haptics
          ? () => unawaited(HapticFeedback.heavyImpact())
          : null,
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
    // "Priority: Medium" on hover and for assistive tech: the chip's bare
    // value never names its attribute, and priority was the one chip in the
    // lane whose tooltip left that to guesswork (the estimate chip already
    // spells its numbers out the same way).
    // Priority shares the neutral filled shell with due/estimate. Within the
    // lane's hierarchy it is a *quick-glance* attribute, so its label sits at
    // medium emphasis — a tier below the status pill and the due date — while
    // its urgency colour rides the glyph (red P0 → green P3), keeping the
    // signal without a second out-shouting solid fill.
    return Tooltip(
      message: context.messages.taskPriorityTooltip(
        priority.localizedLabel(context),
      ),
      child: DsPill(
        variant: DsPillVariant.filled,
        bordered: true,
        // Spelled-out priority (Urgent / High / Medium / Low) instead of the
        // opaque "P2" code, so the urgency direction reads without decoding.
        label: priority.localizedLabel(context),
        // High emphasis, like the due chip. At medium it inked identically to
        // the *unset* chips beside it, so a value the user had chosen looked no
        // different from one they had not — and the lane's two shells stopped
        // meaning "set" and "unset" at all.
        labelColor: TaskShowcasePalette.highText(context),
        leading: TaskShowcasePriorityGlyph(
          priority: priority,
          size: kTaskChipGlyphSize,
        ),
        // The same disclosure caret the status pill wears. Both chips open a
        // picker, and only one of them said so — novice reviewers read the
        // caret-less "Medium" as a badge rather than a control and never
        // discovered priority was changeable.
        trailing: Icon(
          Icons.expand_more_rounded,
          size: kTaskChipGlyphSize,
          // mediumText, like every behavioural glyph on the surface: the caret
          // is the chip's tap-scent, and at lowText it was the faintest ink on
          // a control the empty state depends on.
          color: TaskShowcasePalette.mediumText(context),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// The *set* due-date chip. The unset "Set due date" offer is not this
/// widget's business any more — it lives in [MetaRow]'s dashed add-lane with
/// the other unset affordances, so this pill only ever states a date the task
/// actually has.
class _DuePill extends StatelessWidget {
  const _DuePill({required this.dueDate, this.onTap});

  final DesktopTaskHeaderDueDate dueDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dueDate = this.dueDate;
    // Normal due dates render as a subtle *filled* metadata chip — the same
    // grammar as the estimate and label chips — so the row carries one
    // coherent chip language instead of a lone outlined pill. Urgency
    // (today / overdue) escalates to a tinted accent so it still reads as a
    // warning at a glance.
    final urgent = dueDate.urgency != DesktopTaskHeaderDueUrgency.normal;
    // Ink, because an urgent chip leaves `labelColor` null and the tinted pill
    // then paints its label in this colour — the fill strengths only clear the
    // non-text floor.
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
    return DsPill(
      variant: urgent ? DsPillVariant.tinted : DsPillVariant.filled,
      // The neutral filled due chip gets a quiet border for a clear low-vision
      // boundary; the urgent tinted variant already reads via its accent fill.
      bordered: !urgent,
      color: urgent ? accent : null,
      label: dueDate.label,
      // The due date is the most decision-relevant attribute after status, so
      // its label reads at high emphasis (a tier above priority / estimate);
      // an urgent due date escalates to the tinted accent instead.
      labelColor: urgent ? null : TaskShowcasePalette.highText(context),
      leading: Icon(
        Icons.calendar_today_outlined,
        size: kTaskChipGlyphSize,
        color: accent,
      ),
      onTap: onTap,
    );
  }
}

/// The status pill, rendered through [DsPill] like every other chip in the
/// lane — one pill primitive, no hand-copied height floor or radius to
/// drift. Active statuses use the tinted variant (the same 18% wash the old
/// bespoke pill painted); the neutral Open state and the dismissed Rejected
/// state use the filled+bordered shell the set chips beside them wear, so
/// the lane's "solid container = set value" grammar holds without a special
/// case.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.onTap});

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
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = _accent(context);
    final rejected = status is TaskRejected;
    final caret = Icon(
      Icons.expand_more_rounded,
      size: kTaskChipGlyphSize,
      // mediumText — same behavioural-glyph ink as the priority chip's
      // caret and the action rows' +/chevron.
      color: TaskShowcasePalette.mediumText(context),
    );
    final glyph = TaskShowcaseStatusGlyph(
      status: status,
      size: kTaskChipGlyphSize,
    );
    if (accent == null) {
      return DsPill(
        variant: DsPillVariant.filled,
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
        leading: glyph,
        trailing: caret,
        onTap: onTap,
      );
    }
    return DsPill(
      variant: DsPillVariant.tinted,
      color: accent,
      // The status accent itself is too low-contrast as text on its own
      // tint (a WCAG failure); the colour identity rides the tint and the
      // glyph.
      labelColor: TaskShowcasePalette.highText(context),
      label: status.localizedLabel(context),
      leading: glyph,
      trailing: caret,
      onTap: onTap,
    );
  }
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
      bordered: true,
      label: label.name,
      labelColor: TaskShowcasePalette.mediumText(context),
      leading: _LabelDot(color: label.color),
      onTap: onTap,
      onLongPress: _hasDescription ? () => _showDescription(context) : null,
    );
  }
}

/// The label-lane overflow control: a tappable "+N" chip (and, once expanded,
/// a "Show fewer" chip). It shares the bordered filled shell with the label
/// pills but carries no colour dot, so it reads as a control rather than a
/// tag — collapsing a long taxonomy instead of letting it flood the lane.
class _LabelOverflowChip extends StatelessWidget {
  const _LabelOverflowChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DsPill(
      variant: DsPillVariant.filled,
      bordered: true,
      label: label,
      labelColor: TaskShowcasePalette.mediumText(context),
      onTap: onTap,
    );
  }
}
