import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/agent_model_sheet.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/shared/ds_choice_pills.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_suggestions_band.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:material_ui/material_ui.dart';

part 'relationship_briefing_card_relationship_briefing_card_state_part.dart';

/// The AI card for an enrolled person (design 2026-09-13, options 3a–3e and
/// 3g), in one of its five agent-owned states. One skeleton for all of
/// them: header with the status line, body, the proposals band, then a
/// footer with one quiet text action on the leading edge, one primary on
/// the trailing edge, and the meta line beneath.
class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.state,
    required this.announceArrival,
    required this.item,
    required this.checkInCount,
    required this.checkIns,
    required this.report,
    required this.agentState,
    required this.health,
    required this.totalTokens,
    required this.identityData,
    required this.modelMissing,
    required this.expanded,
    required this.requesting,
    required this.onToggleExpanded,
    required this.onOpenInternals,
    required this.onBrief,
    required this.onChooseModel,
  });

  final RelationshipAgentCardState state;

  /// The current face has just replaced another, so its status line is
  /// news this once.
  final bool announceArrival;
  final RelationshipListItem item;
  final int checkInCount;
  final List<CheckInEntry> checkIns;
  final AgentReportEntity? report;
  final AgentStateEntity? agentState;
  final RelationshipHealthMetrics? health;
  final int totalTokens;
  final TaskAgentModelIdentityViewData identityData;
  final bool modelMissing;
  final bool expanded;
  final bool requesting;
  final VoidCallback onToggleExpanded;
  final VoidCallback onOpenInternals;
  final VoidCallback? onBrief;
  final VoidCallback onChooseModel;

  /// The header's status line: what the agent is doing, or when the
  /// briefing was written and the band it read, in that state's colour.
  _StatusLine _status(BuildContext context, AppLocalizations messages) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final failedAt = agentState?.lastWakeFailedAt;
    final due = peopleDueDateOf(item);
    final latest = item.lastCheckIn;
    return switch (state) {
      RelationshipAgentCardState.noBriefing => _StatusLine(
        icon: LottiIcons.timer,
        tiers: [
          if (due != null)
            messages.relationshipAgentWatchingNextLook(
              relationshipDayLabelOf(context, due),
            ),
          messages.relationshipAgentWatching,
        ],
        color: ai.metaText,
      ),
      RelationshipAgentCardState.running => _StatusLine(
        leading: const DesignSystemSpinner(
          style: DesignSystemSpinnerStyle.plain,
          size: IconSizes.s,
        ),
        tiers: [messages.relationshipAgentWriting],
        // The spinner says busy; the words stay in the meta ink.
        color: ai.metaText,
        liveRegion: true,
      ),
      // A past event in the same grammar as "as of": how long ago, not a
      // clock time that reads as an appointment.
      RelationshipAgentCardState.failed => _StatusLine(
        icon: LottiIcons.error,
        tiers: [
          if (failedAt != null)
            messages.relationshipAgentLastRunFailed(
              relativeAgoLabel(messages, clock.now().difference(failedAt)),
            ),
          messages.relationshipAgentFailedPlain,
        ],
        color: tokens.colors.alert.error.ink,
        metaColor: ai.metaText,
        liveRegion: true,
      ),
      // The band as a colour as well as a word — a dot in the glyph slot,
      // in the band's own accent, the one status the card said only in text.
      RelationshipAgentCardState.current => _StatusLine(
        leading: switch (health?.band) {
          null => null,
          final band => DesignSystemBadge.dot(
            key: const ValueKey('relationship-agent-band-dot'),
            tone: relationshipHealthBandTone(band),
            excludeFromSemantics: true,
          ),
        },
        leadingSize: tokens.spacing.step3,
        tiers: [
          switch (health) {
            null => messages.goalDetailReadAsOf(_age(messages)),
            final health => messages.relationshipAgentAsOfBand(
              _age(messages),
              relationshipHealthBandLabel(context, health.band),
            ),
          },
        ],
        color: ai.metaText,
        // Live only as it arrives: a briefing finishing or a failure
        // clearing is news; the age ticking afterwards is not.
        liveRegion: announceArrival,
      ),
      // One line beside the age pill: the date is the tier that goes, so
      // the status never orphans a date under itself next to a pill.
      RelationshipAgentCardState.outOfDate => _StatusLine(
        icon: LottiIcons.warning,
        tiers: [
          if (latest != null) ...[
            messages.relationshipAgentOutOfDateNewCheckIn(
              relationshipDayLabelOf(context, latest.meta.dateFrom),
            ),
            messages.relationshipAgentOutOfDateNewCheckInShort,
          ],
          messages.taskAgentStatusOutOfDate,
        ],
        color: tokens.colors.alert.warning.ink,
        metaColor: ai.metaText,
        liveRegion: true,
      ),
      // Unreachable by construction: the card returns the plain
      // _NotEnrolledCard before this widget is ever built.
      // coverage:ignore-start
      RelationshipAgentCardState.notEnrolled => const _StatusLine(
        tiers: [''],
        color: Colors.transparent,
      ),
      // coverage:ignore-end
    };
  }

  String _age(AppLocalizations messages) =>
      relativeAgoLabel(messages, clock.now().difference(report!.createdAt));

  /// The header's trailing pill: on an out-of-date briefing, how old it
  /// is — a neutral tag, so the status line's warning ink is the one orange
  /// thing on the face. Open proposals are not counted here: the band
  /// beneath carries its own count, and a state said twice is a state said
  /// badly.
  Widget? _pill(BuildContext context, AppLocalizations messages) {
    if (state != RelationshipAgentCardState.outOfDate) return null;
    final days = clock.now().difference(report!.createdAt).inDays;
    if (days < 1) return null;
    final ai = context.designTokens.colors.aiCard;
    return DsPill(
      key: const ValueKey('relationship-briefing-age'),
      // Outlined in the meta ink: a fact beside the status line, never a
      // second thing competing with it for the first read.
      variant: DsPillVariant.outline,
      shape: DsPillShape.tag,
      color: ai.metaText,
      label: messages.relationshipBriefingAge(days),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final current = report;
    final body = switch (state) {
      RelationshipAgentCardState.noBriefing => Text(
        messages.relationshipAgentNoBriefingBody(checkInCount),
        key: const ValueKey('relationship-agent-body'),
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: ai.bodyText,
        ),
      ),
      // An update keeps the briefing it will replace in view — the spinner
      // on the status line is the only thing that says it is running, and
      // the new briefing swaps in when it lands. A first briefing has
      // nothing to show yet, so the status line stands alone.
      RelationshipAgentCardState.running => switch (current) {
        null => null,
        final report => TldrBody(
          key: const ValueKey('relationship-briefing-body'),
          disclosureKey: const ValueKey('relationship-briefing-expand'),
          bodyStyle: tokens.typography.styles.body.bodyMedium,
          tldr: resolveReportTldr(report),
          expanded: expanded,
          additionalReport: resolveReportAdditional(report),
          onToggle: onToggleExpanded,
        ),
      },
      // A failed run says what went wrong — and, like an update in
      // progress, keeps the briefing it failed to replace. The reader came
      // for what to bring up with this person; a provider error is a reason
      // to retry, not a reason to take that away. The kept briefing is
      // dated, because the status line above now dates the failure instead.
      RelationshipAgentCardState.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            modelMissing
                ? messages.relationshipAgentFailedNoModel
                : messages.relationshipAgentFailedBody,
            key: const ValueKey('relationship-agent-body'),
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: ai.bodyText,
            ),
          ),
          if (current != null) ...[
            SizedBox(height: tokens.spacing.step4),
            Text(
              messages.goalDetailReadAsOf(_age(messages)),
              key: const ValueKey('relationship-briefing-kept-age'),
              style: tokens.typography.styles.others.caption.copyWith(
                color: ai.metaText,
              ),
            ),
            SizedBox(height: tokens.spacing.step1),
            TldrBody(
              key: const ValueKey('relationship-briefing-body'),
              disclosureKey: const ValueKey('relationship-briefing-expand'),
              bodyStyle: tokens.typography.styles.body.bodyMedium,
              tldr: resolveReportTldr(current),
              expanded: expanded,
              additionalReport: resolveReportAdditional(current),
              onToggle: onToggleExpanded,
            ),
          ],
        ],
      ),
      RelationshipAgentCardState.current ||
      RelationshipAgentCardState.outOfDate => TldrBody(
        key: const ValueKey('relationship-briefing-body'),
        disclosureKey: const ValueKey('relationship-briefing-expand'),
        // The reading faces at the same size as the waiting faces' prose:
        // one body tier across all seven.
        bodyStyle: tokens.typography.styles.body.bodyMedium,
        tldr: resolveReportTldr(current),
        expanded: expanded,
        additionalReport: resolveReportAdditional(current),
        onToggle: onToggleExpanded,
      ),
      // Unreachable by construction, see _status.
      // coverage:ignore-start
      RelationshipAgentCardState.notEnrolled => const SizedBox.shrink(),
      // coverage:ignore-end
    };

    // Whether the body closes on the briefing, whose disclosure row brings
    // its own trailing gap.
    final endsInBriefing =
        body is TldrBody ||
        (state == RelationshipAgentCardState.failed && current != null);

    // The quiet text actions start the footer's row: their label sits on
    // the card's content column, not a button inset in from it.
    //
    // *See activity* is this card's one worded door to the agent's
    // internals (the header opens them too). The shared disclosure row's
    // "Open agent internals" is not passed to the reading faces above: on
    // the task card it is the only such door, here it was a third one to the
    // same place, in vocabulary ("internals") the reader has no use for.
    // Quiet, not tertiary: tertiary wears the accent, and beside the footer's
    // one filled primary that made two equal teal links on a card that has
    // one next step. The door stays; the colour says which comes first.
    final seeActivity = DesignSystemButton(
      key: const ValueKey('relationship-agent-see-activity'),
      label: messages.relationshipAgentSeeActivity,
      variant: DesignSystemButtonVariant.quiet,
      alignsLabelToLeadingEdge: true,
      tapTargetSize: MaterialTapTargetSize.padded,
      onPressed: onOpenInternals,
    );
    final updateNow = DesignSystemButton(
      key: const ValueKey('relationship-brief-me'),
      tapTargetSize: MaterialTapTargetSize.padded,
      label: messages.taskAgentUpdateNow,
      leadingIcon: LottiIcons.refresh,
      // Accent only when the briefing actually needs regenerating. On a
      // current briefing the card's offer is the reading, not the rewrite,
      // and a filled `Update now` made maintenance the loudest thing on a
      // card whose job is to be read.
      variant: switch (state) {
        RelationshipAgentCardState.outOfDate =>
          DesignSystemButtonVariant.primary,
        RelationshipAgentCardState.current =>
          DesignSystemButtonVariant.tertiary,
        _ => DesignSystemButtonVariant.secondary,
      },
      onPressed: onBrief,
    );
    final ({Widget? leading, Widget? action}) footer = switch (state) {
      // Every face has its quiet door: a check-in before the first
      // briefing, the activity log while one is being written.
      // Even here the card does not borrow the bar's verb: the body
      // already says a check-in is what the agent needs, and the bar
      // below offers it as the page's primary.
      RelationshipAgentCardState.noBriefing => (
        leading: seeActivity,
        action: DesignSystemButton(
          key: const ValueKey('relationship-brief-me'),
          tapTargetSize: MaterialTapTargetSize.padded,
          label: messages.relationshipAgentBriefNow,
          leadingIcon: LottiIcons.aiSpark,
          onPressed: onBrief,
        ),
      ),
      RelationshipAgentCardState.running => (
        leading: seeActivity,
        action: null,
      ),
      RelationshipAgentCardState.failed => (
        leading: seeActivity,
        action: modelMissing
            ? DesignSystemButton(
                key: const ValueKey('relationship-agent-choose-model'),
                tapTargetSize: MaterialTapTargetSize.padded,
                label: messages.inferenceProfileChooseModelTitle,
                onPressed: onChooseModel,
              )
            : DesignSystemButton(
                key: const ValueKey('relationship-brief-me'),
                tapTargetSize: MaterialTapTargetSize.padded,
                label: messages.relationshipAgentTryAgain,
                leadingIcon: LottiIcons.refresh,
                onPressed: onBrief,
              ),
      ),
      // Once a briefing exists the card owns only the agent's own verbs.
      // Logging a check-in and calling are *doing* verbs, and the sticky
      // action bar carries both of those on every viewport — offering them
      // here too put the same two actions on screen twice, each one loud in
      // one place and quiet in the other, so neither read as the primary.
      // Being overdue changes what the bar's primary is for, not who owns
      // it, so the two current faces are now one arm.
      RelationshipAgentCardState.current ||
      RelationshipAgentCardState.outOfDate => (
        leading: seeActivity,
        action: updateNow,
      ),
      // Unreachable by construction, see _status.
      // coverage:ignore-start
      RelationshipAgentCardState.notEnrolled => (leading: null, action: null),
      // coverage:ignore-end
    };

    // Only a current briefing can say what it was written from: on an
    // out-of-date one the count already includes the check-in it missed.
    // And only once the reader has opened it — collapsed, the summary
    // outweighs its provenance, which is the point of a summary.
    // The sources line is part of the expanded reading — unless there is
    // nothing to expand (no report beyond the summary), when it would
    // otherwise be unreachable.
    final hasMore =
        resolveReportAdditional(current)?.trim().isNotEmpty ?? false;
    final showsSources =
        state == RelationshipAgentCardState.current && (expanded || !hasMore);

    return AgentSummaryCardSurface(
      key: const ValueKey('relationship-briefing-card'),
      children: [
        _BriefingHeader(
          status: _status(context, messages),
          trailing: _pill(context, messages),
          onTap: onOpenInternals,
        ),
        // The band above says "Strained"; this says why. The contract has
        // always required it — "One sentence tracing the band to specific
        // check-in evidence" — and the workflow has always stored it, but
        // no widget read it, so a verdict on a person arrived with no way
        // to check it. It sits with the band rather than behind the
        // disclosure: an unexplained verdict is not a summary.
        if (state == RelationshipAgentCardState.current && health != null)
          _BandRationale(text: health!.rationale, color: ai.metaText),
        if (body != null)
          Padding(
            // No bottom inset under TldrBody: its disclosure row carries the
            // trailing gap inside its tap target. The plain-text bodies bring
            // one of their own.
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.cardPadding,
              0,
              tokens.spacing.cardPadding,
              endsInBriefing ? 0 : tokens.spacing.step4,
            ),
            child: body,
          ),
        RelationshipSuggestionsBand(
          relationshipId: item.relationship.id,
          checkIns: checkIns,
          showHistory: expanded,
        ),
        _AgentCardFooter(
          leading: footer.leading,
          action: footer.action,
          identity: TaskAgentIdentityRegion(
            data: identityData,
            onSetupTap: onChooseModel,
            // This row is the disclosure a briefing starts on (ADR 0061):
            // no width or text size may shed the provider from it.
            alwaysNameProvider: true,
            trailingMeta: totalTokens > 0
                ? messages.agentConversationTokenCount(
                    NumberFormat.compact(
                      locale: Localizations.localeOf(context).toString(),
                    ).format(totalTokens),
                  )
                : null,
          ),
          meta: showsSources
              ? _MetaLine(
                  label: messages.relationshipAgentSources(checkInCount),
                  color: ai.metaText,
                )
              : null,
        ),
      ],
    );
  }
}
