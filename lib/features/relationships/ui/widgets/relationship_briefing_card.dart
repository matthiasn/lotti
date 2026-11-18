import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_automation_row.dart';
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
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/shared/ds_choice_pills.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form.dart';
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
    required this.identityData,
    required this.modelMissing,
    required this.expanded,
    required this.onToggleExpanded,
    required this.folded,
    required this.onOpen,
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
  final TaskAgentModelIdentityViewData identityData;
  final bool modelMissing;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  /// Whether a calm face shows its header row alone ([RelationshipBriefingCard.folded]).
  final bool folded;
  final VoidCallback onOpen;
  final VoidCallback onOpenInternals;
  final VoidCallback? onBrief;
  final VoidCallback onChooseModel;

  /// The faces that ask nothing of the reader: a current briefing, and one
  /// being written. Only these fold to their header row on a phone.
  bool get _calm =>
      state == RelationshipAgentCardState.current ||
      state == RelationshipAgentCardState.running;

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
        glyphColor: ai.metaText,
        tiers: [
          if (due != null)
            messages.relationshipAgentWatchingNextLook(
              relationshipDayLabelOf(context, due),
            ),
          messages.relationshipAgentWatching,
        ],
        color: ai.bodyText,
        metaColor: ai.metaText,
      ),
      // A first briefing has no age or band to show yet: the spinner and
      // what the agent is doing. An update keeps the current face's line —
      // the footer's Thinking… is the one busy signal.
      RelationshipAgentCardState.running when report == null => _StatusLine(
        leading: const DesignSystemSpinner(
          style: DesignSystemSpinnerStyle.plain,
          size: IconSizes.s,
        ),
        tiers: [messages.relationshipAgentWriting],
        color: ai.bodyText,
        liveRegion: true,
      ),
      // A past event in the same grammar as "as of": how long ago, not a
      // clock time that reads as an appointment.
      RelationshipAgentCardState.failed => _StatusLine(
        icon: LottiIcons.error,
        glyphColor: tokens.colors.alert.error.ink,
        tiers: [
          if (failedAt != null)
            messages.relationshipAgentLastRunFailed(
              relativeAgoLabel(messages, clock.now().difference(failedAt)),
            ),
          messages.relationshipAgentFailedPlain,
        ],
        color: ai.bodyText,
        metaColor: ai.metaText,
        liveRegion: true,
      ),
      // The band as a colour as well as a word — a dot in the glyph slot,
      // in the band's own accent, the one status the card said only in text.
      RelationshipAgentCardState.current ||
      RelationshipAgentCardState.running => _StatusLine(
        leading: switch (health?.band) {
          null => null,
          final band => SizedBox.square(
            dimension: IconSizes.s,
            child: Center(
              child: DesignSystemBadge.dot(
                key: const ValueKey('relationship-agent-band-dot'),
                tone: relationshipHealthBandTone(band),
                excludeFromSemantics: true,
              ),
            ),
          ),
        },
        tiers: [
          switch (health) {
            null => messages.goalDetailReadAsOf(_age(messages)),
            final health => messages.relationshipAgentAsOfBand(
              _age(messages),
              relationshipHealthBandLabel(context, health.band),
            ),
          },
        ],
        color: health == null ? ai.metaText : ai.bodyText,
        metaColor: ai.metaText,
        // Live only as it arrives: a briefing finishing or a failure
        // clearing is news; the age ticking afterwards is not.
        liveRegion: announceArrival,
      ),
      // One line beside the age pill: the date is the tier that goes, so
      // the status never orphans a date under itself next to a pill.
      RelationshipAgentCardState.outOfDate => _StatusLine(
        icon: LottiIcons.warning,
        glyphColor: tokens.colors.alert.warning.ink,
        tiers: [
          for (final tier in [
            if (latest != null) ...[
              messages.relationshipAgentOutOfDateNewCheckIn(
                relationshipDayLabelOf(context, latest.meta.dateFrom),
              ),
              messages.relationshipAgentOutOfDateNewCheckInShort,
            ],
            messages.taskAgentStatusOutOfDate,
          ])
            ?_withAge(tier, messages),
          messages.taskAgentStatusOutOfDate,
        ],
        color: ai.bodyText,
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

  /// [tier] with how old the briefing is, once it is a day old: the age
  /// rides the status line as its tail, rather than a pill beside it.
  String? _withAge(String tier, AppLocalizations messages) {
    final days = clock.now().difference(report!.createdAt).inDays;
    return days < 1
        ? tier
        : '$tier · ${messages.relationshipBriefingAge(days)}';
  }

  String _age(AppLocalizations messages) =>
      relativeAgoLabel(messages, clock.now().difference(report!.createdAt));

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final current = report;
    // What the expanded reading says about itself, above its Show less:
    // why the band says what it does, then what the briefing read. Only a
    // current briefing can say what it was written from — on an out-of-date
    // one the count already includes the check-in it missed — and only once
    // the reader opened it, unless there is nothing to open.
    final hasMore =
        resolveReportAdditional(current)?.trim().isNotEmpty ?? false;
    final readingCurrent = state == RelationshipAgentCardState.current;
    final rationale = readingCurrent && expanded ? health?.rationale : null;
    final showsSources = readingCurrent && (expanded || !hasMore);
    final trailing = rationale == null && !showsSources
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rationale != null)
                _BandRationale(text: rationale, color: ai.metaText),
              if (showsSources)
                Padding(
                  padding: EdgeInsets.only(
                    top: rationale == null
                        ? tokens.spacing.step4
                        : tokens.spacing.step1,
                  ),
                  child: Text(
                    messages.relationshipAgentSources(checkInCount),
                    key: const ValueKey('relationship-agent-meta'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: ai.metaText,
                    ),
                  ),
                ),
            ],
          );
    // The briefing as every reading face shows it, with the task card's
    // disclosure row: Read more, and the worded door to the agent's
    // internals beside it.
    TldrBody reading(AgentReportEntity report) => TldrBody(
      key: const ValueKey('relationship-briefing-body'),
      disclosureKey: const ValueKey('relationship-briefing-expand'),
      tldr: resolveReportTldr(report),
      expanded: expanded,
      additionalReport: resolveReportAdditional(report),
      onToggle: onToggleExpanded,
      onOpenInternals: onOpenInternals,
      trailing: trailing,
    );
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: ai.metaText,
    );
    final body = switch (state) {
      RelationshipAgentCardState.noBriefing => Text(
        messages.relationshipAgentNoBriefingBody(checkInCount),
        key: const ValueKey('relationship-agent-body'),
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: ai.bodyText,
        ),
      ),
      // An update keeps the briefing it will replace in view — the footer's
      // Thinking… says it is running, and the new briefing swaps in when it
      // lands. A first briefing has nothing to show yet, so the status line
      // stands alone.
      RelationshipAgentCardState.running => switch (current) {
        null => null,
        final report => reading(report),
      },
      // A failed run says what went wrong — and, like an update in
      // progress, keeps the briefing it failed to replace. The reader came
      // for what to bring up with this person; a provider error is a reason
      // to retry, not a reason to take that away. Beside a kept briefing
      // the error is a caption above it, with the briefing's age, because
      // the status line now dates the failure instead.
      RelationshipAgentCardState.failed => switch (current) {
        null => Text(
          modelMissing
              ? messages.relationshipAgentFailedNoModel
              : messages.relationshipAgentFailedBody,
          key: const ValueKey('relationship-agent-body'),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: ai.bodyText,
          ),
        ),
        final report => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              modelMissing
                  ? messages.relationshipAgentFailedNoModel
                  : messages.relationshipAgentFailedBody,
              key: const ValueKey('relationship-agent-body'),
              style: caption,
            ),
            SizedBox(height: tokens.spacing.step4),
            Text(
              messages.goalDetailReadAsOf(_age(messages)),
              key: const ValueKey('relationship-briefing-kept-age'),
              style: caption,
            ),
            SizedBox(height: tokens.spacing.step1),
            reading(report),
          ],
        ),
      },
      RelationshipAgentCardState.current ||
      RelationshipAgentCardState.outOfDate => reading(current!),
      // Unreachable by construction, see _status.
      // coverage:ignore-start
      RelationshipAgentCardState.notEnrolled => const SizedBox.shrink(),
      // coverage:ignore-end
    };

    // Whether the body closes on the briefing, whose disclosure row brings
    // its own trailing gap.
    final endsInBriefing = current != null && body is! Text;

    if (folded && _calm) {
      return AgentSummaryCardSurface(
        key: const ValueKey('relationship-briefing-card'),
        children: [
          DsQuietInk(
            key: const ValueKey('relationship-briefing-open'),
            onTap: onOpen,
            builder: (BuildContext context, bool highlighted) =>
                _BriefingHeader(
                  status: _status(context, messages),
                  trailing: Icon(
                    LottiIcons.expand,
                    size: IconSizes.s,
                    color: ai.metaText,
                  ),
                ),
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
      );
    }

    final identity = TaskAgentIdentityRegion(
      data: identityData,
      onSetupTap: onChooseModel,
      // This row is the disclosure a briefing starts on (ADR 0061): no width
      // or text size may shed the provider from it.
      alwaysNameProvider: true,
    );

    final largeText =
        MediaQuery.textScalerOf(context).scale(1) > TextScales.large;
    Widget updateStrip({required Widget? leading}) =>
        AgentAutomationRow.compact(
          key: const ValueKey('relationship-update-strip'),
          leading: leading,
          inferenceAvailable: !modelMissing,
          isRunning: state == RelationshipAgentCardState.running,
          hasReportContent: false,
          isStale: false,
          onRunNow: onBrief,
        );

    return AgentSummaryCardSurface(
      key: const ValueKey('relationship-briefing-card'),
      children: [
        _BriefingHeader(
          status: _status(context, messages),
          onTap: onOpenInternals,
        ),
        if (body != null)
          Padding(
            // No bottom inset under TldrBody: its disclosure row carries the
            // trailing gap inside its tap target. The plain-text bodies bring
            // one of their own.
            padding: EdgeInsets.only(
              left: tokens.spacing.cardPadding,
              right: tokens.spacing.cardPadding,
              bottom: endsInBriefing ? 0 : tokens.spacing.step4,
            ),
            child: body,
          ),
        // The task card's footer line on every face: *Update now* always in
        // the same place — *Thinking…* while a briefing is written, disabled
        // while no model is set up — and the model row where the task card
        // has its freshness word, since the status line already says how
        // current the briefing is. The row names the provider beside the
        // trigger that sends to it (ADR 0061), and opens the model setup.
        Padding(
          padding: EdgeInsets.only(
            left: tokens.spacing.cardPadding,
            right: tokens.spacing.cardPadding,
            bottom: tokens.spacing.step4,
          ),
          // The model row takes its own line over the trigger above the
          // large-text bar, and when it carries a second row naming the
          // report's own route: neither fits beside the trigger.
          child: largeText || identityData.showsReportRow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, updateStrip(leading: null)],
                )
              : updateStrip(leading: identity),
        ),
        // Proposals after the footer line, as on the task card: the line that
        // updates the briefing stays with the briefing.
        RelationshipSuggestionsBand(
          relationshipId: item.relationship.id,
          checkIns: checkIns,
          showHistory: expanded,
        ),
      ],
    );
  }
}
