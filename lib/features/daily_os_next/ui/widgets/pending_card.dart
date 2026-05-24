import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/category_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One row of the Reconcile screen's right column
/// ("Worth deciding on").
///
/// Once a triage decision is made for the underlying task, the action
/// row collapses into a teal confirmation pill that mirrors the chosen
/// action, and the whole card fades to ~55% opacity per the design.
class PendingCard extends StatelessWidget {
  const PendingCard({
    required this.item,
    required this.onTriage,
    this.decision,
    super.key,
  });

  final PendingItem item;
  final TriageResult? decision;
  final ValueChanged<TriageAction> onTriage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final decided = decision != null;
    return Opacity(
      opacity: decided ? 0.55 : 1.0,
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
                _StateBadge(item: item),
                SizedBox(width: tokens.spacing.step3),
                CategoryChip(category: item.category),
              ],
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              item.title,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
                decoration: _strikeThrough(decision)
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            if (item.note != null) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                item.note!,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
            SizedBox(height: tokens.spacing.step4),
            if (decided)
              _DecisionPill(action: decision!.action)
            else
              _TriageButtonRow(onTriage: onTriage),
          ],
        ),
      ),
    );
  }
}

bool _strikeThrough(TriageResult? decision) {
  if (decision == null) return false;
  return decision.action == TriageAction.done;
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.item});

  final PendingItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final (color, icon, label) = switch (item.reason) {
      PendingItemReason.overdue => (
        tokens.colors.alert.error.defaultColor,
        Icons.warning_amber_rounded,
        context.messages.dailyOsNextStateOverdue(item.overdueByDays ?? 0),
      ),
      PendingItemReason.inProgress => (
        tokens.colors.alert.warning.defaultColor,
        Icons.adjust_rounded,
        context.messages.dailyOsNextStateInProgress(item.sessionCount ?? 0),
      ),
      PendingItemReason.recurringMissed => (
        tokens.colors.alert.info.defaultColor,
        Icons.refresh_rounded,
        context.messages.dailyOsNextStateRecurringMissed,
      ),
      PendingItemReason.dueToday => (
        tokens.colors.interactive.enabled,
        Icons.today_rounded,
        context.messages.dailyOsNextStateDueToday,
      ),
    };
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TriageButtonRow extends StatelessWidget {
  const _TriageButtonRow({required this.onTriage});

  final ValueChanged<TriageAction> onTriage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PrimaryAction(
          icon: Icons.add_rounded,
          label: messages.dailyOsNextTriageToday,
          onPressed: () => onTriage(TriageAction.today),
        ),
        _SecondaryAction(
          icon: Icons.bolt_rounded,
          label: messages.dailyOsNextTriageDoNow,
          onPressed: () => onTriage(TriageAction.doNow),
        ),
        _SecondaryAction(
          icon: Icons.timelapse_rounded,
          label: messages.dailyOsNextTriageDefer,
          onPressed: () => onTriage(TriageAction.defer),
        ),
        _SecondaryAction(
          icon: Icons.check_rounded,
          label: messages.dailyOsNextTriageDone,
          onPressed: () => onTriage(TriageAction.done),
        ),
        _GhostAction(
          icon: Icons.close_rounded,
          tooltip: messages.dailyOsNextTriageDrop,
          onPressed: () => onTriage(TriageAction.drop),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
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
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
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
    );
  }
}

class _GhostAction extends StatelessWidget {
  const _GhostAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return IconButton(
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      onPressed: onPressed,
      color: tokens.colors.text.lowEmphasis,
      style: IconButton.styleFrom(
        padding: EdgeInsets.all(tokens.spacing.step2),
      ),
    );
  }
}

class _DecisionPill extends StatelessWidget {
  const _DecisionPill({required this.action});

  final TriageAction action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final label = switch (action) {
      TriageAction.today => context.messages.dailyOsNextTriageConfirmToday,
      TriageAction.doNow => context.messages.dailyOsNextTriageConfirmDoNow,
      TriageAction.defer => context.messages.dailyOsNextTriageConfirmDefer,
      TriageAction.done => context.messages.dailyOsNextTriageConfirmDone,
      TriageAction.drop => context.messages.dailyOsNextTriageConfirmDrop,
    };
    return Container(
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        border: Border.all(color: teal.withValues(alpha: 0.32)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: teal),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: teal,
            ),
          ),
        ],
      ),
    );
  }
}
