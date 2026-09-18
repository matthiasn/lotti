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
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_quick_actions.dart';
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
  // Neutral: the accent means pressable on the same card.
  RelationshipHealthBand.steady => tokens.colors.text.mediumEmphasis,
  RelationshipHealthBand.needsAttention =>
    tokens.colors.alert.warning.defaultColor,
  RelationshipHealthBand.strained => tokens.colors.alert.error.defaultColor,
};

/// The band as the design system's presence dot: the same hues as
/// [relationshipHealthBandColor], through the badge's own tone ramp.
DesignSystemBadgeTone relationshipHealthBandTone(RelationshipHealthBand band) =>
    switch (band) {
      RelationshipHealthBand.thriving => DesignSystemBadgeTone.success,
      // Hueless: the accent means pressable on the same card.
      RelationshipHealthBand.steady => DesignSystemBadgeTone.neutral,
      RelationshipHealthBand.needsAttention => DesignSystemBadgeTone.warning,
      RelationshipHealthBand.strained => DesignSystemBadgeTone.danger,
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

  /// The face last rendered, so a change of face can be told from a rebuild
  /// of the same one.
  RelationshipAgentCardState? _shownState;

  /// Whether the current face has just arrived from a running or failed
  /// one — a briefing finishing, a failure clearing — and should be
  /// announced. Cleared when
  /// the age next ticks, so "as of 3 h ago" becoming "4 h ago" stays quiet.
  bool _arrivedCurrent = false;

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
      if (mounted) setState(() => _arrivedCurrent = false);
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
    final relationship = widget.relationship;
    final messages = context.messages;
    setState(() => _requesting = true);
    // No confirmation and no toast: the card's model row already names the
    // model and provider before anything is sent (ADR 0061), and the
    // running face's spinner is the acknowledgement.
    try {
      await ref
          .read(relationshipAgentServiceProvider)
          .requestBriefing(relationship);
    } catch (error, stackTrace) {
      // Only what fails before the wake is queued lands here — agent setup
      // and the enqueue itself; the workflow logs its own failures.
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
    if (cardState != _shownState) {
      // Only from a wake's own faces: the providers' first load passes
      // through noBriefing, and that is a card appearing, not news.
      _arrivedCurrent =
          cardState == RelationshipAgentCardState.current &&
          (_shownState == RelationshipAgentCardState.running ||
              _shownState == RelationshipAgentCardState.failed);
      _shownState = cardState;
    }

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
    // The status line ages from whichever timestamp it is showing: the
    // briefing's on the reading faces, the last wake's on the failed face —
    // armed from the other one, "just now" would outlive its minute.
    final aged = switch (cardState) {
      RelationshipAgentCardState.failed => state?.lastWakeAt,
      _ => report?.createdAt,
    };
    if (aged != null) {
      _armAgeTick(aged);
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
      announceArrival: _arrivedCurrent,
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

/// The plain card for a person without an agent (design 2026-09-13, option
/// 3f): the same skeleton as the agent's card — badge, title, one status
/// line, body, footer — in the section card's own tint rather than the AI
/// chrome, because nothing here is the agent's. The switch is the action;
/// the meta line says the one thing that matters about AI until then.
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
          _BriefingHeader(
            icon: LottiIcons.people,
            plain: true,
            status: _StatusLine(
              tiers: [
                if (paused)
                  relationshipStatusLabel(context, data.status)
                else
                  messages.relationshipAgentNoAgent,
              ],
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.cardPadding,
              0,
              tokens.spacing.cardPadding,
              tokens.spacing.step4,
            ),
            child: Text(
              paused
                  ? messages.relationshipAgentPausedBody
                  : messages.relationshipAgentNotEnrolledBody(
                      data.nickname ?? data.title,
                    ),
              key: const ValueKey('relationship-agent-body'),
              // Prose in the prose ink, like the six enrolled faces: only
              // the privacy caption beneath it is metadata.
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          // The privacy fact rides the action row's leading slot: one row,
          // not a footer and then a meta line under it.
          _AgentCardFooter(
            plain: true,
            leading: Text(
              messages.relationshipAgentOnlyYourStartsUseAi,
              key: const ValueKey('relationship-agent-meta'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            action: paused
                ? null
                : DesignSystemButton(
                    key: const ValueKey('relationship-agent-mark-important'),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    label: messages.relationshipAgentMarkImportant,
                    leadingIcon: LottiIcons.star,
                    isLoading: marking,
                    onPressed: marking ? null : onMarkImportant,
                  ),
          ),
        ],
      ),
    );
  }
}

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

  /// The header's status line: what the agent is doing, or when the
  /// briefing was written and the band it read, in that state's colour.
  _StatusLine _status(BuildContext context, AppLocalizations messages) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final lastWake = agentState?.lastWakeAt;
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
          if (lastWake != null)
            messages.relationshipAgentLastRunFailed(
              relativeAgoLabel(messages, clock.now().difference(lastWake)),
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
    final name =
        item.relationship.data.nickname ?? item.relationship.data.title;

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
          onOpenInternals: onOpenInternals,
        ),
      },
      RelationshipAgentCardState.failed => Text(
        modelMissing
            ? messages.relationshipAgentFailedNoModel
            : messages.relationshipAgentFailedBody,
        key: const ValueKey('relationship-agent-body'),
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: ai.bodyText,
        ),
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
        onOpenInternals: onOpenInternals,
      ),
      // Unreachable by construction, see _status.
      // coverage:ignore-start
      RelationshipAgentCardState.notEnrolled => const SizedBox.shrink(),
      // coverage:ignore-end
    };

    // The quiet text actions start the footer's row: their label sits on
    // the card's content column, not a button inset in from it.
    final logCheckIn = DesignSystemButton(
      key: const ValueKey('relationship-agent-log-check-in'),
      label: messages.relationshipLogCheckIn,
      variant: DesignSystemButtonVariant.tertiary,
      alignsLabelToLeadingEdge: true,
      tapTargetSize: MaterialTapTargetSize.padded,
      onPressed: onLogCheckIn,
    );
    final seeActivity = DesignSystemButton(
      key: const ValueKey('relationship-agent-see-activity'),
      label: messages.relationshipAgentSeeActivity,
      variant: DesignSystemButtonVariant.tertiary,
      alignsLabelToLeadingEdge: true,
      tapTargetSize: MaterialTapTargetSize.padded,
      onPressed: onOpenInternals,
    );
    final updateNow = DesignSystemButton(
      key: const ValueKey('relationship-brief-me'),
      tapTargetSize: MaterialTapTargetSize.padded,
      label: messages.taskAgentUpdateNow,
      leadingIcon: LottiIcons.refresh,
      variant: state == RelationshipAgentCardState.outOfDate
          ? DesignSystemButtonVariant.primary
          : DesignSystemButtonVariant.secondary,
      onPressed: onBrief,
    );
    final ({Widget? leading, Widget? action}) footer = switch (state) {
      // Every face has its quiet door: a check-in before the first
      // briefing, the activity log while one is being written.
      RelationshipAgentCardState.noBriefing => (
        leading: logCheckIn,
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
      RelationshipAgentCardState.current when overdue => (
        leading: logCheckIn,
        action: onCall == null
            ? DesignSystemButton(
                key: const ValueKey('relationship-agent-log-check-in-primary'),
                tapTargetSize: MaterialTapTargetSize.padded,
                label: messages.relationshipLogCheckIn,
                leadingIcon: LottiIcons.greeting,
                onPressed: onLogCheckIn,
              )
            : DesignSystemButton(
                key: const ValueKey('relationship-agent-call'),
                tapTargetSize: MaterialTapTargetSize.padded,
                label: messages.relationshipAgentCall(name),
                leadingIcon: contactActionIcon(reachable!.action),
                onPressed: onCall,
              ),
      ),
      RelationshipAgentCardState.current ||
      RelationshipAgentCardState.outOfDate => (
        leading: logCheckIn,
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
        if (body != null)
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

/// The card's header: the badge, *Briefing*, the status line, and the
/// optional pill on the trailing rail. The shared [TldrHeader] underneath,
/// so the badge tier and the tap-to-internals target stay the agent
/// cards' own.
class _BriefingHeader extends StatelessWidget {
  const _BriefingHeader({
    required this.status,
    this.trailing,
    this.onTap,
    this.icon,
    this.plain = false,
  });

  final _StatusLine status;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData? icon;

  /// The unenrolled card: no internals to open, and the neutral badge.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return TldrHeader(
      title: messages.relationshipBriefingTitle,
      agentName: null,
      subtitle: status,
      plain: plain,
      trailing: trailing,
      icon: icon,
      onAgentTap: plain ? null : onTap,
    );
  }
}

/// One line under the title: an optional glyph or spinner, a label, a tone.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.tiers,
    required this.color,
    this.icon,
    this.leading,
    this.leadingSize = IconSizes.s,
    this.metaColor,
    this.liveRegion = false,
  });

  /// The ink for the detail after the state word (`· 20 min ago`): the
  /// alert colour is the state's alone, and the age is metadata.
  final Color? metaColor;

  /// Whether a change here is news a reader must hear — the card going
  /// running → current or → failed — rather than an age ticking over.
  final bool liveRegion;

  /// The state's wordings, widest first: the line sheds a date or a time
  /// before it wraps, and a phone beside a pill is narrow.
  final List<String> tiers;
  final Color color;
  final IconData? icon;

  /// A widget in the glyph slot — the running state's spinner, the band's
  /// dot.
  final Widget? leading;

  /// The glyph's height, so it can be centred on the first line of text at
  /// any text scale rather than pinned a fixed step from the top.
  final double leadingSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final style = tokens.typography.styles.body.bodySmall.copyWith(
      color: color,
    );
    final glyphSize = icon == null ? leadingSize : IconSizes.s;
    final glyph =
        leading ??
        (icon == null ? null : Icon(icon, size: IconSizes.s, color: color));
    // Centred on the first line: the line as the text engine lays it out at
    // the reader's scale, less the glyph, halved — so at 1.6× the dot still
    // sits on the words rather than above them.
    final line = MediaQuery.textScalerOf(
      context,
    ).scale(style.fontSize! * (style.height ?? 1));
    final glyphTop = ((line - glyphSize) / 2).clamp(0.0, double.infinity);
    // A live region for the transitions only: running → current, or →
    // failed, is the card's one sentence changing, and a reader who cannot
    // see the colour hears it — the state word, not the age behind it.
    return Semantics(
      liveRegion: liveRegion,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // Top-aligned, so a status that wraps keeps its glyph on the first
        // line rather than floating between the two.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (glyph != null) ...[
            Padding(
              padding: EdgeInsets.only(top: glyphTop),
              child: glyph,
            ),
            SizedBox(width: tokens.spacing.step2),
          ],
          Flexible(
            child: DsTieredText(
              textKey: const ValueKey('relationship-agent-status'),
              tiers: tiers,
              // The narrowest wording may still wrap once: this line is the
              // state's non-colour carrier and must not clip.
              maxLines: 2,
              semanticsLabel: liveRegion ? tiers.last : null,
              style: style,
              tailStyle: metaColor == null
                  ? null
                  : style.copyWith(color: metaColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet caption row under the footer's actions: the sources line on a
/// briefing, the AI note on the plain card.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tokens.spacing.step6),
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                key: const ValueKey('relationship-agent-meta'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's quiet controls band — the task card's footer grammar: one
/// text action on the leading edge, the one primary on the trailing rail,
/// the model identity row and the sources line below. Its wash and top
/// hairline are the container; nothing inside draws a second fill.
class _AgentCardFooter extends StatelessWidget {
  const _AgentCardFooter({
    required this.action,
    this.leading,
    this.identity,
    this.meta,
    this.plain = false,
  });

  /// The secondary, text-only action on the leading edge.
  final Widget? leading;
  final Widget? action;
  final Widget? identity;
  final Widget? meta;

  /// The unenrolled card is not an AI surface: its band is the section
  /// card's own tint rather than the AI footer wash.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > TextScales.large;
    final ai = tokens.colors.aiCard;

    // The plain band is a faint neutral wash over the card surface — the
    // tint alpha the tone-tinted fills use, in ink rather than an accent —
    // so it reads as the footer of a quiet card, not as a raised block.
    final plainWash = Color.alphaBlend(
      tokens.colors.text.highEmphasis.withValues(alpha: SurfaceAlphas.tint),
      tokens.colors.background.level02,
    );
    return Container(
      key: const ValueKey('relationship-agent-footer'),
      // Full width regardless of what sits inside: a footer with only the
      // model row (the running face) must still wash the whole card.
      width: double.infinity,
      decoration: BoxDecoration(
        color: plain ? plainWash : ai.footerWash,
        border: Border(
          top: BorderSide(
            color: plain ? tokens.colors.decorative.level01 : ai.borderSoft,
          ),
        ),
      ),
      // A step more above than below when meta rows close the card; with
      // nothing under the action row the inset is symmetric.
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.cardPadding,
        tokens.spacing.step4,
        tokens.spacing.cardPadding,
        identity == null && meta == null
            ? tokens.spacing.step4
            : tokens.spacing.step3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Above the large-text bar the leading slot — a quiet action, or
          // the not-enrolled face's privacy note — takes its own full-width
          // line above the primary, so neither is squeezed by the other.
          if (stacked && leading != null && action != null) ...[
            leading!,
            SizedBox(height: tokens.spacing.step3),
            // The same row height as the side-by-side branch, so the
            // stacked footer keeps its rhythm below the primary too.
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TapTargets.minimum,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: action,
              ),
            ),
          ] else if (leading != null || action != null)
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TapTargets.minimum,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: leading ?? const SizedBox.shrink(),
                    ),
                  ),
                  if (action != null) ...[
                    SizedBox(width: tokens.spacing.step3),
                    action!,
                  ],
                ],
              ),
            ),
          // A designed gap under the action row: the 48pt floor gives no
          // slack once a large-text pill outgrows it.
          if ((leading != null || action != null) &&
              (identity != null || meta != null))
            SizedBox(height: tokens.spacing.step3),
          ?identity,
          ?meta,
        ],
      ),
    );
  }
}
