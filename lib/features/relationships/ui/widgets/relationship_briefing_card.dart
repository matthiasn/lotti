import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
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
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_quick_actions.dart';
import 'package:lotti/features/relationships/ui/widgets/person_header.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_suggestions_band.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:material_ui/material_ui.dart';

/// The localized label of a health band — shared by the chip and any
/// future list surface.
String relationshipHealthBandLabel(
  BuildContext context,
  RelationshipHealthBand band,
) => switch (band) {
  RelationshipHealthBand.thriving =>
    context.messages.relationshipHealthThriving,
  RelationshipHealthBand.steady => context.messages.relationshipHealthSteady,
  RelationshipHealthBand.needsAttention =>
    context.messages.relationshipHealthNeedsAttention,
  RelationshipHealthBand.strained =>
    context.messages.relationshipHealthStrained,
};

/// The accent a health band wears wherever it is shown as a tinted pill —
/// the briefing card's chip and the person header's band pill alike. The
/// band accent as text on its own tint is a contrast failure, so callers
/// paint the label in high-emphasis ink and let the colour ride the tint.
Color relationshipHealthBandColor(
  DsTokens tokens,
  RelationshipHealthBand band,
) => switch (band) {
  RelationshipHealthBand.thriving => tokens.colors.alert.success.defaultColor,
  RelationshipHealthBand.steady => tokens.colors.aiCard.accent,
  RelationshipHealthBand.needsAttention =>
    tokens.colors.alert.warning.defaultColor,
  RelationshipHealthBand.strained => tokens.colors.alert.error.defaultColor,
};

/// The agent's standing briefing, if [report] is one: the `current`-scope
/// report entity that has not been deleted. Anything else — no report yet,
/// a historical scope, a tombstone — is `null`, and the surfaces that read
/// the briefing (the card, the header's band pill) treat that as "no
/// briefing" together rather than each deciding differently.
AgentReportEntity? currentRelationshipReport(Object? report) =>
    report is AgentReportEntity &&
        report.scope == AgentReportScopes.current &&
        report.deletedAt == null
    ? report
    : null;

/// What the relationship agent card shows (design 2026-09-06 §4): one of
/// seven faces, decided once per build from the runtime's own signals.
enum RelationshipAgentCardState {
  /// Not important, or dormant/archived: no agent watches this person.
  notEnrolled,

  /// Enrolled, the agent has never written a briefing.
  noBriefing,

  /// A wake is running right now.
  running,

  /// The last wake failed and nothing newer succeeded.
  failed,

  /// The briefing is fresh.
  current,

  /// Evidence arrived after the briefing was written.
  outOfDate,
}

/// The card's state from the runtime's signals. Pure, so the decision is
/// testable as a table: running beats everything but enrolment, a failure
/// counts only while it is newer than the briefing, and staleness needs a
/// briefing to be stale.
RelationshipAgentCardState relationshipAgentCardStateOf({
  required bool enrolled,
  required bool isRunning,
  required AgentReportEntity? report,
  required AgentStateEntity? state,
}) {
  if (!enrolled) return RelationshipAgentCardState.notEnrolled;
  if (isRunning) return RelationshipAgentCardState.running;
  final failures = state?.consecutiveFailureCount ?? 0;
  final lastWake = state?.lastWakeAt;
  final failedSinceReport =
      failures > 0 &&
      (report == null ||
          (lastWake != null && lastWake.isAfter(report.createdAt)));
  if (failedSinceReport) return RelationshipAgentCardState.failed;
  if (report == null) return RelationshipAgentCardState.noBriefing;
  if (state?.isReportStale ?? false) {
    return RelationshipAgentCardState.outOfDate;
  }
  return RelationshipAgentCardState.current;
}

/// The relationship agent's card on the person's page (plan v2 phase 5,
/// design 2026-09-06 §4): the same AI panel as the task agent's section and
/// the goal agent's read — [aiCardDecoration] chrome, [TldrHeader] identity
/// (tapping it opens the agent internals), [TldrBody] for the briefing prose
/// — with the cadence fact and the health band as pills, and a footer that
/// says what the agent is doing and offers the one thing to do about it:
/// *Brief now* before the first briefing, *Update now* when it is current or
/// out of date, *Choose a model* or *Try again* after a failure, and *Log
/// check-in* · *Call* while the cadence is lapsed. An unenrolled person gets
/// a plain card explaining what *important* turns on, with the switch as
/// the action.
///
/// The chat entry lives in the page's hero, not here. Automatic updates are
/// not offered as a switch because the relationship runtime does not read
/// that flag; the model row opens the same setup sheet as on a task.
class RelationshipBriefingCard extends ConsumerStatefulWidget {
  const RelationshipBriefingCard({
    required this.relationship,
    required this.checkIns,
    super.key,
  });

  final RelationshipEntry relationship;

  /// Newest first. The latest one drives the cadence pill and names the day
  /// of the "new check-in" that made a briefing out of date; the count feeds
  /// the empty and running states.
  final List<CheckInEntry> checkIns;

  @override
  ConsumerState<RelationshipBriefingCard> createState() =>
      _RelationshipBriefingCardState();
}

class _RelationshipBriefingCardState
    extends ConsumerState<RelationshipBriefingCard> {
  bool _expanded = false;
  bool _requesting = false;
  bool _marking = false;

  /// The channel the due state's *Call* offers, resolved like the action
  /// bar's; null until asked and when nothing is launchable.
  ReachableChannel? _reachable;
  int _resolution = 0;

  /// Re-renders the "as of" meta when its displayed bucket next changes:
  /// computed only at build, a briefing rendered "just now" would keep that
  /// label for hours. One wake per visible change, not a per-second tick.
  Timer? _ageTick;

  String get _agentId => relationshipAgentIdFor(widget.relationship.meta.id);

  @override
  void initState() {
    super.initState();
    unawaited(_resolveReachable());
  }

  @override
  void dispose() {
    _ageTick?.cancel();
    super.dispose();
  }

  void _armAgeTick(DateTime writtenAt) {
    _ageTick?.cancel();
    _ageTick = Timer(untilNextAgeBucket(clock.now().difference(writtenAt)), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(RelationshipBriefingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
      oldWidget.relationship.data.contactChannels,
      widget.relationship.data.contactChannels,
    )) {
      unawaited(_resolveReachable());
    }
  }

  Future<void> _resolveReachable() async {
    final generation = ++_resolution;
    final found = await firstReachableChannel(
      ref.read(contactLauncherProvider),
      widget.relationship.data.contactChannels,
    );
    if (!mounted || generation != _resolution) return;
    setState(() => _reachable = found);
  }

  void _openInternals(String? agentName) {
    Navigator.of(context).push(
      AgentInternalsPanel.route(
        context: context,
        agentId: _agentId,
        agentName: agentName,
      ),
    );
  }

  /// Asks for a briefing: the first one, an update, or a retry after a
  /// failure — one path, one trigger token.
  Future<void> _briefMe() async {
    if (_requesting) return;
    final messages = context.messages;
    setState(() => _requesting = true);
    try {
      // Name the provider BEFORE any cloud-bound trigger (ADR 0037): the
      // locality check fails closed, so an unresolvable profile discloses.
      final providerName = await ref.refresh(
        relationshipBriefingDisclosureProvider(
          widget.relationship.meta.id,
        ).future,
      );
      if (!mounted) return;
      if (providerName != null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              messages.relationshipBriefingDisclosureTitle(providerName),
            ),
            content: Text(
              messages.relationshipBriefingDisclosureBody(providerName),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(messages.cancelButton),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  messages.relationshipBriefingDisclosureConfirm,
                ),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      await ref
          .read(relationshipAgentServiceProvider)
          .requestBriefing(widget.relationship);
      if (!mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: messages.relationshipBriefingRequested,
      );
    } on RelationshipInferenceSetupUnavailable {
      if (!mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: messages.taskAgentSetupBroken,
        description: messages.relationshipAgentFailedNoModel,
        action: ToastAction(
          label: messages.inferenceProfileChooseModelTitle,
          onPressed: () =>
              AgentModelSheet.show(context: context, agentId: _agentId),
        ),
      );
    } catch (error, stackTrace) {
      // Only what fails before the wake is queued lands here — disclosure,
      // agent setup, the enqueue itself; the workflow logs its own failures.
      developer.log(
        'Failed to request a relationship briefing',
        name: 'RelationshipBriefingCard',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: messages.relationshipBriefingRequestFailed,
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  /// The consent switch, from the card: marking the person important is
  /// what creates their agent (ADR 0059 Decision 2), so the save is followed
  /// by the same lazy-create call the edit form makes — fire-and-forget with
  /// contained failure, because agent wiring must never fail the save the
  /// user just watched succeed. Both services are read before the await:
  /// the agent is minted after this widget may be gone.
  Future<void> _markImportant() async {
    if (_marking) return;
    final messages = context.messages;
    final repository = ref.read(relationshipRepositoryProvider);
    final agentService = ref.read(relationshipAgentServiceProvider);
    setState(() => _marking = true);
    try {
      final relationship = widget.relationship;
      final enrolled = relationship.copyWith(
        data: relationship.data.copyWith(important: true),
      );
      final saved = await repository.updateRelationship(enrolled);
      if (saved) {
        unawaited(() async {
          try {
            await agentService.ensureAgentForRelationship(enrolled);
          } catch (error, stackTrace) {
            developer.log(
              'Failed to ensure relationship agent',
              name: 'RelationshipBriefingCard',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }());
      } else if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: messages.relationshipErrorUpdateFailed,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to mark the person important',
        name: 'RelationshipBriefingCard',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: messages.relationshipErrorUpdateFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _logCheckIn() => showCheckInCaptureSheet(
    context: context,
    relationshipId: widget.relationship.meta.id,
  );

  Future<void> _call(ReachableChannel reachable) => launchContactAction(
    context,
    ref,
    relationshipId: widget.relationship.meta.id,
    channel: reachable.channel,
    action: reachable.action,
  );

  @override
  Widget build(BuildContext context) {
    final relationship = widget.relationship;
    final data = relationship.data;
    final item = (
      relationship: relationship,
      lastCheckIn: widget.checkIns.firstOrNull,
    );
    final enrolled = isEnrolled(relationship);
    final agentId = _agentId;

    final report = currentRelationshipReport(
      ref.watch(agentReportProvider(agentId)).value,
    );
    final state = ref
        .watch(agentStateProvider(agentId))
        .value
        ?.mapOrNull(agentState: (value) => value);
    final isRunning = ref.watch(agentIsRunningProvider(agentId)).value ?? false;
    final cardState = relationshipAgentCardStateOf(
      enrolled: enrolled,
      isRunning: isRunning,
      report: report,
      state: state,
    );

    if (cardState == RelationshipAgentCardState.notEnrolled) {
      return _NotEnrolledCard(
        item: item,
        marking: _marking,
        onMarkImportant: data.important ? null : _markImportant,
      );
    }

    final health = report == null
        ? null
        : relationshipHealthMetricsFromReport(report);
    if (report != null) {
      _armAgeTick(report.createdAt);
    } else {
      _ageTick?.cancel();
    }
    final setup = ref.watch(taskAgentResolvedSetupProvider(agentId)).value;
    final provenance = report == null
        ? null
        : ReportInferenceProvenance.tryRead(report.provenance);
    final identityData = TaskAgentModelIdentityViewData.fromResolution(
      setup: setup,
      reportProvenance: provenance,
      hasReport: report != null,
    );
    final modelMissing =
        identityData.presentation == TaskAgentIdentityPresentation.disabled ||
        identityData.presentation == TaskAgentIdentityPresentation.broken;
    final usage = ref.watch(agentTokenUsageSummariesProvider(agentId)).value;
    final totalTokens =
        usage?.fold<int>(0, (sum, summary) => sum + summary.totalTokens) ?? 0;
    final identity = ref.watch(agentIdentityProvider(agentId)).value;
    // The relationship agent is NAMED after the person it watches, and this
    // card sits under a hero already carrying that name — so the internals
    // panel gets the name, and the header's subtitle line says what the
    // agent is doing instead.
    final agentName = identity is AgentIdentityEntity
        ? identity.displayName.trim()
        : null;
    final overdue =
        peopleCadencePillOf(item).kind == PeopleCadencePillKind.overdue;

    return _AgentCard(
      state: cardState,
      item: item,
      checkInCount: widget.checkIns.length,
      checkIns: widget.checkIns,
      report: report,
      agentState: state,
      health: health,
      totalTokens: totalTokens,
      identityData: identityData,
      modelMissing: modelMissing,
      overdue: overdue,
      reachable: _reachable,
      expanded: _expanded,
      requesting: _requesting,
      onToggleExpanded: () => setState(() => _expanded = !_expanded),
      onOpenInternals: () => _openInternals(agentName),
      onBrief: _requesting ? null : _briefMe,
      onChooseModel: () => AgentModelSheet.show(
        context: context,
        entityId: relationship.meta.id,
        agentId: agentId,
      ),
      onLogCheckIn: _logCheckIn,
      onCall: switch (_reachable) {
        null => null,
        final reachable => () => _call(reachable),
      },
    );
  }
}

/// The plain card for a person without an agent: what *important* turns
/// on, and the switch as the action. No AI chrome — nothing here is the
/// agent's.
class _NotEnrolledCard extends StatelessWidget {
  const _NotEnrolledCard({
    required this.item,
    required this.marking,
    required this.onMarkImportant,
  });

  final RelationshipListItem item;
  final bool marking;

  /// Null while the person is important but dormant or archived: the
  /// switch is already on, and the card says why nothing happens instead.
  final VoidCallback? onMarkImportant;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final data = item.relationship.data;
    final paused = onMarkImportant == null;

    return DesignSystemSectionCard(
      key: const ValueKey('relationship-briefing-card'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.cardPadding,
              tokens.spacing.step4,
              tokens.spacing.cardPadding,
              0,
            ),
            child: Row(
              children: [
                Container(
                  width: tokens.spacing.step8,
                  height: tokens.spacing.step8,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.colors.background.level03,
                    borderRadius: BorderRadius.circular(tokens.radii.m),
                  ),
                  child: Icon(
                    LottiIcons.people,
                    size: tokens.spacing.step6,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        messages.relationshipBriefingTitle,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(color: tokens.colors.text.highEmphasis),
                      ),
                      Text(
                        messages.relationshipAgentNoAgent,
                        key: const ValueKey('relationship-agent-subtitle'),
                        style: relationshipTimestampStyle(
                          tokens,
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.cardPadding,
              tokens.spacing.step3,
              tokens.spacing.cardPadding,
              tokens.spacing.step4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                relationshipCadencePill(
                  context,
                  item,
                  keyPrefix: 'relationship-agent-pill',
                ),
                SizedBox(height: tokens.spacing.step3),
                Text(
                  paused
                      ? messages.relationshipAgentPausedBody
                      : messages.relationshipAgentNotEnrolledBody(
                          data.nickname ?? data.title,
                        ),
                  key: const ValueKey('relationship-agent-body'),
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
            ),
          ),
          _AgentCardFooter(
            status: _StatusLine(
              icon: LottiIcons.info,
              label: paused
                  ? relationshipStatusLabel(context, data.status)
                  : messages.relationshipNotEnrolled,
              color: tokens.colors.text.mediumEmphasis,
            ),
            action: paused
                ? null
                : DesignSystemButton(
                    key: const ValueKey('relationship-agent-mark-important'),
                    label: messages.relationshipAgentMarkImportant,
                    isLoading: marking,
                    onPressed: marking ? null : onMarkImportant,
                  ),
            plain: true,
          ),
        ],
      ),
    );
  }
}

/// The AI card for an enrolled person, in one of its five agent-owned
/// states.
class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.state,
    required this.item,
    required this.checkInCount,
    required this.checkIns,
    required this.report,
    required this.agentState,
    required this.health,
    required this.totalTokens,
    required this.identityData,
    required this.modelMissing,
    required this.overdue,
    required this.reachable,
    required this.expanded,
    required this.requesting,
    required this.onToggleExpanded,
    required this.onOpenInternals,
    required this.onBrief,
    required this.onChooseModel,
    required this.onLogCheckIn,
    required this.onCall,
  });

  final RelationshipAgentCardState state;
  final RelationshipListItem item;
  final int checkInCount;
  final List<CheckInEntry> checkIns;
  final AgentReportEntity? report;
  final AgentStateEntity? agentState;
  final RelationshipHealthMetrics? health;
  final int totalTokens;
  final TaskAgentModelIdentityViewData identityData;
  final bool modelMissing;
  final bool overdue;
  final ReachableChannel? reachable;
  final bool expanded;
  final bool requesting;
  final VoidCallback onToggleExpanded;
  final VoidCallback onOpenInternals;
  final VoidCallback? onBrief;
  final VoidCallback onChooseModel;
  final VoidCallback onLogCheckIn;
  final VoidCallback? onCall;

  /// The header's meta line: what the agent is doing, or when the briefing
  /// was written and what it has cost so far.
  String _subtitle(BuildContext context, AppLocalizations messages) {
    final lastWake = agentState?.lastWakeAt;
    return switch (state) {
      RelationshipAgentCardState.noBriefing =>
        messages.relationshipAgentWatching,
      RelationshipAgentCardState.running => messages.relationshipAgentWriting,
      RelationshipAgentCardState.failed =>
        lastWake == null
            ? messages.relationshipAgentFailedBody
            : messages.relationshipAgentLastRunFailed(
                relationshipTimeLabel(lastWake),
              ),
      RelationshipAgentCardState.current ||
      RelationshipAgentCardState.outOfDate => [
        messages.goalDetailReadAsOf(
          relativeAgoLabel(
            messages,
            clock.now().difference(report!.createdAt),
          ),
        ),
        if (totalTokens > 0)
          messages.agentConversationTokenCount(
            NumberFormat.compact(
              locale: Localizations.localeOf(context).toString(),
            ).format(totalTokens),
          ),
      ].join(' · '),
      // Unreachable by construction: the card returns the plain

      // _NotEnrolledCard before this widget is ever built.
      RelationshipAgentCardState.notEnrolled => '', // coverage:ignore-line
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final current = report;
    final name =
        item.relationship.data.nickname ?? item.relationship.data.title;

    final pills = <Widget>[
      relationshipCadencePill(
        context,
        item,
        keyPrefix: 'relationship-agent-pill',
      ),
      if (health case final health?)
        Tooltip(
          message: health.rationale,
          child: DsPill(
            key: const ValueKey('relationship-health-chip'),
            variant: DsPillVariant.tinted,
            shape: DsPillShape.tag,
            color: relationshipHealthBandColor(tokens, health.band),
            // The band accent as text on its own tint is a contrast
            // failure; the colour identity rides the tint, as it does on
            // the task status tag.
            labelColor: tokens.colors.text.highEmphasis,
            label: relationshipHealthBandLabel(context, health.band),
          ),
        ),
    ];

    final body = switch (state) {
      RelationshipAgentCardState.noBriefing => Text(
        messages.relationshipAgentNoBriefingBody(checkInCount),
        key: const ValueKey('relationship-agent-body'),
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: ai.metaText,
        ),
      ),
      RelationshipAgentCardState.running => Text(
        messages.relationshipAgentReading(checkInCount),
        key: const ValueKey('relationship-agent-body'),
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: ai.accent,
        ),
      ),
      RelationshipAgentCardState.failed => Text(
        modelMissing
            ? messages.relationshipAgentFailedNoModel
            : messages.relationshipAgentFailedBody,
        key: const ValueKey('relationship-agent-body'),
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
      RelationshipAgentCardState.current ||
      RelationshipAgentCardState.outOfDate => TldrBody(
        key: const ValueKey('relationship-briefing-body'),
        disclosureKey: const ValueKey('relationship-briefing-expand'),
        tldr: resolveReportTldr(current),
        expanded: expanded,
        additionalReport: resolveReportAdditional(current),
        onToggle: onToggleExpanded,
        onOpenInternals: onOpenInternals,
      ),
      // Unreachable by construction, see _subtitle.
      // coverage:ignore-start
      RelationshipAgentCardState.notEnrolled => const SizedBox.shrink(),
      // coverage:ignore-end
    };

    final due = peopleDueDateOf(item);
    final latest = item.lastCheckIn;
    final lastWake = agentState?.lastWakeAt;
    final ({_StatusLine? status, Widget? leading, Widget? action}) footer =
        switch (state) {
          RelationshipAgentCardState.noBriefing => (
            leading: null,
            status: due == null
                ? null
                : _StatusLine(
                    icon: LottiIcons.timer,
                    label: messages.relationshipAgentNextLook(
                      relationshipDayLabelOf(context, due),
                    ),
                    color: ai.metaText,
                  ),
            action: DesignSystemButton(
              key: const ValueKey('relationship-brief-me'),
              label: messages.relationshipAgentBriefNow,
              onPressed: onBrief,
            ),
          ),
          RelationshipAgentCardState.running => (
            leading: null,
            status: _StatusLine(
              icon: LottiIcons.refresh,
              label: lastWake == null
                  ? messages.relationshipAgentRunning
                  : messages.relationshipAgentRunningSince(
                      relationshipTimeLabel(lastWake),
                    ),
              color: ai.accent,
            ),
            action: null,
          ),
          RelationshipAgentCardState.failed => (
            leading: null,
            status: _StatusLine(
              icon: LottiIcons.error,
              label: lastWake == null
                  ? messages.relationshipAgentFailedPlain
                  : messages.relationshipAgentFailed(
                      relationshipTimeLabel(lastWake),
                    ),
              color: tokens.colors.alert.error.defaultColor,
            ),
            action: modelMissing
                ? DesignSystemButton(
                    key: const ValueKey('relationship-agent-choose-model'),
                    label: messages.inferenceProfileChooseModelTitle,
                    onPressed: onChooseModel,
                  )
                : DesignSystemButton(
                    key: const ValueKey('relationship-brief-me'),
                    label: messages.relationshipAgentTryAgain,
                    onPressed: onBrief,
                  ),
          ),
          RelationshipAgentCardState.current when overdue => (
            status: null,
            leading: DesignSystemButton(
              key: const ValueKey('relationship-agent-log-check-in'),
              label: messages.relationshipLogCheckIn,
              leadingIcon: LottiIcons.greeting,
              variant: DesignSystemButtonVariant.tertiary,
              onPressed: onLogCheckIn,
            ),
            action: onCall == null
                ? DesignSystemButton(
                    key: const ValueKey(
                      'relationship-agent-log-check-in-primary',
                    ),
                    label: messages.relationshipLogCheckIn,
                    onPressed: onLogCheckIn,
                  )
                : DesignSystemButton(
                    key: const ValueKey('relationship-agent-call'),
                    label: messages.relationshipAgentCall(name),
                    leadingIcon: contactActionIcon(reachable!.action),
                    onPressed: onCall,
                  ),
          ),
          RelationshipAgentCardState.current => (
            leading: null,
            status: _StatusLine(
              icon: LottiIcons.confirm,
              label: messages.taskAgentStatusUpToDate,
              color: ai.metaText,
            ),
            action: DesignSystemButton(
              key: const ValueKey('relationship-brief-me'),
              label: messages.taskAgentUpdateNow,
              variant: DesignSystemButtonVariant.secondary,
              onPressed: onBrief,
            ),
          ),
          RelationshipAgentCardState.outOfDate => (
            leading: null,
            status: _StatusLine(
              icon: LottiIcons.warning,
              label: latest == null
                  ? messages.taskAgentStatusOutOfDate
                  : messages.relationshipAgentOutOfDateNewCheckIn(
                      relationshipDayLabelOf(context, latest.meta.dateFrom),
                    ),
              color: tokens.colors.alert.warning.defaultColor,
            ),
            action: DesignSystemButton(
              key: const ValueKey('relationship-brief-me'),
              label: messages.taskAgentUpdateNow,
              onPressed: onBrief,
            ),
          ),
          // Unreachable by construction, see _subtitle.
          // coverage:ignore-start
          RelationshipAgentCardState.notEnrolled => (
            status: null,
            leading: null,
            action: null,
          ),
          // coverage:ignore-end
        };

    return AgentSummaryCardSurface(
      key: const ValueKey('relationship-briefing-card'),
      children: [
        TldrHeader(
          title: messages.relationshipBriefingTitle,
          agentName: _subtitle(context, messages),
          onAgentTap: onOpenInternals,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.cardPadding,
            0,
            tokens.spacing.cardPadding,
            tokens.spacing.step3,
          ),
          child: Wrap(
            spacing: tokens.spacing.step2,
            runSpacing: tokens.spacing.step2,
            children: pills,
          ),
        ),
        Padding(
          // No bottom inset under TldrBody: its disclosure row carries the
          // trailing gap inside its tap target. The plain-text bodies bring
          // one of their own.
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.cardPadding,
            0,
            tokens.spacing.cardPadding,
            body is TldrBody ? 0 : tokens.spacing.step4,
          ),
          child: body,
        ),
        RelationshipSuggestionsBand(
          relationshipId: item.relationship.id,
          checkIns: checkIns,
          showHistory: expanded,
        ),
        _AgentCardFooter(
          status: footer.status,
          leading: footer.leading,
          action: footer.action,
          identity: TaskAgentIdentityRegion(
            data: identityData,
            onSetupTap: onChooseModel,
          ),
        ),
      ],
    );
  }
}

/// One line of the footer: an icon, a label, a tone.
class _StatusLine {
  const _StatusLine({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}

/// The card's quiet controls band — the task card's footer grammar: the
/// status on the leading edge, the one action on the trailing rail, the
/// model identity row below. Its wash and top hairline are the container;
/// nothing inside draws a second fill.
class _AgentCardFooter extends StatelessWidget {
  const _AgentCardFooter({
    required this.status,
    required this.action,
    this.leading,
    this.identity,
    this.plain = false,
  });

  final _StatusLine? status;

  /// A control on the leading edge instead of a status — the due state's
  /// quiet *Log check-in* beside its primary *Call*.
  final Widget? leading;
  final Widget? action;
  final Widget? identity;

  /// The unenrolled card is not an AI surface: its band is the section
  /// card's own tint rather than the AI footer wash.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final status = this.status;

    Widget statusWidget(_StatusLine line) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(line.icon, size: IconSizes.s, color: line.color),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            line.label,
            key: const ValueKey('relationship-agent-status'),
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: line.color,
            ),
          ),
        ),
      ],
    );

    // The plain band is a faint neutral wash over the card surface — the
    // tint alpha the tone-tinted fills use, in ink rather than an accent —
    // so it reads as the footer of a quiet card, not as a raised block.
    final plainWash = Color.alphaBlend(
      tokens.colors.text.highEmphasis.withValues(alpha: SurfaceAlphas.tint),
      tokens.colors.background.level02,
    );
    return Container(
      key: const ValueKey('relationship-agent-footer'),
      decoration: BoxDecoration(
        color: plain ? plainWash : ai.footerWash,
        border: Border(
          top: BorderSide(
            color: plain ? tokens.colors.decorative.level01 : ai.borderSoft,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.cardPadding,
        vertical: tokens.spacing.step2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status != null || leading != null || action != null)
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing.step8),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: status == null
                          ? (leading ?? const SizedBox.shrink())
                          : statusWidget(status),
                    ),
                  ),
                  if (action != null) ...[
                    SizedBox(width: tokens.spacing.step3),
                    action!,
                  ],
                ],
              ),
            ),
          ?identity,
        ],
      ),
    );
  }
}
