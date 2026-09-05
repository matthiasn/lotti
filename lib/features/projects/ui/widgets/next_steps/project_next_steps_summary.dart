import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/next_steps/project_next_steps_model.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// "just now", "40 min ago", "2 h ago", "3 days ago" — the coarse age the
/// band uses for when the agent last looked.
String formatProjectNextStepsAge(AppLocalizations messages, Duration elapsed) {
  final age = projectNextStepsAge(elapsed);
  return switch (age.unit) {
    ProjectNextStepsAgeUnit.justNow => messages.projectNextStepsAgoJustNow,
    ProjectNextStepsAgeUnit.minutes => messages.projectNextStepsAgoMinutes(
      age.count,
    ),
    ProjectNextStepsAgeUnit.hours => messages.projectNextStepsAgoHours(
      age.count,
    ),
    ProjectNextStepsAgeUnit.days => messages.projectNextStepsAgoDays(age.count),
  };
}

/// The one-line stand-in for a run whose every step has been decided: what
/// happened, when the agent last looked, and a disclosure to the per-step
/// history. Replaces the full row list only once the user comes back to the
/// page; the decisions they just made stay inline until then.
class ProjectNextStepsSummary extends StatelessWidget {
  const ProjectNextStepsSummary({
    required this.steps,
    required this.runCreatedAt,
    required this.now,
    required this.historyOpen,
    required this.onToggleHistory,
    super.key,
  });

  final List<ProjectRecommendationEntity> steps;
  final DateTime? runCreatedAt;
  final DateTime now;
  final bool historyOpen;
  final VoidCallback onToggleHistory;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final tally = ProjectNextStepsTally.of(steps);
    final parts = [
      if (tally.added > 0) messages.projectNextStepsCountAdded(tally.added),
      if (tally.done > 0) messages.projectNextStepsCountDone(tally.done),
      if (tally.dismissed > 0)
        messages.projectNextStepsCountDismissed(tally.dismissed),
    ].join(', ');
    // A legacy run without a snapshot dates itself by its newest step.
    final lookedAt =
        runCreatedAt ??
        steps
            .map((step) => step.createdAt)
            .reduce(
              (a, b) => a.isAfter(b) ? a : b,
            );
    final line = messages.projectNextStepsLastRun(
      parts,
      formatProjectNextStepsAge(messages, now.difference(lookedAt)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(LottiIcons.tip, size: IconSizes.s, color: ai.titleText),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                line,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: ai.metaText,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            IntrinsicWidth(
              child: DesignSystemInlineAction(
                onTap: onToggleHistory,
                semanticsLabel: historyOpen
                    ? messages.projectNextStepsHideHistory
                    : messages.projectNextStepsShowHistory,
                label: historyOpen
                    ? messages.projectNextStepsHideHistory
                    : messages.projectNextStepsShowHistory,
                leadingIcon: historyOpen
                    ? LottiIcons.chevronUp
                    : LottiIcons.chevronDown,
                ink: tokens.colors.interactive.enabled,
              ),
            ),
          ],
        ),
        if (historyOpen) ...[
          SizedBox(height: tokens.spacing.step2),
          for (final step in steps) _HistoryRow(step: step),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.step});

  final ProjectRecommendationEntity step;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final (icon, color, tag) = switch (projectNextStepOutcome(step)) {
      ProjectNextStepOutcome.added => (
        LottiIcons.confirm,
        ai.accent,
        messages.projectNextStepAdded,
      ),
      ProjectNextStepOutcome.done => (
        LottiIcons.confirm,
        ai.accent,
        messages.projectNextStepDone,
      ),
      ProjectNextStepOutcome.dismissed => (
        LottiIcons.close,
        ai.metaText,
        messages.projectNextStepDismissed,
      ),
      // A pending row cannot appear in a fully decided run; render it as
      // plain history rather than inventing a state.
      ProjectNextStepOutcome.pending => (
        LottiIcons.tip,
        ai.metaText,
        messages.changeSetPendingCount(1),
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
        child: Row(
          children: [
            Icon(icon, size: IconSizes.xs, color: color),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                step.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: ai.titleText,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Text(
              tag,
              style: tokens.typography.styles.others.caption.copyWith(
                color: ai.metaText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The band when the newest run has nothing open: says so, and when the agent
/// last looked, instead of leaving an unexplained gap under the report.
class ProjectNextStepsEmpty extends StatelessWidget {
  const ProjectNextStepsEmpty({
    required this.runCreatedAt,
    required this.now,
    super.key,
  });

  final DateTime? runCreatedAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final text = [
      messages.projectNextStepsEmpty,
      if (runCreatedAt case final lookedAt?)
        messages.projectNextStepsLastLooked(
          formatProjectNextStepsAge(messages, now.difference(lookedAt)),
        ),
    ].join(' ');
    return Row(
      children: [
        Icon(LottiIcons.tip, size: IconSizes.s, color: ai.titleText),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            text,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: ai.metaText,
            ),
          ),
        ),
      ],
    );
  }
}
