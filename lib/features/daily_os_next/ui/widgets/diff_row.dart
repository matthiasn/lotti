import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/category_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One row in the Refine right column.
///
/// Mirrors task-agent suggestions: every proposed change is a separate card
/// with accept/reject controls, then collapses into a resolved pill.
class DiffRow extends StatelessWidget {
  const DiffRow({
    required this.change,
    required this.decision,
    required this.onAccept,
    required this.onReject,
    this.resolving = false,
    super.key,
  });

  final PlanDiffChange change;
  final PlanDiffChangeDecision decision;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool resolving;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final decided = decision != PlanDiffChangeDecision.pending;
    final lineThrough =
        change.kind == PlanDiffChangeKind.dropped ||
        decision == PlanDiffChangeDecision.rejected;

    return Opacity(
      opacity: decided ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: BorderRadius.circular(tokens.radii.l),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ChangeBadge(change: change),
                SizedBox(width: tokens.spacing.step3),
                CategoryChip(category: change.category),
              ],
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              change.title,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
                decoration: lineThrough ? TextDecoration.lineThrough : null,
              ),
            ),
            if (change.fromStart != null || change.toStart != null) ...[
              SizedBox(height: tokens.spacing.step2),
              _TimeChipsRow(change: change),
            ],
            SizedBox(height: tokens.spacing.step2),
            Text(
              change.reason,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            if (decided)
              _DecisionPill(decision: decision)
            else
              _DecisionButtonRow(
                resolving: resolving,
                onAccept: onAccept,
                onReject: onReject,
              ),
          ],
        ),
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.change});

  final PlanDiffChange change;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = _accentColor(context, change.kind);
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(change.kind), size: 12, color: accent),
          SizedBox(width: tokens.spacing.step2),
          Text(
            _overlineFor(context, change.kind),
            style: tokens.typography.styles.others.caption.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _accentColor(BuildContext context, PlanDiffChangeKind kind) {
    final tokens = context.designTokens;
    switch (kind) {
      case PlanDiffChangeKind.moved:
        return tokens.colors.alert.info.defaultColor;
      case PlanDiffChangeKind.added:
        return tokens.colors.interactive.enabled;
      case PlanDiffChangeKind.dropped:
        return tokens.colors.text.lowEmphasis;
    }
  }

  IconData _iconFor(PlanDiffChangeKind kind) {
    switch (kind) {
      case PlanDiffChangeKind.moved:
        return Icons.swap_vert_rounded;
      case PlanDiffChangeKind.added:
        return Icons.add_rounded;
      case PlanDiffChangeKind.dropped:
        return Icons.close_rounded;
    }
  }

  String _overlineFor(BuildContext context, PlanDiffChangeKind kind) {
    switch (kind) {
      case PlanDiffChangeKind.moved:
        return context.messages.dailyOsNextRefineDiffMoved;
      case PlanDiffChangeKind.added:
        return context.messages.dailyOsNextRefineDiffAdded;
      case PlanDiffChangeKind.dropped:
        return context.messages.dailyOsNextRefineDiffDropped;
    }
  }
}

class _DecisionButtonRow extends StatelessWidget {
  const _DecisionButtonRow({
    required this.resolving,
    required this.onAccept,
    required this.onReject,
  });

  final bool resolving;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (resolving) {
      return SizedBox(
        height: tokens.spacing.step8,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox.square(
            dimension: tokens.spacing.step4,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.colors.interactive.enabled,
            ),
          ),
        ),
      );
    }
    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onReject,
          icon: const Icon(Icons.close_rounded, size: 14),
          label: Text(context.messages.changeSetSwipeReject),
          style: OutlinedButton.styleFrom(
            foregroundColor: tokens.colors.text.mediumEmphasis,
            side: BorderSide(color: tokens.colors.decorative.level01),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step3,
              vertical: tokens.spacing.step2,
            ),
            textStyle: tokens.typography.styles.body.bodySmall,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onAccept,
          icon: const Icon(Icons.check_rounded, size: 14),
          label: Text(context.messages.dailyOsNextRefineAccept),
          style: FilledButton.styleFrom(
            backgroundColor: tokens.colors.interactive.enabled,
            foregroundColor: tokens.colors.text.onInteractiveAlert,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step2,
            ),
            textStyle: tokens.typography.styles.body.bodySmall,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
          ),
        ),
      ],
    );
  }
}

class _DecisionPill extends StatelessWidget {
  const _DecisionPill({required this.decision});

  final PlanDiffChangeDecision decision;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accepted = decision == PlanDiffChangeDecision.accepted;
    final color = accepted
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.lowEmphasis;
    final label = accepted
        ? context.messages.changeSetItemConfirmed
        : context.messages.changeSetItemRejected;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            accepted ? Icons.check_rounded : Icons.close_rounded,
            size: 14,
            color: color,
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChipsRow extends StatelessWidget {
  const _TimeChipsRow({required this.change});

  final PlanDiffChange change;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = change.kind == PlanDiffChangeKind.moved
        ? tokens.colors.alert.info.defaultColor
        : tokens.colors.interactive.enabled;
    return Wrap(
      spacing: tokens.spacing.step2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (change.fromStart != null && change.fromEnd != null)
          _TimeChip(
            label: _formatRange(context, change.fromStart!, change.fromEnd!),
            color: tokens.colors.text.lowEmphasis,
            strikethrough: true,
          ),
        if (change.fromStart != null && change.toStart != null)
          Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: tokens.colors.text.lowEmphasis,
          ),
        if (change.toStart != null && change.toEnd != null)
          _TimeChip(
            label: _formatRange(context, change.toStart!, change.toEnd!),
            color: accent,
          ),
      ],
    );
  }

  String _formatRange(BuildContext context, DateTime start, DateTime end) {
    return '${_clock(context, start)}–${_clock(context, end)}';
  }

  String _clock(BuildContext context, DateTime t) {
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final messages = context.messages;
    final period = t.hour < 12
        ? messages.dailyOsNextTimelineMeridiemAmShort
        : messages.dailyOsNextTimelineMeridiemPmShort;
    return t.minute == 0 ? '$h12$period' : '$h12:$m$period';
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.color,
    this.strikethrough = false,
  });

  final String label;
  final Color color;
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Text(
        label,
        style: tokens.typography.styles.others.caption.copyWith(
          color: color,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
