import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/category_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One row of the Reconcile screen's left column ("Here's what I heard").
///
/// Surfaces a single [ParsedItem] with:
/// - Kind badge (NEW / MATCHED / UPDATE) in the top-left.
/// - Title (Inter 600 / 15) underneath.
/// - For MATCHED + UPDATE: the spoken phrase in italic + the linked
///   task on an info-tinted pill with a one-tap `×` to break the link.
/// - Foot row: category chip · estimate · time-anchor warning (when
///   present) · "low confidence" warning tag.
class ParsedCard extends StatelessWidget {
  const ParsedCard({
    required this.item,
    required this.onBreakLink,
    super.key,
  });

  final ParsedItem item;
  final VoidCallback onBreakLink;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KindBadge(kind: item.kind),
          SizedBox(height: tokens.spacing.step3),
          if (item.spokenPhrase != null) ...[
            _SpokenPhraseLine(phrase: item.spokenPhrase!),
            SizedBox(height: tokens.spacing.step2),
          ],
          Text(
            item.title,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          if (item.matchedTaskTitle != null) ...[
            SizedBox(height: tokens.spacing.step3),
            _MatchedTaskPill(
              title: item.matchedTaskTitle!,
              taskState: item.matchedTaskState,
              warning: item.confidence == ParsedItemConfidence.medium,
              onBreak: onBreakLink,
            ),
          ],
          if (item.proposedUpdate != null) ...[
            SizedBox(height: tokens.spacing.step3),
            _ProposedUpdateLine(update: item.proposedUpdate!),
          ],
          SizedBox(height: tokens.spacing.step4),
          _FootRow(item: item),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final ParsedItemKind kind;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final (color, label, icon) = switch (kind) {
      ParsedItemKind.newTask => (
        tokens.colors.interactive.enabled,
        context.messages.dailyOsNextReconcileBadgeNew,
        Icons.add_rounded,
      ),
      ParsedItemKind.matched => (
        tokens.colors.alert.info.defaultColor,
        context.messages.dailyOsNextReconcileBadgeMatched,
        Icons.link_rounded,
      ),
      ParsedItemKind.update => (
        tokens.colors.alert.success.defaultColor,
        context.messages.dailyOsNextReconcileBadgeUpdate,
        Icons.check_rounded,
      ),
    };
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: calmEyebrowStyle(tokens, color: color),
          ),
        ],
      ),
    );
  }
}

class _SpokenPhraseLine extends StatelessWidget {
  const _SpokenPhraseLine({required this.phrase});

  final String phrase;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      '“$phrase”',
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.mediumEmphasis,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _MatchedTaskPill extends StatelessWidget {
  const _MatchedTaskPill({
    required this.title,
    required this.warning,
    required this.onBreak,
    this.taskState,
  });

  final String title;
  final String? taskState;
  final bool warning;
  final VoidCallback onBreak;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = warning
        ? tokens.colors.alert.warning.defaultColor
        : tokens.colors.alert.info.defaultColor;
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_forward_rounded, size: 14, color: accent),
          SizedBox(width: tokens.spacing.step2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (taskState != null) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    taskState!,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: accent,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Tooltip(
            message: context.messages.dailyOsNextParsedCardBreakLinkTooltip,
            child: InkWell(
              onTap: onBreak,
              borderRadius: BorderRadius.circular(tokens.radii.s),
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.step1),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposedUpdateLine extends StatelessWidget {
  const _ProposedUpdateLine({required this.update});

  final String update;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final success = tokens.colors.alert.success.defaultColor;
    return Row(
      children: [
        Icon(Icons.check_circle_outline_rounded, size: 14, color: success),
        SizedBox(width: tokens.spacing.step2),
        Expanded(
          child: Text(
            update,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: success,
            ),
          ),
        ),
      ],
    );
  }
}

class _FootRow extends StatelessWidget {
  const _FootRow({required this.item});

  final ParsedItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CategoryChip(category: item.category),
        if (item.estimateMinutes != null)
          _EstimateChip(minutes: item.estimateMinutes!),
        if (item.timeAnchor != null) _TimeAnchorChip(anchor: item.timeAnchor!),
        if (item.confidence == ParsedItemConfidence.medium)
          const _LowConfidenceTag(),
      ],
    );
  }
}

class _EstimateChip extends StatelessWidget {
  const _EstimateChip({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule_rounded,
          size: 12,
          color: tokens.colors.text.lowEmphasis,
        ),
        SizedBox(width: tokens.spacing.step1),
        Text(
          context.messages.dailyOsNextEstimateMinutes(minutes),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
    );
  }
}

class _TimeAnchorChip extends StatelessWidget {
  const _TimeAnchorChip({required this.anchor});

  final String anchor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final warning = tokens.colors.alert.warning.defaultColor;
    return Container(
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: 2,
      ),
      child: Text(
        anchor,
        style: tokens.typography.styles.others.caption.copyWith(
          color: warning,
        ),
      ),
    );
  }
}

class _LowConfidenceTag extends StatelessWidget {
  const _LowConfidenceTag();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final warning = tokens.colors.alert.warning.defaultColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded, size: 12, color: warning),
        SizedBox(width: tokens.spacing.step1),
        Text(
          context.messages.dailyOsNextReconcileLowConfidence,
          style: tokens.typography.styles.others.caption.copyWith(
            color: warning,
          ),
        ),
      ],
    );
  }
}
