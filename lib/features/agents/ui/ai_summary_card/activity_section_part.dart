part of '../ai_summary_card.dart';

/// Footer at the bottom of the card. Hosts the agent avatar, the
/// recent-actions count, and the See activity / Hide activity pill that
/// drives the inline activity-list expansion above it.
class _ActivityFooter extends StatelessWidget {
  const _ActivityFooter({
    required this.count,
    required this.open,
    required this.onToggle,
    required this.onOpenInternals,
  });

  final int count;
  final bool open;
  final VoidCallback? onToggle;
  final VoidCallback onOpenInternals;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    return Container(
      decoration: BoxDecoration(
        color: ai.footerWash,
        border: Border(top: BorderSide(color: ai.rowBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Tooltip(
            message: messages.aiCardAgentNameTooltip,
            child: GestureDetector(
              onTap: onOpenInternals,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      ai.accent.withValues(alpha: 0.6),
                      ai.accent.withValues(alpha: 0.25),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 12,
                  color: ai.background,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              messages.aiCardRecentActions(count),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: ai.bodyText,
                height: 1.2,
              ),
            ),
          ),
          if (onToggle != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: ai.rowBorderStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        open
                            ? messages.aiCardHideActivity
                            : messages.aiCardSeeActivity,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: ai.metaText,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        size: 14,
                        color: ai.metaText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline list of resolved ledger entries that expands above the
/// activity footer when "See activity" is tapped. Capped at six rows;
/// the canonical full list lives in the agent internals panel.
class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activity, required this.agentName});

  final List<LedgerEntry> activity;
  final String? agentName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final visible = activity.take(6).toList(growable: false);
    return Container(
      decoration: BoxDecoration(
        color: ai.footerWashOpen,
        border: Border(top: BorderSide(color: ai.rowBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              messages.aiCardActivitySectionLabel,
              style: tokens.typography.styles.others.caption.copyWith(
                color: ai.faintMeta,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                height: 1,
              ),
            ),
          ),
          for (final entry in visible)
            _ActivityRow(entry: entry, agentName: agentName),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.agentName});

  final LedgerEntry entry;
  final String? agentName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final kind = _resolveKind(entry.toolName, entry.args);
    final iconData = _activityIcon(kind);
    final color = _activityColor(context, kind);
    final time = _relativeTime(context, entry.resolvedAt ?? entry.createdAt);
    final agent = agentName?.trim().isNotEmpty == true
        ? agentName!.trim()
        : null;
    final meta = agent != null ? '$time · $agent' : time;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            height: 18,
            child: Center(child: Icon(iconData, size: 12, color: color)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.humanSummary,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.35,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    meta,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: ai.faintMeta,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(_ProposalKind kind) {
    switch (kind) {
      case _ProposalKind.add:
        return Icons.add;
      case _ProposalKind.status:
        return Icons.check_circle_outline;
      case _ProposalKind.label:
        return Icons.label_outline;
      case _ProposalKind.priority:
        return Icons.flag_outlined;
      case _ProposalKind.estimate:
        return Icons.timer_outlined;
      case _ProposalKind.due:
        return Icons.calendar_today_outlined;
      case _ProposalKind.remove:
        return Icons.remove;
      case _ProposalKind.update:
        return Icons.edit_outlined;
    }
  }

  Color _activityColor(BuildContext context, _ProposalKind kind) {
    final palette = context.designTokens.colors.proposalKind;
    switch (kind) {
      case _ProposalKind.add:
        return palette.add.color;
      case _ProposalKind.status:
        return palette.status.color;
      case _ProposalKind.label:
        return palette.label.color;
      case _ProposalKind.priority:
        return palette.priority.color;
      case _ProposalKind.estimate:
        return palette.estimate.color;
      case _ProposalKind.due:
        return palette.due.color;
      case _ProposalKind.remove:
        return palette.remove.color;
      case _ProposalKind.update:
        return palette.update.color;
    }
  }

  String _relativeTime(BuildContext context, DateTime when) {
    final messages = context.messages;
    final now = clock.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return messages.aiCardActivityRelativeNow;
    if (diff.inMinutes < 60) {
      return messages.aiCardActivityRelativeMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return messages.aiCardActivityRelativeHours(diff.inHours);
    }
    if (diff.inDays < 7) {
      return messages.aiCardActivityRelativeDays(diff.inDays);
    }
    final weeks = math.max(1, diff.inDays ~/ 7);
    return messages.aiCardActivityRelativeWeeks(weeks);
  }
}
