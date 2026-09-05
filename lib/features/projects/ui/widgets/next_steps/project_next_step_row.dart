import 'package:flutter/material.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_chips.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// What the row is doing right now, layered over the step's durable outcome:
/// [busy] and [failed] are transient states of the current attempt, the rest
/// mirror `projectNextStepOutcome`.
enum ProjectNextStepRowState { pending, busy, added, done, dismissed, failed }

/// One recommended next step inside the project AI card.
///
/// The title, rationale and priority stay put whatever happens to the step;
/// only the action strip changes. A pending step offers one labelled primary
/// (**Add task**) and one labelled secondary (**Dismiss**), never a bare
/// glyph. A decided step keeps its place with a quiet tag — *Added* with a
/// link to the task, *Done*, or *Dismissed* — and, while the decision is still
/// reversible, an Undo. A failed attempt shows what went wrong under the
/// controls and offers Retry instead of leaving the row blank.
///
/// Above [wideBreakpoint] the strip sits beside the text; below it the strip
/// stacks under the text so a phone title keeps the full row width instead
/// of wrapping around a control rail.
class ProjectNextStepRow extends StatelessWidget {
  const ProjectNextStepRow({
    required this.step,
    required this.state,
    this.enabled = true,
    this.canUndo = false,
    this.failureMessage,
    this.onAddTask,
    this.onDismiss,
    this.onUndo,
    this.onOpenTask,
    super.key,
  });

  /// Content width from which the action strip sits beside the text.
  static const double wideBreakpoint = 560;

  final ProjectRecommendationEntity step;
  final ProjectNextStepRowState state;

  /// Disables every control without hiding it — the host passes `false`
  /// while the page runs a mutation of its own.
  final bool enabled;

  /// Whether the decided step still offers Undo.
  final bool canUndo;

  /// Shown under the controls in the [ProjectNextStepRowState.failed] state;
  /// falls back to the generic creation failure copy.
  final String? failureMessage;

  /// Add task, and Retry after a failure. Null in the failed state means the
  /// failure is final — the step was consumed — so no Retry is offered.
  final VoidCallback? onAddTask;
  final VoidCallback? onDismiss;
  final VoidCallback? onUndo;
  final VoidCallback? onOpenTask;

  bool get _decided => switch (state) {
    ProjectNextStepRowState.added ||
    ProjectNextStepRowState.done ||
    ProjectNextStepRowState.dismissed => true,
    ProjectNextStepRowState.pending ||
    ProjectNextStepRowState.busy ||
    ProjectNextStepRowState.failed => false,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final dismissed = state == ProjectNextStepRowState.dismissed;
    final rationale = step.rationale?.trim() ?? '';
    final priority = parseTaskPriority(step.priority);

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          step.title,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: dismissed ? ai.metaText : ai.titleText,
            decoration: dismissed ? TextDecoration.lineThrough : null,
            decorationColor: ai.metaText,
          ),
        ),
        if (rationale.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step1),
          Text(
            rationale,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: ai.metaText,
            ),
          ),
        ],
        if (priority != null) ...[
          SizedBox(height: tokens.spacing.step2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaskShowcasePriorityGlyph(priority: priority, size: IconSizes.xs),
              SizedBox(width: tokens.spacing.step2),
              Text(
                priority.localizedLabel(context),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ai.metaText,
                ),
              ),
            ],
          ),
        ],
      ],
    );
    final actions = _ActionStrip(row: this);
    final failure = state == ProjectNextStepRowState.failed
        ? _FailureLine(
            message:
                failureMessage ?? context.messages.projectNextStepCreateFailed,
          )
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _decided ? ai.subtleWash : ai.row,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border.all(color: ai.rowBorder),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step3,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= wideBreakpoint;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (wide)
                  Row(
                    children: [
                      Expanded(child: text),
                      SizedBox(width: tokens.spacing.step4),
                      actions,
                    ],
                  )
                else ...[
                  text,
                  SizedBox(height: tokens.spacing.step2),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: actions,
                  ),
                ],
                if (failure != null) ...[
                  SizedBox(height: tokens.spacing.step2),
                  failure,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActionStrip extends StatelessWidget {
  const _ActionStrip({required this.row});

  final ProjectNextStepRow row;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final enabled = row.enabled;

    Widget addButton(String label, IconData icon) => DesignSystemButton(
      label: label,
      leadingIcon: icon,
      variant: DesignSystemButtonVariant.secondary,
      size: DesignSystemButtonSize.dense,
      tapTargetSize: MaterialTapTargetSize.padded,
      onPressed: enabled ? row.onAddTask : null,
    );
    // An inline action aligns itself and fills whatever width a Wrap offers,
    // which would push every neighbour onto the next run; the intrinsic box
    // hands it its own width instead.
    final dismiss = IntrinsicWidth(
      child: DesignSystemInlineAction(
        onTap: enabled ? row.onDismiss : null,
        semanticsLabel: messages.projectNextStepDismiss,
        label: messages.projectNextStepDismiss,
        leadingIcon: LottiIcons.close,
      ),
    );
    final undo = IntrinsicWidth(
      child: DesignSystemInlineAction(
        onTap: enabled ? row.onUndo : null,
        semanticsLabel: messages.designSystemUndoLabel,
        label: messages.designSystemUndoLabel,
        leadingIcon: LottiIcons.undo,
      ),
    );

    final children = switch (row.state) {
      ProjectNextStepRowState.pending => [
        addButton(messages.projectActionAddTask, LottiIcons.add),
        dismiss,
      ],
      ProjectNextStepRowState.failed => [
        if (row.onAddTask != null)
          addButton(messages.projectNextStepRetry, LottiIcons.refresh),
        dismiss,
      ],
      ProjectNextStepRowState.busy => [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: IconSizes.xs,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ai.accent,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Text(
              messages.projectNextStepCreating,
              style: tokens.typography.styles.others.caption.copyWith(
                color: ai.metaText,
              ),
            ),
          ],
        ),
      ],
      ProjectNextStepRowState.added => [
        _OutcomeTag(
          icon: LottiIcons.confirm,
          iconColor: ai.accent,
          label: messages.projectNextStepAdded,
        ),
        IntrinsicWidth(
          child: DesignSystemInlineAction(
            onTap: enabled ? row.onOpenTask : null,
            semanticsLabel: messages.projectNextStepOpenTask,
            label: messages.projectNextStepOpenTask,
            trailingIcon: LottiIcons.chevronRight,
            ink: tokens.colors.interactive.enabled,
          ),
        ),
        if (row.canUndo) undo,
      ],
      ProjectNextStepRowState.done => [
        _OutcomeTag(
          icon: LottiIcons.confirm,
          iconColor: ai.accent,
          label: messages.projectNextStepDone,
        ),
        if (row.canUndo) undo,
      ],
      ProjectNextStepRowState.dismissed => [
        _OutcomeTag(
          icon: LottiIcons.close,
          iconColor: ai.metaText,
          label: messages.projectNextStepDismissed,
        ),
        if (row.canUndo) undo,
      ],
    };

    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// The quiet history tag a decided row keeps: glyph plus a plain word, never
/// colour alone, in the same register as the task agent's resolved tag.
class _OutcomeTag extends StatelessWidget {
  const _OutcomeTag({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: IconSizes.xs, color: iconColor),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: ai.metaText,
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureLine extends StatelessWidget {
  const _FailureLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ink = tokens.colors.alert.error.ink;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.step1),
            child: Icon(LottiIcons.warning, size: IconSizes.xs, color: ink),
          ),
          SizedBox(width: tokens.spacing.step2),
          Expanded(
            child: Text(
              message,
              style: tokens.typography.styles.others.caption.copyWith(
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
