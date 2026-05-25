import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One row in the Refine right column. Mirrors the prototype DiffRow.
class DiffRow extends StatelessWidget {
  const DiffRow({required this.change, super.key});

  final PlanDiffChange change;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = _accentColor(context);
    final isDropped = change.kind == PlanDiffChangeKind.dropped;

    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(tokens.radii.s),
            ),
            child: Icon(_iconFor(change.kind), size: 14, color: accent),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _overlineFor(context, change.kind),
                  style: tokens.typography.styles.others.overline.copyWith(
                    color: accent,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  change.title,
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    decoration: isDropped ? TextDecoration.lineThrough : null,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _accentColor(BuildContext context) {
    final tokens = context.designTokens;
    switch (change.kind) {
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
            label: _formatRange(change.fromStart!, change.fromEnd!),
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
            label: _formatRange(change.toStart!, change.toEnd!),
            color: accent,
          ),
      ],
    );
  }

  String _formatRange(DateTime start, DateTime end) {
    return '${_clock(start)}–${_clock(end)}';
  }

  String _clock(DateTime t) {
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'am' : 'pm';
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
