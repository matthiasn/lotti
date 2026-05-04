part of '../ai_summary_card.dart';

/// Header row of the AI card: sparkle badge, "AI summary" + agent-name
/// link, the running spinner / refresh affordance / countdown pill /
/// cancel-timer cluster, and the Read more / Show less pill.
class _TldrHeader extends StatelessWidget {
  const _TldrHeader({
    required this.agentName,
    required this.hasMore,
    required this.expanded,
    required this.onToggle,
    required this.onAgentTap,
    required this.isRunning,
    required this.showCountdown,
    required this.nextWakeAt,
    required this.onRunNow,
    required this.onCancelTimer,
    required this.onCountdownExpired,
  });

  final String? agentName;
  final bool hasMore;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAgentTap;
  final bool isRunning;
  final bool showCountdown;
  final DateTime? nextWakeAt;
  final VoidCallback onRunNow;
  final VoidCallback onCancelTimer;
  final VoidCallback onCountdownExpired;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final hasAgentName = agentName != null && agentName!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
      child: Row(
        children: [
          const _SparkleBadge(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messages.aiCardTitle,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: ai.titleText,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                if (hasAgentName)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: GestureDetector(
                      onTap: onAgentTap,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          agentName!.trim(),
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: ai.metaText,
                                decoration: TextDecoration.underline,
                                decorationColor: ai.metaText.withValues(
                                  alpha: 0.40,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isRunning)
            SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ai.accent,
                  ),
                ),
              ),
            ),
          // The countdown cluster needs both `showCountdown` and a
          // non-null `nextWakeAt`; if the parent ever passes
          // `showCountdown: true` without a timestamp, fall back to
          // the plain refresh affordance so the header never ends up
          // with no run / wake control at all.
          if (!isRunning && (!showCountdown || nextWakeAt == null))
            _IconAffordance(
              icon: Icons.refresh_rounded,
              tooltip: messages.taskAgentRunNowTooltip,
              onPressed: onRunNow,
            ),
          if (showCountdown && nextWakeAt != null) ...[
            _IconAffordance(
              icon: Icons.play_arrow_rounded,
              tooltip: messages.taskAgentRunNowTooltip,
              onPressed: onRunNow,
            ),
            _CountdownPill(
              nextWakeAt: nextWakeAt!,
              onExpired: onCountdownExpired,
            ),
            _IconAffordance(
              icon: Icons.close_rounded,
              tooltip: messages.taskAgentCancelTimerTooltip,
              onPressed: onCancelTimer,
              compact: true,
            ),
          ],
          if (hasMore) _ReadMorePill(expanded: expanded, onPressed: onToggle),
        ],
      ),
    );
  }
}

class _SparkleBadge extends StatelessWidget {
  const _SparkleBadge();

  @override
  Widget build(BuildContext context) {
    final ai = context.designTokens.colors.aiCard;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ai.accentSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.auto_awesome_rounded, size: 14, color: ai.accent),
    );
  }
}

class _ReadMorePill extends StatelessWidget {
  const _ReadMorePill({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final label = expanded ? messages.aiCardShowLess : messages.aiCardReadMore;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: ai.accentSoft,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: ai.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: ai.accent,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                  size: 14,
                  color: ai.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAffordance extends StatelessWidget {
  const _IconAffordance({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ai = context.designTokens.colors.aiCard;
    return IconButton(
      icon: Icon(icon, size: compact ? 16 : 18, color: ai.metaText),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: compact ? 24 : 28,
        minHeight: compact ? 24 : 28,
      ),
      onPressed: onPressed,
    );
  }
}

class _CountdownPill extends StatefulWidget {
  const _CountdownPill({required this.nextWakeAt, required this.onExpired});

  final DateTime nextWakeAt;
  final VoidCallback onExpired;

  @override
  State<_CountdownPill> createState() => _CountdownPillState();
}

class _CountdownPillState extends State<_CountdownPill>
    with WakeCountdownState<_CountdownPill> {
  @override
  DateTime get nextWakeAt => widget.nextWakeAt;

  @override
  void didUpdateWidget(covariant _CountdownPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextWakeAt != widget.nextWakeAt) {
      resyncCountdown();
    }
  }

  @override
  void onCountdownExpired() => widget.onExpired();

  @override
  Widget build(BuildContext context) {
    if (countdownSeconds <= 0) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: ai.accentSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ai.border),
        ),
        child: Text(
          formatCountdown(countdownSeconds),
          textAlign: TextAlign.center,
          style: tokens.typography.styles.others.caption.copyWith(
            color: ai.accent,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Body of the AI card under the header. Always renders the TLDR
/// markdown; when [expanded] is true it additionally renders the full
/// report markdown and a pill that opens the agent internals panel.
class _TldrBody extends StatelessWidget {
  const _TldrBody({
    required this.tldr,
    required this.expanded,
    required this.additionalReport,
    required this.onOpenInternals,
  });

  final String tldr;
  final bool expanded;
  final String? additionalReport;
  final VoidCallback onOpenInternals;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final bodyStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: ai.bodyText,
      height: 1.55,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectionArea(child: AgentMarkdownView(tldr, style: bodyStyle)),
          if (expanded && additionalReport != null) ...[
            const SizedBox(height: 14),
            SelectionArea(
              child: AgentMarkdownView(additionalReport!, style: bodyStyle),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: _OpenInternalsPill(onPressed: onOpenInternals),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpenInternalsPill extends StatelessWidget {
  const _OpenInternalsPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: ai.accentSoft,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: ai.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 14, color: ai.accent),
              const SizedBox(width: 6),
              Text(
                context.messages.aiCardOpenAgentInternals,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ai.accent,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
