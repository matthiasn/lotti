import 'dart:async';

import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_collapse.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_entrance.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Proposals section sandwiched between the TLDR body and the controls
/// footer: section title + pending count badge, the vertical list of
/// [ProposalRow]s, and an optional "Confirm all" rail.
///
/// The card renders this only while [open] is non-empty. A header over an
/// empty band said nothing the absence of rows did not already say, and cost
/// a divider plus two paddings to say it — so with nothing to propose there
/// is no section at all. Resolved entries live in [ProposalHistorySection],
/// which the card shows only with the report expanded.
class ProposalsSection extends StatelessWidget {
  const ProposalsSection({
    required this.open,
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
  final bool confirmAllBusy;

  /// Confirms every open row. Null when the rail has nothing to offer — one
  /// pending row, or none — which collapses the rail rather than unmounting
  /// it; see the rail's own note in [build].
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
        vertical: tokens.spacing.step3,
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
                    LottiIcons.factCheck,
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
                  // there is something to act on. It fades rather than
                  // unmounts: it is the tallest thing on this line, and
                  // zero is only ever reached mid-sweep, when dropping it
                  // stepped the whole header up by the difference.
                  SizedBox(width: tokens.spacing.step3),
                  _PendingPill(count: pendingCount ?? open.length),
                ],
              ),
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
              // Bottom rail: the one list-level operation, trailing-aligned.
              // Open rows already end with their own trailing gap, so the
              // rail needs none of its own. Always mounted and collapsed
              // away rather than conditionally built: when a confirm leaves
              // a single row behind, the rail eases out on the same clock as
              // the row that just left instead of vanishing in one frame and
              // snapping the last row up by its height. A section that never
              // needed the rail starts collapsed, without animation.
              SizeFadeCollapse(
                key: const ValueKey('proposalBottomRail'),
                collapsed: onConfirmAll == null,
                duration: ProposalMotion.collapse,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: DesignSystemButton(
                    label: messages.changeSetConfirmAll,
                    leadingIcon: LottiIcons.confirmAll,
                    variant: DesignSystemButtonVariant.outlined,
                    isLoading: confirmAllBusy,
                    onPressed: onConfirmAll == null
                        ? null
                        : () => unawaited(onConfirmAll!()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolved proposals, disclosed on their own section band.
///
/// Split out of [ProposalsSection] because the two answer different
/// questions: what still needs a decision, and what was already decided. The
/// card shows this only with the report expanded — in the collapsed reading
/// state a permanently visible "History · n" row was the third disclosure
/// competing for the same glance, and none of it was the summary the user
/// came for.
class ProposalHistorySection extends StatelessWidget {
  const ProposalHistorySection({
    required this.resolved,
    required this.open,
    required this.onToggle,
    super.key,
  });

  /// Resolved ledger entries, newest first. Never empty — the card omits the
  /// whole section rather than render an empty disclosure.
  final List<LedgerEntry> resolved;

  /// Whether the resolved list is disclosed.
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.cardPadding,
        // The toggle's own 40-high tap target carries the vertical rhythm
        // while collapsed; the band adds only the hairline's breathing room.
        vertical: tokens.spacing.step1,
      ),
      // Same reading measure as the summary and the proposals above it.
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TldrBody.maxReadingWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HistoryToggle(
                open: open,
                count: resolved.length,
                onPressed: onToggle,
              ),
              if (open) ...[
                SizedBox(height: tokens.spacing.step2),
                for (var i = 0; i < resolved.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      top: i == 0 ? 0 : tokens.spacing.step2,
                      bottom: i == resolved.length - 1
                          ? tokens.spacing.step3
                          : 0,
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
    final duration = reduceMotion ? Duration.zero : MotionDurations.medium1;
    // Zero fades the pill out in place — see the header row in
    // [ProposalsSection.build] for why it keeps its footprint.
    return ExcludeSemantics(
      excluding: count == 0,
      child: AnimatedOpacity(
        opacity: count > 0 ? 1 : 0,
        duration: duration,
        curve: MotionCurves.standard,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step1,
          ),
          decoration: BoxDecoration(
            color: ai.subtleWashStrong,
            borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          ),
          child: AnimatedSwitcher(
            duration: duration,
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
    return MergeSemantics(
      child: Semantics(
        button: true,
        expanded: open,
        // Text-link hover: the link's own ink brightens; no fill behind it,
        // which read as a phantom button around the quiet words.
        child: DsQuietInk(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          builder: (context, highlighted) {
            final ink = highlighted ? ai.bodyText : ai.metaText;
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing.step8),
              // Quiet meta like the footer's model line — the chevron and hit
              // target signal interactivity without spending accent on a
              // low-priority disclosure.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    open ? LottiIcons.chevronDown : LottiIcons.chevronRight,
                    size: tokens.spacing.step5,
                    color: ink,
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  Text(
                    context.messages.aiCardHistoryToggle(count),
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: ink,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
