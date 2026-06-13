import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Header row of the AI card: sparkle badge, "AI summary" + agent-name
/// link, the running spinner / refresh affordance / countdown pill /
/// cancel-timer cluster, and the Read more / Show less pill.
class TldrHeader extends StatelessWidget {
  const TldrHeader({
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
    this.playbackControl,
    super.key,
  });

  final String? agentName;
  final bool hasMore;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAgentTap;

  /// Slot for the playback control (the connector injects a Riverpod-aware
  /// TtsPlayButton here so the header stays framework-free). `null` when the
  /// feature flag is off, there's no TL;DR, or the engine is unsupported.
  final Widget? playbackControl;
  final bool isRunning;
  final bool showCountdown;
  final DateTime? nextWakeAt;
  final VoidCallback onRunNow;
  final VoidCallback onCancelTimer;
  final VoidCallback onCountdownExpired;

  /// Card width at or below which the countdown pill switches to its
  /// compact variant (tighter width / padding). Doesn't change the
  /// layout — the controls always sit inline on the right of the
  /// title — just trims the pill so the inline cluster reads less
  /// crowded on a phone-sized card.
  static const double _compactCountdownWidth = 360;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final hasAgentName = agentName != null && agentName!.trim().isNotEmpty;
    // The countdown cluster needs both `showCountdown` and a non-null
    // `nextWakeAt`; if the parent ever passes `showCountdown: true`
    // without a timestamp, fall back to the plain refresh affordance so
    // the header never ends up with no run / wake control at all.
    final hasCountdownCluster = showCountdown && nextWakeAt != null;

    Widget buildLeadingBlock({required double maxColumnWidth}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SparkleBadge(),
          const SizedBox(width: 10),
          // Cap the title column so an unusually long agent name softWraps
          // inside the column instead of pushing the whole leading block
          // wider than the card.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxColumnWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  messages.aiCardTitle,
                  softWrap: true,
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
                          softWrap: true,
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
        ],
      );
    }

    List<Widget> buildControls({required bool compactCountdown}) {
      return <Widget>[
        if (isRunning) const _ThinkingPill(),
        if (!isRunning && !hasCountdownCluster)
          _IconAffordance(
            icon: Icons.refresh_rounded,
            tooltip: messages.taskAgentRunNowTooltip,
            onPressed: onRunNow,
          ),
        if (hasCountdownCluster) ...[
          _IconAffordance(
            icon: Icons.play_arrow_rounded,
            tooltip: messages.taskAgentRunNowTooltip,
            onPressed: onRunNow,
          ),
          _CountdownPill(
            nextWakeAt: nextWakeAt!,
            onExpired: onCountdownExpired,
            compact: compactCountdown,
          ),
          _IconAffordance(
            icon: Icons.close_rounded,
            tooltip: messages.taskAgentCancelTimerTooltip,
            onPressed: onCancelTimer,
            compact: true,
          ),
        ],
        ?playbackControl,
        if (hasMore) _ReadMorePill(expanded: expanded, onPressed: onToggle),
      ];
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step4,
        tokens.spacing.step4,
        tokens.spacing.step3,
        tokens.spacing.step3,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Lay the leading block + control cluster out via a Wrap with
          // space-between alignment. When both clusters fit the card
          // width they share a single run with the gap between them;
          // when they truly don't fit (extreme narrow card or a long
          // agent name eating the title column), the controls fall to
          // a second run instead of crushing the title or overflowing.
          // Previously a fixed 360 px threshold dropped the controls
          // even when there was clearly room for them inline.
          final compact = constraints.maxWidth < _compactCountdownWidth;
          // 22 px badge + 10 px gap inside leadingBlock — leave the
          // rest of the card width for the title column.
          final maxColumnWidth = (constraints.maxWidth - 32).clamp(
            0.0,
            double.infinity,
          );
          // Wrap shrink-wraps each run to its children's combined
          // width by default, so WrapAlignment.spaceBetween only
          // spreads items when there is leftover space inside the
          // run. Forcing the Wrap to occupy the full available width
          // via a SizedBox makes the single-run case spread across
          // the card — leading block at the left edge, control
          // cluster at the right edge.
          return SizedBox(
            width: constraints.maxWidth,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                buildLeadingBlock(maxColumnWidth: maxColumnWidth),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: buildControls(compactCountdown: compact),
                ),
              ],
            ),
          );
        },
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

/// Labelled "Thinking…" chip shown while the agent is running. A labelled
/// chip (not a bare spinner) so agent activity never reads as audio loading.
/// Mirrors the [_ReadMorePill] pill chrome for visual consistency.
class _ThinkingPill extends StatelessWidget {
  const _ThinkingPill();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
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
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: reduceMotion ? 1.0 : null,
                color: ai.accent,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              context.messages.aiSummaryThinkingLabel,
              style: tokens.typography.styles.others.caption.copyWith(
                color: ai.accent,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
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
  const _CountdownPill({
    required this.nextWakeAt,
    required this.onExpired,
    this.compact = false,
  });

  final DateTime nextWakeAt;
  final VoidCallback onExpired;

  /// When true, draws the pill at a tighter width / padding so the
  /// stacked-mobile control row reads more compact alongside the play
  /// and cancel icons. The fixed pill width (rather than letting it
  /// shrink-wrap the digits) is kept on purpose so the row doesn't
  /// jiggle as the countdown ticks across digit-width changes.
  final bool compact;

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
    final compact = widget.compact;
    final countdownText = formatCountdown(countdownSeconds);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: ai.accentSoft,
          borderRadius: BorderRadius.circular(compact ? 9 : 10),
          border: Border.all(color: ai.border),
        ),
        child: Text(
          countdownText,
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
class TldrBody extends StatelessWidget {
  const TldrBody({
    required this.tldr,
    required this.expanded,
    required this.additionalReport,
    required this.onOpenInternals,
    super.key,
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
