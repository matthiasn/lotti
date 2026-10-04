part of 'goal_agent_detail_page.dart';

/// The §4b chat drawer: a ~400px non-modal overlay hosting the goal's
/// durable conversation. Its header carries the SAME computed pill as the
/// page — one status vocabulary, one source, so the two can never disagree.
class _GoalChatDrawer extends StatelessWidget {
  const _GoalChatDrawer({
    required this.agentId,
    required this.identity,
    required this.status,
    required this.hasStandingAssessment,
    required this.recoveryHint,
    required this.onClose,
  });

  final String agentId;
  final AgentIdentityEntity identity;
  final UnifiedGoalStatus? status;
  final bool hasStandingAssessment;
  final String? recoveryHint;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final status = this.status;
    final showPill =
        status != null &&
        !(status == UnifiedGoalStatus.noData && hasStandingAssessment);
    final color = status == null
        ? tokens.colors.text.lowEmphasis
        : unifiedGoalStatusColor(status, tokens.colors);
    // A bordered card surface rather than a shadow: `DsShadows` is reserved
    // for floating surfaces (menus, tooltips), and the calm card-on-canvas
    // language separates in-flow surfaces with the decorative hairline
    // instead.
    return Material(
      color: dsCardSurface(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: tokens.colors.decorative.level01),
          ),
        ),
        child: SizedBox(
          width: kGoalChatDrawerWidth,
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: tokens.colors.decorative.level01),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacing.step3),
                  child: Row(
                    children: [
                      NudgeBannerPersonaChip(
                        monogram: NudgeBannerPersonaChip.monogramFor(
                          identity.displayName,
                        ),
                        fill: color.withValues(alpha: SurfaceAlphas.washChip),
                      ),
                      SizedBox(width: tokens.spacing.step3),
                      Expanded(
                        child: Wrap(
                          spacing: tokens.spacing.step3,
                          runSpacing: tokens.spacing.step1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              identity.displayName,
                              // User-authored and unbounded; above an
                              // Expanded chat pane a many-line name would
                              // overflow the drawer's column, so two lines
                              // is the ceiling (the page app bar's rule).
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tokens.typography.styles.subtitle.subtitle2
                                  .copyWith(
                                    color: tokens.colors.text.highEmphasis,
                                  ),
                            ),
                            if (showPill)
                              UnifiedGoalStatusPill(
                                status: status,
                                recoveryHint: recoveryHint,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('goal-chat-drawer-close'),
                        icon: const Icon(LottiIcons.close),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GoalAgentChatPane(agentId: agentId, showHeader: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalHeader extends StatelessWidget {
  const _GoalHeader({
    required this.identity,
    required this.health,
    required this.healthAvailable,
    required this.spec,
    required this.hasStandingAssessment,
    required this.showStatement,
    super.key,
  });

  final AgentIdentityEntity identity;
  final GoalAgentHealth? health;
  final bool healthAvailable;
  final GoalSpecVersionEntity? spec;

  /// Whether the header renders the goal statement. False on an active
  /// goal (the definition lives behind Edit goal); true on a dormant one,
  /// where no Edit doorway exists and this is the statement's only surface.
  final bool showStatement;

  /// Whether the agent has already published an assessment of this goal.
  /// Suppresses the "No data" pill, which would otherwise sit directly
  /// above a report that plainly does assess the goal.
  final bool hasStandingAssessment;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // The SAME four-pill vocabulary as the unified Goals list (§4b: the
    // page pill and the drawer pill can never disagree, and neither may the
    // list's) — with the same display rules: only a resolved health carries
    // a verdict, and a "No data" pill must not sit directly above a
    // standing assessment that plainly contains data-driven judgement.
    final status = healthAvailable
        ? unifiedGoalStatusOf(health?.trackStatus)
        : null;
    final showPill =
        status != null &&
        !(status == UnifiedGoalStatus.noData && hasStandingAssessment);
    final recoveryHint = switch (health?.deficit) {
      final int deficit when deficit > 0 => messages.goalDaysToRecover(deficit),
      _ => null,
    };
    final color = status == null
        ? tokens.colors.text.lowEmphasis
        : unifiedGoalStatusColor(status, tokens.colors);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The chip anchors to the title's FIRST line: as a Wrap sibling a
        // long goal name stranded the monogram alone on the top line.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step1),
              child: NudgeBannerPersonaChip(
                monogram: NudgeBannerPersonaChip.monogramFor(
                  identity.displayName,
                ),
                fill: color.withValues(alpha: SurfaceAlphas.washChip),
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Wrap(
                spacing: tokens.spacing.step3,
                runSpacing: tokens.spacing.step2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    spec?.title ?? identity.displayName,
                    style: tokens.typography.styles.heading.heading3.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  if (showPill)
                    UnifiedGoalStatusPill(
                      status: status,
                      recoveryHint: recoveryHint,
                    ),
                  // Gated on the RAW health: with too little data to judge
                  // the goal, a green "Trending up" was the most confident
                  // statement in the header and the least supported by the
                  // evidence under it.
                  if (unifiedGoalStatusOf(health?.trackStatus) !=
                      UnifiedGoalStatus.noData)
                    if (health?.direction case final direction?)
                      GoalHealthDirectionChip(direction: direction),
                ],
              ),
            ),
          ],
        ),
        if (showStatement)
          if (spec?.statement case final statement?) ...[
            SizedBox(height: tokens.spacing.step3),
            Text(
              statement,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
      ],
    );
  }
}

/// The §4b "Agent's read" hero card: the narrative half of the hero stack.
///
/// Deterministic numbers on this page are never stale by construction; the
/// narrative IS allowed to age, so it carries its generation timestamp — and
/// when the runtime marks the report stale, the timestamp slot self-demotes
/// to the out-of-date notice instead (the §4b freshness contract). Ask-why
/// hands the verdict on screen to the conversation.
/// The goal agent's read — the same "intelligence" panel as the task
/// agent section on Task Details, wearing the shared [aiCardDecoration]
/// chrome and [TldrHeader], with the same reload affordances
/// ([AgentAutomationRow]) and the goal's cumulative inference cost pills
/// in the footer. One panel language across agent surfaces: change the
/// tokens or the wash once, both cards follow.
///
/// Deterministic numbers on this page are never stale by construction; the
/// narrative IS allowed to age, so the header's trailing slot carries its
/// generation age — and when the runtime marks the report stale it
/// self-demotes to the out-of-date notice (the freshness contract). Ask-why
/// hands the verdict on screen to the conversation.
class _AgentReadCard extends ConsumerStatefulWidget {
  const _AgentReadCard({
    required this.agentId,
    required this.identity,
    required this.agentState,
    required this.canRefresh,
    required this.healthAsync,
    required this.report,
    required this.isStale,
  });

  final String agentId;
  final AgentIdentityEntity identity;
  final AgentStateEntity? agentState;
  final bool canRefresh;
  final AsyncValue<GoalAgentHealth> healthAsync;
  final AgentReportEntity? report;
  final bool isStale;

  @override
  ConsumerState<_AgentReadCard> createState() => _AgentReadCardState();
}

class _AgentReadCardState extends ConsumerState<_AgentReadCard> {
  /// Re-renders the "as of" caption when its DISPLAYED bucket next changes:
  /// computed only at build, a read rendered "just now" kept that label for
  /// hours. Armed at the next minute/hour/day boundary of the read's age —
  /// one wake per visible change, not a per-second tick.
  Timer? _ageTick;
  bool _automationBusy = false;
  bool _cancelledManually = false;

  @override
  void dispose() {
    _ageTick?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AgentReadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldWake = oldWidget.agentState?.nextWakeAt;
    final newWake = widget.agentState?.nextWakeAt;
    if (newWake != oldWake && newWake?.isAfter(clock.now()) == true) {
      _cancelledManually = false;
    }
  }

  void _armAgeTick(DateTime generatedAt) {
    _ageTick?.cancel();
    _ageTick = Timer(
      untilNextAgeBucket(clock.now().difference(generatedAt)),
      () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _updateAutomaticUpdates(bool enabled) async {
    if (_automationBusy) return;
    setState(() => _automationBusy = true);
    try {
      await ref
          .read(goalAgentServiceProvider)
          .updateAutomaticUpdates(
            agentId: widget.agentId,
            enabled: enabled,
          );
      _cancelledManually = false;
    } finally {
      if (mounted) setState(() => _automationBusy = false);
    }
  }

  void _openInternals() {
    Navigator.of(context).push(
      AgentInternalsPanel.route(
        context: context,
        agentId: widget.agentId,
        agentName: widget.identity.displayName,
      ),
    );
  }

  /// The failure's own words, minus executor wrapping. The provider error
  /// ("Insufficient balance…", a timeout, an HTTP status) is the actionable
  /// part — a bare "failed" would leave the user exactly as stranded as the
  /// silence this line replaces.
  static String _failureReason(WakeRunCompletion completion) {
    final raw = completion.error?.toString().trim();
    if (raw == null || raw.isEmpty) return '';
    const wrappers = [
      'Bad state: ',
      'StateError: ',
      'TimeoutException: ',
      'Exception: ',
    ];
    var reason = raw;
    for (final wrapper in wrappers) {
      if (reason.startsWith(wrapper)) {
        reason = reason.substring(wrapper.length);
      }
    }
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final report = widget.report;
    final oneLiner = widget.healthAsync.value?.reportOneLiner;
    final generatedAt = report?.createdAt;
    // Staleness is a judgement OF a displayed read: with no report and no
    // one-liner there is nothing whose freshness could be out of date, and
    // "Out of date" directly above "No report yet" reads as a contradiction.
    final hasReadContent =
        report != null || (oneLiner?.trim().isNotEmpty ?? false);
    // Staleness belongs to the automation band, where it sits beside the
    // action that resolves it ("Out of date · Update now"). The header rail
    // says only how old the read is — printing the same warning in both
    // places made one state look like two problems.
    final String? freshness;
    if (generatedAt == null) {
      freshness = null;
      _ageTick?.cancel();
    } else {
      freshness = messages.goalDetailReadAsOf(
        relativeAgoLabel(messages, clock.now().difference(generatedAt)),
      );
      _armAgeTick(generatedAt);
    }

    final isRefreshing =
        ref.watch(agentIsRunningProvider(widget.agentId)).value ?? false;
    // The last decisive report-wake outcome, so a refresh that DIED
    // (provider out of credits, network down, the executor timeout) tells
    // the user instead of leaving a dead button under an eternal "Out of
    // date". A later successful update emits a completed outcome and clears
    // the line. While a RETRY is in flight the running state takes the
    // stage — scoped to the report-refresh workspace, so an unrelated chat
    // run or Phase A subscription tick for the same agent cannot blink the
    // error away. And a success that arrives by SYNC (another device
    // refreshed) outranks an older local failure: `reportFreshAt` records
    // the successful run's START, so it is compared against this failure's
    // start — a refresh that began after ours began saw at least our
    // evidence, even when its watermark predates our finish.
    final lastOutcome = ref
        .watch(goalReportWakeOutcomeProvider(widget.agentId))
        .value;
    final reportRefreshInFlight =
        ref.watch(goalReportWakeInFlightProvider(widget.agentId)).value ??
        false;
    final reportFreshAt = widget.agentState?.reportFreshAt;
    final failureAnchor = lastOutcome?.startedAt ?? lastOutcome?.finishedAt;
    // Two ways durable evidence outranks the in-process failure: the
    // freshness watermark advanced (a successful refresh, local or synced —
    // start-to-start comparison, see above), or the DISPLAYED report itself
    // was published after this failure began — the timed-out executor's
    // future is deliberately allowed to finish late, and its report arrives
    // by notification without any completed outcome or fresh watermark.
    final supersededByNewerEvidence =
        failureAnchor != null &&
        ((reportFreshAt != null && reportFreshAt.isAfter(failureAnchor)) ||
            (report != null && report.createdAt.isAfter(failureAnchor)));
    final updateFailure =
        !reportRefreshInFlight &&
            lastOutcome != null &&
            lastOutcome.status != WakeRunStatus.completed &&
            !supersededByNewerEvidence
        ? lastOutcome
        : null;
    final nextWakeAt = widget.agentState?.nextWakeAt;
    final automaticUpdatesEnabled = GoalAgentService.automaticUpdatesEnabled(
      widget.identity,
    );
    final showCountdown =
        widget.canRefresh &&
        automaticUpdatesEnabled &&
        !isRefreshing &&
        !_cancelledManually &&
        nextWakeAt?.isAfter(clock.now()) == true;

    return DecoratedBox(
      key: const ValueKey('goal-agent-read-card'),
      decoration: aiCardDecoration(context),
      child: ClipRRect(
        borderRadius: aiCardRadius(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The same header as the task agent section: sparkle badge, the
            // shared card title, the persona underneath, tap → internals.
            // The trailing slot carries the read's freshness instead of a
            // playback control.
            TldrHeader(
              agentName: widget.identity.displayName,
              onAgentTap: _openInternals,
              // The card's two meta facts on one trailing rail: what this
              // goal's agent has cost over its lifetime, and how old the
              // read below it is. Neither earns a row of the card's body —
              // the header rail was empty space beside them.
              // A Wrap, not a Row: the slot's cap bounds the RAIL, and a Row
              // would still lay these two out at their intrinsic widths and
              // clip past it. Both facts are money-and-time figures that a
              // longer locale or a raised text scale lengthens, so when they
              // stop fitting side by side the caption drops UNDER the pill —
              // end-aligned, still the header's trailing rail — rather than
              // either of them being truncated into a wrong number.
              trailing: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: tokens.spacing.step3,
                runSpacing: tokens.spacing.step1,
                children: [
                  GoalAgentLifetimePills(agentId: widget.agentId, inline: true),
                  if (freshness != null)
                    Text(
                      freshness,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.aiCard.metaText,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.cardPadding,
                0,
                tokens.spacing.cardPadding,
                tokens.spacing.step3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GoalReportCard(
                    report: report,
                    fallback:
                        oneLiner ??
                        (widget.healthAsync.hasError
                            ? messages.goalDetailHealthUnavailable
                            : messages.goalDetailNoReport),
                    fallbackMuted: oneLiner == null,
                  ),
                  if (updateFailure != null) ...[
                    SizedBox(height: tokens.spacing.step3),
                    Row(
                      key: const ValueKey('goal-agent-update-failed'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LottiIcons.error,
                          size:
                              tokens.typography.styles.body.bodySmall.fontSize,
                          color: tokens.colors.alert.error.ink,
                        ),
                        SizedBox(width: tokens.spacing.step1),
                        Expanded(
                          child: Text(
                            switch (_failureReason(updateFailure)) {
                              '' => messages.goalDetailUpdateFailed,
                              final reason =>
                                messages.goalDetailUpdateFailedWithReason(
                                  reason,
                                ),
                            },
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: tokens.colors.alert.error.ink,
                                ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.canRefresh) ...[
                    SizedBox(height: tokens.spacing.step3),
                    // The same reload affordances as the task agent section:
                    // freshness state, countdown, skip-once, Update now and
                    // the automatic-updates switch.
                    AgentAutomationRow(
                      compact: !isDesktopLayout(context),
                      // "Updates on changes" restates the switch beside it:
                      // automatic updates being ON *is* the promise. The
                      // countdown, which says something the switch cannot,
                      // still takes the slot whenever a run is pending.
                      showsIdleScheduleLabel: false,
                      automaticUpdatesEnabled: automaticUpdatesEnabled,
                      automationBusy: _automationBusy,
                      inferenceAvailable: true,
                      isRunning: isRefreshing,
                      // The agent-wide flag keeps the trigger busy while ANY
                      // run holds the lock — a chat reply, a Phase A tick —
                      // but only a report refresh replaces the read, so only
                      // that one may call it out of date.
                      isRefreshingReport: reportRefreshInFlight,
                      showCountdown: showCountdown,
                      nextWakeAt: nextWakeAt,
                      hasReportContent: hasReadContent,
                      isStale: widget.agentState?.isReportStale ?? false,
                      onAutomaticUpdatesChanged: (enabled) =>
                          unawaited(_updateAutomaticUpdates(enabled)),
                      onRunNow: () => ref
                          .read(goalHabitCompletionServiceProvider)
                          .requestReportRefresh(widget.agentId),
                      onSkipScheduledUpdate: () {
                        ref
                            .read(goalAgentServiceProvider)
                            .skipPendingReportRefresh(widget.agentId);
                        setState(() => _cancelledManually = true);
                      },
                      onCountdownExpired: () =>
                          ref.invalidate(agentStateProvider(widget.agentId)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "back in the bar" caption under a banner that is snoozed or dismissed
/// from the shell dock. A live countdown (the shared [WakeCountdownState]
/// second-tick, TickerMode-aware) rather than a static estimate, and it
/// renders nothing once the deadline passes — at that instant the dock shows
/// the banner again and the caption would be stating a falsehood.
class _GoalBannerShellReturnCountdown extends StatefulWidget {
  const _GoalBannerShellReturnCountdown({required this.hiddenUntil});

  final DateTime hiddenUntil;

  @override
  State<_GoalBannerShellReturnCountdown> createState() =>
      _GoalBannerShellReturnCountdownState();
}

class _GoalBannerShellReturnCountdownState
    extends State<_GoalBannerShellReturnCountdown>
    with WakeCountdownState<_GoalBannerShellReturnCountdown> {
  @override
  DateTime get nextWakeAt => widget.hiddenUntil;

  @override
  void didUpdateWidget(covariant _GoalBannerShellReturnCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hiddenUntil != widget.hiddenUntil) resyncCountdown();
  }

  @override
  void onCountdownExpired() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (countdownSeconds <= 0) return const SizedBox.shrink();
    final tokens = context.designTokens;
    return Row(
      key: const ValueKey('goal-banner-shell-return-countdown'),
      children: [
        Icon(
          LottiIcons.snooze,
          size: tokens.typography.styles.others.caption.fontSize,
          color: tokens.colors.text.lowEmphasis,
        ),
        SizedBox(width: tokens.spacing.step1),
        Expanded(
          child: Text(
            // Wraps freely: the countdown value sits at the END of the
            // sentence in most locales, and a one-line ellipsis would cut
            // off the exact return time this caption exists to state.
            context.messages.goalBannerHiddenFromBar(
              formatCountdown(countdownSeconds),
            ),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}
