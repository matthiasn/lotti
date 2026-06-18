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
    super.key,
  });

  final List<PendingSuggestion> open;
  final List<LedgerEntry> resolved;
  final bool historyOpen;
  final VoidCallback onToggleHistory;
  final bool confirmAllBusy;
  final Future<void> Function()? onConfirmAll;

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
                    _PendingPill(count: open.length),
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
            for (var i = 0; i < open.length; i++)
              Padding(
                // A clear gap between proposals (step4) against the tighter
                // step3 rhythm inside each row, so each reads as its own unit.
                padding: EdgeInsets.only(top: i == 0 ? 0 : tokens.spacing.step4),
                child: ProposalRow(
                  suggestion: open[i],
                  // Only the first pending row gets the swipe-affordance
                  // wiggle hint so the page doesn't pulse with every
                  // visible row.
                  isFirst: i == 0,
                ),
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
                  child: ProposalRow.fromLedger(entry: resolved[i]),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: hasItems
            ? ai.accent.withValues(alpha: 0.10)
            : ai.subtleWashStrong,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.messages.changeSetPendingCount(count),
        style: tokens.typography.styles.others.caption.copyWith(
          color: hasItems ? ai.accent : ai.metaText,
          fontWeight: FontWeight.w600,
          height: 1.1,
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
