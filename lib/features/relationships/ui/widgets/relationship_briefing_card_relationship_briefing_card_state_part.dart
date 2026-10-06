part of 'relationship_briefing_card.dart';

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
/// counts only while it is the last outcome and newer than the briefing,
/// and staleness needs a briefing to be stale.
///
/// The failure is read from the state row's two outcome watermarks
/// (`lastWakeFailed`: the last failed wake ended after the last completed
/// one), which every device merges by latest instant, never from the
/// failure count, which is last-writer-wins with the row and showed one
/// device's stale count beside another's good briefing (ADR 0115). A
/// failure older than the briefing is history: a success whose state write
/// was lost still wrote its briefing.
RelationshipAgentCardState relationshipAgentCardStateOf({
  required bool enrolled,
  required bool isRunning,
  required AgentReportEntity? report,
  required AgentStateEntity? state,
}) {
  if (!enrolled) return RelationshipAgentCardState.notEnrolled;
  if (isRunning) return RelationshipAgentCardState.running;
  final failedAt = state?.lastWakeFailedAt;
  final failedSinceReport =
      failedAt != null &&
      (state?.lastWakeFailed ?? false) &&
      (report == null || failedAt.isAfter(report.createdAt));
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
/// *Brief now* before the first briefing, *Update now* once there is one to
/// update, and *Choose a model* or *Try again* after a failure. An
/// unenrolled person gets a plain card explaining what *important* turns
/// on, with the switch as the action.
///
/// The footer carries only the agent's own verbs. Logging a check-in and
/// calling are the page's verbs, and the sticky action bar holds both on
/// every viewport — offering them here too put the same two actions on
/// screen twice, loud in one place and quiet in the other.
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

  /// The interval picked on the not-enrolled face, null until a pill is
  /// tapped — the face then shows the stored interval, or the default the
  /// runtime would apply. Whatever it shows is what [_markImportant] saves,
  /// so one tap on the button never schedules a rhythm nobody saw.
  int? _enrolCadenceDays;

  int get _shownEnrolCadenceDays =>
      _enrolCadenceDays ??
      relationshipShownCadenceDays(
        widget.relationship.data.checkInCadenceDays,
      );

  /// Re-renders the "as of" meta when its displayed bucket next changes:
  /// computed only at build, a briefing rendered "just now" would keep that
  /// label for hours. One wake per visible change, not a per-second tick.
  Timer? _ageTick;

  /// The timestamp [_ageTick] was armed against, so a rebuild that changes
  /// nothing about the age leaves the running timer alone.
  DateTime? _ageTickFor;

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
  void dispose() {
    _ageTick?.cancel();
    super.dispose();
  }

  /// Arms one timer for the instant the "as of" line would read differently.
  ///
  /// Armed from `build`, which this card runs on any of six watched providers
  /// — an agent tick, a token-usage update, an identity arriving. Re-arming
  /// on each of those is harmless only because [untilNextAgeBucket] measures
  /// to the next *boundary* from where the age already sits, so a re-arm
  /// lands on the same instant rather than pushing a fresh bucket out; a
  /// helper that returned a whole minute would starve the line on a card that
  /// keeps rebuilding. Rather than leave that resting on the helper, a tick
  /// already armed for [writtenAt] is left alone, and re-armed only once it
  /// has fired or the timestamp it measures from has changed.
  void _armAgeTick(DateTime writtenAt) {
    if (_ageTick != null && _ageTickFor == writtenAt) return;
    _cancelAgeTick();
    _ageTickFor = writtenAt;
    _ageTick = Timer(untilNextAgeBucket(clock.now().difference(writtenAt)), () {
      _ageTick = null;
      _ageTickFor = null;
      if (mounted) setState(() => _arrivedCurrent = false);
    });
  }

  void _cancelAgeTick() {
    _ageTick?.cancel();
    _ageTick = null;
    _ageTickFor = null;
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
    final logger = ref.read(domainLoggerProvider);
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
      logger.error(
        LogDomain.agentWorkflow,
        error,
        stackTrace: stackTrace,
        subDomain: 'RelationshipBriefingCard',
        message: 'Failed to request a relationship briefing',
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
  /// what creates their agent (ADR 0059 Decision 2), and the interval the
  /// face shows as selected is stored with it. The save is followed
  /// by the same lazy-create call the edit form makes — fire-and-forget with
  /// contained failure, because agent wiring must never fail the save the
  /// user just watched succeed. Both services are read before the await:
  /// the agent is minted after this widget may be gone.
  Future<void> _markImportant() async {
    if (_marking) return;
    final messages = context.messages;
    final repository = ref.read(relationshipRepositoryProvider);
    final agentService = ref.read(relationshipAgentServiceProvider);
    final logger = ref.read(domainLoggerProvider);
    setState(() => _marking = true);
    try {
      final relationship = widget.relationship;
      final enrolled = relationship.copyWith(
        data: relationship.data.copyWith(
          important: true,
          checkInCadenceDays: _shownEnrolCadenceDays,
        ),
      );
      final saved = await repository.updateRelationship(enrolled);
      if (saved) {
        ensureRelationshipAgentInBackground(
          agentService,
          enrolled,
          source: 'RelationshipBriefingCard',
          domainLogger: logger,
        );
      } else if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: messages.relationshipErrorUpdateFailed,
        );
      }
    } catch (error, stackTrace) {
      logger.error(
        LogDomain.general,
        error,
        stackTrace: stackTrace,
        subDomain: 'RelationshipBriefingCard',
        message: 'Failed to mark the person important',
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
        cadenceDays: _shownEnrolCadenceDays,
        onCadenceSelected: (days) => setState(() => _enrolCadenceDays = days),
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
      RelationshipAgentCardState.failed => state?.lastWakeFailedAt,
      _ => report?.createdAt,
    };
    if (aged != null) {
      _armAgeTick(aged);
    } else {
      _cancelAgeTick();
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
    required this.cadenceDays,
    required this.onCadenceSelected,
    required this.onMarkImportant,
  });

  final RelationshipListItem item;
  final bool marking;

  /// The interval the enrol button will store, shown as the selected pill.
  final int cadenceDays;
  final ValueChanged<int> onCadenceSelected;

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
                  // The band and the pill's own words for this state, so
                  // one fact has one name on the list and on the page.
                  messages.relationshipNotEnrolled,
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
              // Prose in the prose ink, like the six enrolled faces.
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          // How often, before the tap that turns it on: the button enrols in
          // one tap, so the rhythm it applies has to be on screen already —
          // and changeable — rather than a default discovered later.
          if (!paused)
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.cardPadding,
                0,
                tokens.spacing.cardPadding,
                tokens.spacing.step4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    messages.relationshipCadencePromptLabel,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step3),
                  DsChoicePills<int>(
                    key: const ValueKey('relationship-agent-enrol-cadence'),
                    value: cadenceDays,
                    values: relationshipCadenceChoices(cadenceDays),
                    labelFor: (preset) =>
                        relationshipCadenceLabel(context, preset),
                    onSelected: marking ? (_) {} : onCadenceSelected,
                  ),
                ],
              ),
            ),
          // No privacy caption here. It read "Only what you start yourself
          // uses AI" and sat in the slot beside the control that starts an
          // agent which wakes on a cadence and writes briefings without
          // being asked each time — so it described a state the reader was
          // one tap from leaving, and said nothing about the one they were
          // heading into. An unexplained disclaimer in the one place it is
          // about to stop applying is worse than none; what the agent
          // sends belongs somewhere it can actually be explained.
          _AgentCardFooter(
            plain: true,
            action: paused
                ? null
                : DesignSystemButton(
                    key: const ValueKey('relationship-agent-mark-important'),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    // Named with the same verb the state uses: the band,
                    // the pill and the summary all say *enrolled*, so the
                    // control that ends *Not enrolled* says it too.
                    label: messages.relationshipAgentEnrolPerson(
                      data.nickname ?? data.title,
                    ),
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

/// The sentence under the band: what the briefing read to land on it.
///
/// Kept to three lines — the contract asks for one sentence, and a model
/// that writes an essay must not push the briefing itself off the card.
class _BandRationale extends StatelessWidget {
  const _BandRationale({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.cardPadding,
        0,
        tokens.spacing.cardPadding,
        tokens.spacing.step3,
      ),
      child: Text(
        text,
        key: const ValueKey('relationship-agent-band-rationale'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: tokens.typography.styles.body.bodySmall.copyWith(color: color),
      ),
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
