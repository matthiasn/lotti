import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_part.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Proposals section sandwiched between the TLDR body and the activity
/// footer. Always shows the section title + pending count badge +
/// optional "Confirm all" button. The body is either an empty-state
/// placeholder or a vertical list of [ProposalRow]s. Resolved entries
/// are rendered through [_HistoryToggle] + a hidden-by-default list.
class ProposalsSection extends StatelessWidget {
  const ProposalsSection({
    required this.open,
    required this.resolved,
    required this.historyOpen,
    required this.onToggleHistory,
    required this.confirmAllBusy,
    required this.onConfirmAll,
    required this.confirmAllPulse,
    this.pendingCount,
    this.onResolveStart,
    this.onResolveEnd,
    this.settling = false,
    super.key,
  });

  final List<PendingSuggestion> open;

  /// The count to show in the pending pill. Excludes rows that are committed
  /// and collapsing out, so the count ticks down in sync with the action.
  /// Falls back to `open.length` when not supplied.
  final int? pendingCount;
  final List<LedgerEntry> resolved;
  final bool historyOpen;
  final VoidCallback onToggleHistory;
  final bool confirmAllBusy;
  final Future<void> Function()? onConfirmAll;

  /// Bumped by the shell on each "Confirm all" press; forwarded to the rows so
  /// they cascade their confirm pop top-to-bottom.
  final int confirmAllPulse;

  /// Forwarded to each open [ProposalRow] so the shell can keep a row mounted
  /// (collapsing in place) while it leaves, instead of the provider snapping
  /// it out. See `_AiSummaryShellState`.
  final void Function(PendingSuggestion suggestion)? onResolveStart;
  final void Function(PendingSuggestion suggestion, {required bool removed})?
  onResolveEnd;

  /// True while at least one row is committing/collapsing, so the surviving
  /// rows guard taps against a mis-targeted second action while they slide.
  final bool settling;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title block on the left (icon + label + pending-count
          // pill, wraps internally if the card is too narrow to fit
          // them on one line) and the Confirm-all button pinned to
          // the right edge so it lines up with the Read-more pill in
          // the header above. `Expanded` collapses harmlessly on
          // empty/single-child rows when the button isn't shown.
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: 16,
                      color: ai.accent,
                    ),
                    Text(
                      messages.changeSetCardTitle,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: ai.titleText,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    _PendingPill(count: pendingCount ?? open.length),
                  ],
                ),
              ),
              if (onConfirmAll != null)
                _ConfirmAllButton(
                  busy: confirmAllBusy,
                  onPressed: onConfirmAll!,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (open.isEmpty)
            const _EmptyProposalsRow()
          else
            // No inter-row Padding here: each open row owns a trailing gap
            // (step4) *inside* its collapse subtree, so the gap closes with the
            // row when it leaves — no leftover spacing to snap on prune.
            for (var i = 0; i < open.length; i++)
              ProposalRow(
                // Stable identity (set id + item index) so the row's
                // timer/animation/busy state stays bound to its suggestion
                // when the open list mutates (e.g. confirm-all), instead of
                // index-based element reuse transferring it to a sibling.
                key: ValueKey(
                  'open-${open[i].changeSet.id}-${open[i].itemIndex}',
                ),
                suggestion: open[i],
                // Only the first pending row gets the swipe-affordance
                // wiggle hint so the page doesn't pulse with every
                // visible row.
                isFirst: i == 0,
                confirmAllPulse: confirmAllPulse,
                cascadeIndex: i,
                onResolveStart: onResolveStart,
                onResolveEnd: onResolveEnd,
                settling: settling,
                pendingCount: pendingCount ?? open.length,
              ),
          if (resolved.isNotEmpty) ...[
            const SizedBox(height: 10),
            _HistoryToggle(
              open: historyOpen,
              count: resolved.length,
              onPressed: onToggleHistory,
            ),
            if (historyOpen) ...[
              const SizedBox(height: 8),
              for (var i = 0; i < resolved.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: ProposalRow.fromLedger(
                    key: ValueKey(
                      'resolved-${resolved[i].changeSetId}-${resolved[i].itemIndex}',
                    ),
                    entry: resolved[i],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PendingPill extends StatelessWidget {
  const _PendingPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final hasItems = count > 0;
    // Fade-through on count change (a value transition, not a spatial one), so
    // the number resolves rather than hard-swapping. Instant under reduced
    // motion. Keyed by count so the switcher cross-fades only when it changes.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: hasItems
            ? ai.accent.withValues(alpha: 0.10)
            : ai.subtleWashStrong,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : MotionDurations.medium1,
        switchInCurve: MotionCurves.standard,
        switchOutCurve: MotionCurves.standard,
        child: Text(
          context.messages.changeSetPendingCount(count),
          key: ValueKey(count),
          style: tokens.typography.styles.others.caption.copyWith(
            color: hasItems ? ai.accent : ai.metaText,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _ConfirmAllButton extends StatelessWidget {
  const _ConfirmAllButton({required this.busy, required this.onPressed});

  final bool busy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    // The card's primary action: a filled tonal accent pill (was a plain
    // text link), so the eye lands on it. Mirrors the header pills' chrome
    // — an accentSoft fill with an accent-tinted border — but reads as the
    // hero affordance via the leading double-check glyph.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onPressed.call,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step2,
          ),
          decoration: BoxDecoration(
            color: ai.accentSoft,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(color: ai.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ai.accent,
                  ),
                )
              else
                Icon(Icons.done_all_rounded, size: 16, color: ai.accent),
              SizedBox(width: tokens.spacing.step2),
              Text(
                context.messages.changeSetConfirmAll,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ai.accent,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProposalsRow extends StatelessWidget {
  const _EmptyProposalsRow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ai.subtleWash,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ai.subtleBorder),
      ),
      child: Center(
        child: Text(
          context.messages.aiCardEmptyProposals,
          style: tokens.typography.styles.others.caption.copyWith(
            color: ai.metaText,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _HistoryToggle extends StatelessWidget {
  const _HistoryToggle({
    required this.open,
    required this.count,
    required this.onPressed,
  });

  final bool open;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                open ? Icons.keyboard_arrow_down : Icons.chevron_right,
                size: 14,
                color: ai.metaText,
              ),
              const SizedBox(width: 4),
              Text(
                context.messages.aiCardHistoryToggle(count),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ai.metaText,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
