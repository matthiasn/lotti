part of 'goal_agent_detail_page.dart';

/// The resolved state one [_GoalDetailList._detailList] build reads, computed
/// once per page build.
typedef _GoalDetailInputs = ({
  DsTokens tokens,
  AsyncValue<GoalAgentHealth> healthAsync,
  AgentDomainEntity? agentState,
  AgentIdentityEntity goalIdentity,
  bool isActive,
  GoalAgentHealth? health,
  GoalSpecVersionEntity? spec,
  bool rangeFailed,
  GoalProgressView? progress,
  int renderedTimeSpanDays,
  List<GoalAssessmentRecord> assessments,
  List<({NudgeBannerEntry entry, DateTime? shellHiddenUntil})> nudges,
  bool hasStandingAssessment,
  AgentReportEntity? latestReport,
  VoidCallback openComposer,
  Widget Function({int? maxBeats}) checkInsCard,
});

/// The goal detail page's scrolling list of cards, from one build's inputs.
extension _GoalDetailList on _GoalAgentDetailPageState {
  Widget _detailList(
    BuildContext context,
    _GoalDetailInputs inputs, {
    required bool showChatAction,
    double? contentMaxWidth,
    bool showRail = false,
  }) {
    final (
      :tokens,
      :healthAsync,
      :agentState,
      :goalIdentity,
      :isActive,
      :health,
      :spec,
      :rangeFailed,
      :progress,
      :renderedTimeSpanDays,
      :assessments,
      :nudges,
      :hasStandingAssessment,
      :latestReport,
      :openComposer,
      :checkInsCard,
    ) = inputs;
    final canReflect = isActive && spec != null;
    final thisWeek =
        progress != null &&
            GoalThisWeekCard.shouldShow(progress, canReflect: canReflect)
        ? GoalThisWeekCard(
            progress: progress,
            scrollGroup: _trackScrollGroup,
            // The user's own verdict outranks the measurement in the
            // strip: a day they filed as missed must not keep rendering as
            // the neutral grey of a day with no data.
            //
            // Scoped to the ACTIVE spec. Spec versions are immutable and
            // the history keeps them all, so an unscoped map would let a
            // verdict passed on the old criteria colour the same date
            // under the new ones — a judgement of a goal that no longer
            // exists.
            ratingsByDay: spec == null
                ? const {}
                : latestRatingsByDay(
                    assessments,
                    specVersionId: spec.id,
                  ),
            onReflectDay: !canReflect
                ? null
                : (day) => _openReflection(
                    spec: spec,
                    progress: progress,
                    assessments: assessments,
                    day: day,
                  ),
          )
        : null;
    final agentRead = _AgentReadCard(
      agentId: agentId,
      identity: goalIdentity,
      agentState: agentState is AgentStateEntity ? agentState : null,
      canRefresh: isActive,
      healthAsync: healthAsync,
      report: latestReport,
      isStale:
          (agentState is AgentStateEntity ? agentState : null)?.isReportStale ??
          false,
    );
    final sections = <Widget>[
      _GoalHeader(
        key: _headerKey,
        identity: goalIdentity,
        health: health,
        healthAvailable: healthAsync.hasValue,
        spec: spec,
        // An ACTIVE goal's header stays tidy — the title names the goal
        // and the full definition lives behind Edit goal. A dormant goal
        // has no Edit doorway, so the header is the statement's only
        // remaining surface and must keep showing it.
        showStatement: !isActive,
        // Whatever the page is ACTUALLY showing as an assessment — the
        // spec-matched report when there is one, otherwise the one-liner
        // the card falls back to. Keying only off the report let the chip
        // reappear on exactly the surfaces still displaying a summary.
        hasStandingAssessment: hasStandingAssessment,
      ),
      SizedBox(height: tokens.spacing.cardItemSpacing),
      // The hero stack: the agent's narrative above the deterministic
      // week — the two answers to "how is this going" — each at the
      // full content width, so the day strip and the read never trade
      // legibility for a shared row. The stretching Column matters: on
      // desktop every section sits under an Align whose loose constraints
      // would otherwise let the cards shrink-wrap.
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The read LEADS: the agent's judgement is the page's answer to
          // "how is this going", and the deterministic day strip is its
          // first piece of evidence beneath.
          agentRead,
          if (thisWeek != null) ...[
            SizedBox(height: tokens.spacing.cardItemSpacing),
            thisWeek,
          ],
          // Directly after the week: the reflect row and the check-in list
          // are the two halves of "what I've said about this goal", so they
          // belong adjacent. On desktop this same card is hoisted into the
          // rail instead.
          if (!showRail) ...[
            SizedBox(height: tokens.spacing.cardItemSpacing),
            checkInsCard(maxBeats: 3),
          ],
        ],
      ),
      // Every active banner remains reachable here, uncapped. The shell
      // rotates one slot; this goal-owned surface does not. Banners are an
      // interaction channel, not a replacement for the standing report.
      for (final item in nudges) ...[
        SizedBox(height: tokens.spacing.step3),
        NudgeBannerExposureTracker(
          key: ValueKey(
            '${item.entry.nudge.id}:${item.entry.nudge.activationCount}',
          ),
          nudgeId: item.entry.nudge.id,
          child: GoalBannerCard(
            entry: item.entry,
            // Always non-null: a null callback would fall back to the
            // card's default navigate-to-detail — a self-navigation no-op
            // on this page. While the evidence is still resolving the CTA
            // anchors (or quietly no-ops) and heals when progress lands.
            // Answer the banner with the verb it names. A nudge about a
            // habit still opens the one-tap capture sheet; when there is
            // nothing to tick off, the useful answer is to say something —
            // "can't do it right now? Say when you will" — so the CTA opens
            // the check-in composer instead of doing nothing.
            onCtaPressed: () {
              final resolved = progress;
              if (resolved != null && resolved.habits.isNotEmpty) {
                _logToday(resolved);
              } else if (isActive) {
                openComposer();
              } else {
                _scrollToProgress();
              }
            },
          ),
        ),
        if (item.shellHiddenUntil case final hiddenUntil?) ...[
          SizedBox(height: tokens.spacing.step1),
          _GoalBannerShellReturnCountdown(hiddenUntil: hiddenUntil),
        ],
      ],
      // Gated on there BEING a change set, not merely on the agent being
      // active. The card renders nothing when nothing is pending, so an
      // active goal with no proposal still paid a full card gap here — the
      // one broken interval in an otherwise even stack.
      if (isActive && (health?.pendingProposals ?? 0) > 0) ...[
        SizedBox(height: tokens.spacing.cardItemSpacing),
        ChangeSetSummaryCard.selfTargeted(
          agentId: agentId,
          confirmationProvider: goalChangeSetConfirmationServiceProvider,
        ),
      ],
      if (progress != null) ...[
        SizedBox(height: tokens.spacing.cardItemSpacing),
        KeyedSubtree(
          key: _progressSectionKey,
          child: GoalProgressCard(
            progress: progress,
            assessments: assessments,
            specVersionId: spec?.id,
            scrollGroup: _trackScrollGroup,
            // The page-wide range picker rides the first evidence
            // heading — one control for every day track and the chart.
            habitsHeadingTrailing: TimeSpanSegmentedControl(
              // In auto mode the fitted span matches no segment, so none
              // highlights — which is the honest reading: no preset is
              // active until one is chosen.
              timeSpanDays: renderedTimeSpanDays,
              onValueChanged: (days) {
                // An explicit pick ends auto mode for this page instance.
                _rangePicked = true;
                ref.read(habitsControllerProvider.notifier).setTimeSpan(days);
              },
              segments: HabitsChartCard.timeSpans,
            ),
            onHabitOutcomeSelected: !isActive
                ? null
                : ({
                    required day,
                    required habitId,
                    required outcome,
                  }) async {
                    final saved = await ref
                        .read(goalHabitCompletionServiceProvider)
                        .record(
                          agentId: agentId,
                          habitId: habitId,
                          day: day,
                          outcome: outcome,
                        );
                    if (saved) {
                      ref
                        ..invalidate(goalAgentProgressViewProvider(agentId))
                        ..invalidate(goalAgentProgressViewForSpanProvider);
                    }
                    return saved;
                  },
          ),
        ),
      ],
      // The completion-rate chart scoped to THIS goal's habits — same
      // card shell as the habits page, the line computed on the goal's
      // slice of the shared day maps. Gate AND scope from the same
      // retained progress snapshot: during a spec revision the health can
      // carry the new spec while the progress deliberately retains the
      // old one, and mixing the two flashed an empty chart scoped by a
      // habit set the visible rows do not show.
      if (!rangeFailed && progress != null && progress.habits.isNotEmpty) ...[
        SizedBox(height: tokens.spacing.cardItemSpacing),
        HabitsChartCard(
          habitIds: {for (final habit in progress.habits) habit.habitId},
          title: context.messages.goalDetailCompletionRateTitle,
          // The page-level picker on the Habits heading governs the range.
          showTimeSpanPicker: false,
        ),
      ],
      // Daily reflections deliberately do NOT get a main-column card:
      // they live in the check-ins rail (the flyout on desktop, the
      // check-ins card on phones), where each one is a tight single row.
      if (showChatAction) ...[
        SizedBox(height: tokens.spacing.cardItemSpacing),
        DesignSystemButton(
          label: context.messages.goalChatTalkToAgent,
          onPressed: () => beamToNamed(goalChatPath(agentId)),
          leadingIcon: LottiIcons.chat,
          // Secondary: the persistent app-bar action is the primary
          // doorway; this tail button is the convenience for readers who
          // reached the bottom.
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.medium,
          fullWidth: true,
        ),
      ],
    ];
    // Eager, not lazy: the section count is small and bounded, and the
    // lazily mounted ListView made scrolling janky — heavy cards laid out
    // mid-fling — while also letting scrolled-away sections unmount (which
    // could null out the ensureVisible anchor). A single Column builds the
    // whole page once and scrolls smoothly.
    return SingleChildScrollView(
      controller: _scrollController,
      // The mobile shell keeps the bottom navigation overlaid on goals
      // subroutes, so the final content must clear it.
      // The Habits dashboard's behavior: a step6 gutter that holds on
      // small screens, with the centered cap binding on wide ones — the
      // goals list and this page share both numbers with Habits.
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step6,
        tokens.spacing.step5,
        tokens.spacing.step6,
        tokens.spacing.step5 +
            DesignSystemBottomNavigationBar.occupiedHeight(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in sections)
            if (contentMaxWidth == null)
              section
            else
              // The reading measure belongs to the CONTENT, not the scroll
              // view (constraining the scroll view parks the scrollbar at
              // the measure's edge, floating mid-pane). CENTERED in the
              // available width: left-aligned, a wide window carried a
              // dead right half whenever the chat drawer was closed.
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: section,
                ),
              ),
        ],
      ),
    );
  }
}
