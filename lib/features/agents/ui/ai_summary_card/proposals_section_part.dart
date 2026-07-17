import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_entrance.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Proposals section sandwiched between the TLDR body and the controls
/// footer. Always shows the section title + pending count badge +
/// optional "Confirm all" button. With open proposals the body is a
/// vertical list of [ProposalRow]s; with none, the "0 pending" pill
/// already carries the state, so no placeholder band is rendered.
/// Resolved entries are rendered through [_HistoryToggle] + a
/// hidden-by-default list.
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
    this.newlyArrived = const {},
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

  /// Fingerprints whose row should play an entrance reveal (a proposal that
  /// arrived after the initial load). Rows not in this set appear instantly.
  final Set<String> newlyArrived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.cardPadding,
        vertical: tokens.spacing.step4,
      ),
      // Same reading measure as the summary: full-width rows strand the
      // accept/reject actions at the far card edge on wide surfaces.
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TldrBody.maxReadingWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // One clean header line: icon + title + pending pill. All
              // list-level operations live on the bottom rail instead, so
              // the header never has to squeeze or wrap a button.
              Row(
                children: [
                  Icon(
                    Icons.fact_check_outlined,
                    size: tokens.spacing.step5,
                    color: ai.titleText,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Flexible(
                    child: Text(
                      messages.changeSetCardTitle,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: ai.titleText),
                    ),
                  ),
                  // At zero the pill is furniture — the absence of rows
                  // already says it, so the count earns its ink only when
                  // there is something to act on.
                  if ((pendingCount ?? open.length) > 0) ...[
                    SizedBox(width: tokens.spacing.step3),
                    _PendingPill(count: pendingCount ?? open.length),
                  ],
                ],
              ),
              if (open.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step3),
                // No inter-row Padding here: each open row owns a trailing gap
                // (step4) *inside* its collapse subtree, so the gap closes with the
                // row when it leaves — no leftover spacing to snap on prune.
                for (var i = 0; i < open.length; i++)
                  // A newly arrived proposal eases its own height open; the initial
                  // batch (and a row re-appearing mid-collapse) appears instantly.
                  // SizeFadeEntrance is a SizeTransition, so it composes with the
                  // row's own collapse on exit without fighting it.
                  SizeFadeEntrance(
                    key: ValueKey(
                      'enter-${open[i].changeSet.id}-${open[i].itemIndex}',
                    ),
                    animate: newlyArrived.contains(open[i].fingerprint),
                    child: ProposalRow(
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
                  ),
              ],
              // Bottom rail: the list-level operations share one line —
              // History disclosure left, batch confirm right. Open rows
              // already end with their own trailing gap, so only the empty
              // list needs one here.
              if (resolved.isNotEmpty || onConfirmAll != null) ...[
                if (open.isEmpty) SizedBox(height: tokens.spacing.step3),
                Row(
                  children: [
                    if (resolved.isNotEmpty)
                      _HistoryToggle(
                        open: historyOpen,
                        count: resolved.length,
                        onPressed: onToggleHistory,
                      ),
                    const Spacer(),
                    if (onConfirmAll != null)
                      DesignSystemButton(
                        label: messages.changeSetConfirmAll,
                        leadingIcon: Icons.done_all_rounded,
                        variant: DesignSystemButtonVariant.outlined,
                        isLoading: confirmAllBusy,
                        onPressed: () => unawaited(onConfirmAll!()),
                      ),
                  ],
                ),
              ],
              if (resolved.isNotEmpty && historyOpen) ...[
                SizedBox(height: tokens.spacing.step2),
                for (var i = 0; i < resolved.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      top: i == 0 ? 0 : tokens.spacing.step2,
                    ),
                    child: ProposalRow.fromLedger(
                      key: ValueKey(
                        'resolved-${resolved[i].changeSetId}-${resolved[i].itemIndex}',
                      ),
                      entry: resolved[i],
                    ),
                  ),
              ],
            ],
          ),
        ),
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
    // Neutral always: a status count is not an action and must not outshine
    // the confirm buttons. Fade-through on count change (a value transition,
    // not a spatial one), so the number resolves rather than hard-swapping.
    // Instant under reduced motion. Keyed by count so the switcher
    // cross-fades only when it changes.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: ai.subtleWashStrong,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : MotionDurations.medium1,
        switchInCurve: MotionCurves.standard,
        switchOutCurve: MotionCurves.standard,
        child: Text(
          context.messages.changeSetPendingCount(count),
          key: ValueKey(count),
          style: tokens.typography.styles.others.caption.copyWith(
            color: ai.metaText,
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
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
          // Quiet meta like the footer's model line — the chevron and hit
          // target signal interactivity without spending accent on a
          // low-priority disclosure.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                open
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.chevron_right_rounded,
                size: tokens.spacing.step5,
                color: ai.metaText,
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                context.messages.aiCardHistoryToggle(count),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: ai.metaText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
