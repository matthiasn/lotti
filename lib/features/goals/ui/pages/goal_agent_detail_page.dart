import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_automation_row.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/features/goals/service/goal_habit_completion_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';
import 'package:lotti/features/goals/ui/goal_agent_lifetime_pills.dart';
import 'package:lotti/features/goals/ui/goal_assessment_widgets.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';
import 'package:lotti/features/goals/ui/goal_banner_dock.dart';
import 'package:lotti/features/goals/ui/goal_banner_exposure_tracker.dart';
import 'package:lotti/features/goals/ui/goal_banner_widgets.dart';
import 'package:lotti/features/goals/ui/goal_coarse_health.dart';
import 'package:lotti/features/goals/ui/goal_log_today_sheet.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/features/goals/ui/goal_status_chip.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// One goal agent: rolling progress, active banners (including any that the
/// host strips' visible cap holds back), pending revision proposals, watching
/// metadata and outcome history. Desktop gives the durable conversation a
/// peer pane; mobile opens the same projection as a pushed page.
class GoalAgentDetailPage extends ConsumerStatefulWidget {
  const GoalAgentDetailPage({required this.agentId, super.key});

  final String agentId;

  @override
  ConsumerState<GoalAgentDetailPage> createState() =>
      _GoalAgentDetailPageState();
}

class _GoalAgentDetailPageState extends ConsumerState<GoalAgentDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _appBarTitleVisible = ValueNotifier<bool>(false);
  final GlobalKey _progressSectionKey = GlobalKey();
  final GlobalKey _headerKey = GlobalKey();

  String get agentId => widget.agentId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncAppBarTitle);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_syncAppBarTitle)
      ..dispose();
    _appBarTitleVisible.dispose();
    super.dispose();
  }

  /// The page opens with one title — the H1 in the header. The app bar's
  /// copy only fades in once the header has actually scrolled away (its
  /// laid-out extent, not a fixed offset — a wrapped title or a large text
  /// scale grows the header), so the goal name never reads twice in the
  /// same viewport.
  void _syncAppBarTitle() {
    final headerBox = _headerKey.currentContext?.findRenderObject();
    final threshold = headerBox is RenderBox && headerBox.hasSize
        ? headerBox.size.height
        : context.designTokens.spacing.step12;
    _appBarTitleVisible.value =
        _scrollController.hasClients && _scrollController.offset > threshold;
  }

  /// The banner CTA performs the verb it names: a goal with loggable habit
  /// dimensions opens the one-tap capture sheet; otherwise the CTA anchors
  /// to the evidence — never a navigation to the route the user is on.
  void _logToday(GoalProgressView progress) {
    if (progress.habits.isEmpty) {
      _scrollToProgress();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => GoalLogTodaySheet(
        agentId: agentId,
        progress: progress,
      ),
    );
  }

  void _scrollToProgress() {
    final target = _progressSectionKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MotionDurations.medium4,
      curve: MotionCurves.emphasizedDecelerate,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final identityAsync = ref.watch(agentIdentityProvider(agentId));
    final healthAsync = ref.watch(goalAgentHealthProvider(agentId));
    final agentState = ref.watch(agentStateProvider(agentId)).value;
    // Stale-while-revalidate: `.value` keeps the last render across
    // background reloads; only a load that has never produced data gets
    // the spinner. An errored load must not claim "no report yet".
    // EVERY pop — AppBar button, Android system back, iOS gesture —
    // routes through NavService so currentPath and the persisted route
    // return to the Agents root instead of pinning this child.
    final backToList = BackButton(onPressed: () => beamToNamed('/agents'));
    Widget popSafe(Widget child) => PopScope(
      // canPop stays TRUE: false would disable the iOS swipe-back
      // gesture entirely. The route pops normally; the completed pop
      // then persists the Agents root through NavService.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Post-frame: the pop is mid-router-update — persisting the root
        // synchronously would re-enter the delegate while it notifies.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => beamToNamed('/agents'),
        );
      },
      child: child,
    );
    if ((!healthAsync.hasValue && !healthAsync.hasError) ||
        (!identityAsync.hasValue && !identityAsync.hasError)) {
      return popSafe(
        Scaffold(
          appBar: AppBar(leading: backToList, title: const Text('')),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    // A stale link, a foreign route, OR a FIRST identity load that
    // failed: none of these may mount proposals and history as if the
    // goal were healthy. A background reload error with a retained
    // identity keeps the established page (the no-flash rule).
    final identity = identityAsync.value;
    if ((identityAsync.hasError && !identityAsync.hasValue) ||
        (identityAsync.hasValue &&
            (identity is! AgentIdentityEntity ||
                identity.kind != AgentKinds.goalAgent))) {
      return popSafe(
        Scaffold(
          appBar: AppBar(leading: backToList, title: const Text('')),
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step5),
              child: Text(
                identityAsync.hasError && !identityAsync.hasValue
                    ? context.messages.goalDetailHealthUnavailable
                    : context.messages.goalDetailNotFound,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final goalIdentity = identity! as AgentIdentityEntity;
    final isActive = goalIdentity.lifecycle == AgentLifecycle.active;
    final health = healthAsync.value;
    final spec = health?.spec;
    final progress = spec == null
        ? null
        : ref.watch(goalAgentProgressViewProvider(agentId)).value;
    final assessments =
        ref.watch(goalAssessmentHistoryProvider(agentId)).value ?? const [];
    // Same render-time staleness contract as the strip: retained data
    // from a failed deadline reload keeps fresh banners (no-flash) but
    // never expired copy — whose tracker would keep counting exposure.
    final locallySnoozed = ref.watch(locallySnoozedNudgeDeadlinesProvider);
    final nudges = [
      for (final entry in visibleGoalBannerEntries(
        entries: ref.watch(activeGoalNudgesProvider).value,
        locallySnoozedDeadlines: locallySnoozed,
      ))
        if (entry.nudge.agentId == agentId) entry,
    ];
    final history =
        ref.watch(goalNudgeHistoryProvider(agentId)).value ??
        const <GoalNudgeEntity>[];
    final report = ref.watch(agentReportProvider(agentId)).value;
    AgentReportEntity? latestReport;
    if (report is AgentReportEntity &&
        report.scope == AgentReportScopes.current &&
        report.deletedAt == null) {
      final reportSpecId = report.provenance['specVersionId'];
      final matchesSpec =
          spec != null &&
          (reportSpecId is String
              ? reportSpecId == spec.id
              : !report.createdAt.isBefore(spec.createdAt));
      if (matchesSpec) {
        latestReport = report;
      }
    }
    Widget detailList({required bool showChatAction}) => ListView(
      controller: _scrollController,
      // The mobile shell keeps the bottom navigation overlaid on agents
      // subroutes, so the final content must clear it.
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5 +
            DesignSystemBottomNavigationBar.occupiedHeight(context),
      ),
      children: [
        _GoalHeader(
          key: _headerKey,
          agentId: agentId,
          identity: goalIdentity,
          health: health,
          healthAvailable: healthAsync.hasValue,
          spec: spec,
          hasStandingAssessment:
              (latestReport?.tldr?.trim().isNotEmpty ?? false) ||
              latestReport?.content.trim().isNotEmpty == true,
        ),
        // The agent's voice — standing report and active banners — stays
        // grouped with the goal definition at the top; the evidence
        // (habit cards, then charts) follows below it.
        SizedBox(height: tokens.spacing.cardItemSpacing),
        _AgentSayingSection(
          agentId: agentId,
          healthAsync: healthAsync,
          nudges: nudges,
          report: latestReport,
          identity: goalIdentity,
          agentState: agentState is AgentStateEntity ? agentState : null,
          canRefresh: isActive,
          // Always non-null: a null callback would fall back to the card's
          // default navigate-to-detail — a self-navigation no-op on this
          // page. While the evidence is still resolving the CTA anchors
          // (or quietly no-ops) and heals when progress lands.
          onBannerCta: () {
            final resolved = progress;
            if (resolved != null) {
              _logToday(resolved);
            } else {
              _scrollToProgress();
            }
          },
        ),
        if (progress != null) ...[
          SizedBox(height: tokens.spacing.cardItemSpacing),
          KeyedSubtree(
            key: _progressSectionKey,
            child: GoalProgressCard(
              progress: progress,
              // The user's own verdict outranks the measurement in the strip:
              // a day they filed as missed must not keep rendering as the
              // neutral grey of a day with no data.
              //
              // Scoped to the ACTIVE spec. Spec versions are immutable and the
              // history keeps them all, so an unscoped map would let a verdict
              // passed on the old criteria colour the same date under the new
              // ones — a judgement of a goal that no longer exists.
              ratingsByDay: spec == null
                  ? const {}
                  : latestRatingsByDay(
                      assessments,
                      specVersionId: spec.id,
                    ),
              onReflectDay: !isActive || spec == null
                  ? null
                  : (day) => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => GoalDayAssessmentSheet(
                        agentId: agentId,
                        specVersionId: spec.id,
                        specVersion: spec.version,
                        day: day,
                        progress: progress,
                        // Reopening a judged day shows what was recorded.
                        // Arriving blank offered Met with an empty note, and
                        // saving replaced the real reflection with that
                        // default — note and dimension verdicts included.
                        existing: latestAssessmentsByDay(
                          assessments,
                          specVersionId: spec.id,
                        )[DateTime.utc(day.year, day.month, day.day)],
                      ),
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
                        ref.invalidate(goalAgentProgressViewProvider(agentId));
                      }
                      return saved;
                    },
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.cardItemSpacing),
        if (isActive)
          ChangeSetSummaryCard.selfTargeted(
            agentId: agentId,
            confirmationProvider: goalChangeSetConfirmationServiceProvider,
          ),
        if (progress != null && progress.dimensionCount > 0) ...[
          SizedBox(height: tokens.spacing.cardItemSpacing),
          _WatchingSection(progress: progress),
        ],
        if (progress != null && assessments.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.cardItemSpacing),
          GoalAssessmentHistoryCard(
            records: assessments,
            progress: progress,
          ),
        ],
        if (showChatAction) ...[
          SizedBox(height: tokens.spacing.cardItemSpacing),
          DesignSystemButton(
            label: context.messages.goalChatTalkTo(goalIdentity.displayName),
            onPressed: () => beamToNamed('/agents/details/$agentId/chat'),
            leadingIcon: Icons.chat_bubble_outline_rounded,
            // Secondary: the persistent app-bar action is the primary
            // doorway; this tail button is the convenience for readers who
            // reached the bottom.
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.medium,
            fullWidth: true,
          ),
        ],
        if (history.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.cardItemSpacing),
          _GoalHistorySection(history: history),
        ],
      ],
    );
    final desktop = isDesktopLayout(context);
    final chatAvailable = isActive;
    return popSafe(
      Scaffold(
        appBar: AppBar(
          leading: backToList,
          // The header's H1 owns the goal name at rest; the app bar copy
          // fades in only once the header scrolls away, so the name never
          // reads twice in one viewport.
          title: ValueListenableBuilder<bool>(
            valueListenable: _appBarTitleVisible,
            builder: (context, visible, child) => AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: MotionDurations.short3,
              child: child,
            ),
            // Two lines at a compact size rather than one truncated line.
            // "Blood Pressure managed 🫀" arrived as "Blood Pressure manage…",
            // which is the one thing an app-bar title exists to avoid, and
            // goal names are user-written so they are routinely this long.
            // Two lines of subtitle2 clear the toolbar height; a third would
            // not, so the ellipsis remains as the last resort it should be.
            child: Text(
              spec?.title ?? goalIdentity.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          actions: [
            // The conversation is the feature's second half — phones get a
            // persistent doorway beside the overflow instead of a button
            // buried below every card.
            if (!desktop && chatAvailable)
              IconButton(
                key: const ValueKey('goal-detail-chat-action'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                tooltip: context.messages.goalChatTalkTo(
                  goalIdentity.displayName,
                ),
                onPressed: () => beamToNamed('/agents/details/$agentId/chat'),
              ),
            _GoalActionsMenuButton(
              agentId: agentId,
              agentName: goalIdentity.displayName,
              canEdit: isActive && spec != null,
            ),
          ],
        ),
        body: SafeArea(
          child: desktop && chatAvailable
              ? Row(
                  children: [
                    Expanded(flex: 3, child: detailList(showChatAction: false)),
                    VerticalDivider(
                      color: tokens.colors.decorative.level01,
                    ),
                    Expanded(
                      flex: 2,
                      child: GoalAgentChatPane(agentId: agentId),
                    ),
                  ],
                )
              : detailList(showChatAction: !desktop && chatAvailable),
        ),
      ),
    );
  }
}

class _GoalHeader extends StatelessWidget {
  const _GoalHeader({
    required this.agentId,
    required this.identity,
    required this.health,
    required this.healthAvailable,
    required this.spec,
    required this.hasStandingAssessment,
    super.key,
  });

  final String agentId;
  final AgentIdentityEntity identity;
  final GoalAgentHealth? health;
  final bool healthAvailable;
  final GoalSpecVersionEntity? spec;

  /// Whether the agent has already published an assessment of this goal.
  /// Suppresses the "Not enough data" chip, which would otherwise sit
  /// directly above a report that plainly does assess the goal.
  final bool hasStandingAssessment;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // A header that sits directly above a populated report must not claim
    // there is not enough data to have written one.
    final coarse = coarseHealthChip(
      health?.trackStatus,
      hasStandingAssessment: hasStandingAssessment,
    );
    final color = goalCoarseHealthColor(
      coarse ?? coarseHealthOf(health?.trackStatus),
      tokens.colors,
    );
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
              child: GoalBannerPersonaChip(
                monogram: GoalBannerPersonaChip.monogramFor(
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
                  if (healthAvailable && coarse != null)
                    GoalCoarseHealthChip(health: coarse),
                  if (health?.direction case final direction?)
                    GoalHealthDirectionChip(direction: direction),
                ],
              ),
            ),
          ],
        ),
        GoalAgentLifetimePills(agentId: agentId),
        if (spec?.statement case final statement?) ...[
          SizedBox(height: tokens.spacing.step3),
          // Explicitly labelled as the aspiration: unlabelled, the statement
          // reads as the agent asserting current status directly against the
          // health chip above it.
          Text(
            context.messages.goalDetailStatementLabel,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
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

class _AgentSayingSection extends ConsumerStatefulWidget {
  const _AgentSayingSection({
    required this.agentId,
    required this.healthAsync,
    required this.nudges,
    required this.report,
    required this.identity,
    required this.agentState,
    required this.canRefresh,
    this.onBannerCta,
  });

  final String agentId;
  final AsyncValue<GoalAgentHealth> healthAsync;
  final List<GoalBannerEntry> nudges;
  final AgentReportEntity? report;
  final AgentIdentityEntity identity;
  final AgentStateEntity? agentState;
  final bool canRefresh;

  /// Anchor-scroll to the evidence this page hosts — the banner CTA must
  /// never navigate to the route the user is already on.
  final VoidCallback? onBannerCta;

  @override
  ConsumerState<_AgentSayingSection> createState() =>
      _AgentSayingSectionState();
}

class _AgentSayingSectionState extends ConsumerState<_AgentSayingSection> {
  bool _automationBusy = false;
  bool _cancelledManually = false;

  @override
  void didUpdateWidget(covariant _AgentSayingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldWake = oldWidget.agentState?.nextWakeAt;
    final newWake = widget.agentState?.nextWakeAt;
    if (newWake != oldWake && newWake?.isAfter(clock.now()) == true) {
      _cancelledManually = false;
    }
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isRefreshing =
        ref.watch(agentIsRunningProvider(widget.agentId)).value ?? false;
    final oneLiner = widget.healthAsync.value?.reportOneLiner;
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
    final hasReportContent = widget.report != null || oneLiner != null;
    final header = Text(
      context.messages.goalDetailSayingTitle,
      style: tokens.typography.styles.subtitle.subtitle1.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
    final reportCard = _GoalReportCard(
      report: widget.report,
      fallback:
          oneLiner ??
          (widget.healthAsync.hasError
              ? context.messages.goalDetailHealthUnavailable
              : context.messages.goalDetailNoReport),
      fallbackMuted: oneLiner == null,
    );
    return Column(
      // Stretch, not start: on wide panes the report card must share the
      // banners' right edge instead of shrink-wrapping to its prose.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        SizedBox(height: tokens.spacing.step2),
        if (widget.canRefresh) ...[
          AgentAutomationRow(
            automaticUpdatesEnabled: automaticUpdatesEnabled,
            automationBusy: _automationBusy,
            inferenceAvailable: true,
            isRunning: isRefreshing,
            showCountdown: showCountdown,
            nextWakeAt: nextWakeAt,
            hasReportContent: hasReportContent,
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
          SizedBox(height: tokens.spacing.step2),
        ],
        reportCard,
        // Every active banner remains reachable here, uncapped. The shell
        // rotates one slot; this goal-owned surface does not. Banners are an
        // interaction channel, not a replacement for the standing report.
        for (var index = 0; index < widget.nudges.length; index++) ...[
          SizedBox(height: tokens.spacing.step3),
          GoalBannerExposureTracker(
            key: ValueKey(
              '${widget.nudges[index].nudge.id}:'
              '${widget.nudges[index].nudge.activationCount}',
            ),
            nudgeId: widget.nudges[index].nudge.id,
            child: GoalBannerCard(
              entry: widget.nudges[index],
              onCtaPressed: widget.onBannerCta,
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalReportCard extends StatefulWidget {
  const _GoalReportCard({
    required this.report,
    required this.fallback,
    required this.fallbackMuted,
  });

  final AgentReportEntity? report;
  final String fallback;
  final bool fallbackMuted;

  @override
  State<_GoalReportCard> createState() => _GoalReportCardState();
}

class _GoalReportCardState extends State<_GoalReportCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final report = widget.report;
    final tldr = report?.tldr?.trim();
    final content = report?.content.trim();
    final hasTldr = tldr != null && tldr.isNotEmpty;
    final hasContent = content != null && content.isNotEmpty;
    // A full text identical to the TLDR would make Show more a no-op that
    // merely repeats the same paragraph — hide the toggle instead.
    final expandable = hasTldr && hasContent && content != tldr;
    final primary = hasTldr
        ? tldr
        : hasContent
        ? content
        : widget.fallback;

    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgentMarkdownView(
            primary,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: report == null && widget.fallbackMuted
                  ? tokens.colors.text.lowEmphasis
                  : tokens.colors.text.highEmphasis,
            ),
          ),
          if (expandable) ...[
            if (_expanded) ...[
              SizedBox(height: tokens.spacing.step3),
              // Sections when the report carries them, the flat text when it
              // does not. The sentences are model-authored in the user's own
              // language, so the composer cannot wrap them in headings without
              // injecting English — the headings are added here instead, which
              // also means they follow the app language rather than whichever
              // one the report was written in.
              if (_sectionsOf(report) case final sections?)
                _GoalReportSections(sections: sections)
              else
                AgentMarkdownView(
                  content,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
            ],
            SizedBox(height: tokens.spacing.step1),
            DesignSystemButton(
              label: _expanded
                  ? context.messages.aiResponseShowLess
                  : context.messages.aiResponseShowMore,
              onPressed: () => setState(() => _expanded = !_expanded),
              variant: DesignSystemButtonVariant.tertiary,
              size: DesignSystemButtonSize.dense,
              trailingIcon: _expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              alignsLabelToLeadingEdge: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _WatchingSection extends StatelessWidget {
  const _WatchingSection({required this.progress});

  final GoalProgressView progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.goalDetailWatchingTitle,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          for (var index = 0; index < progress.habits.length; index++) ...[
            if (index > 0) SizedBox(height: tokens.spacing.step3),
            Builder(
              builder: (context) {
                final habit = progress.habits[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      key: ValueKey('goal-watching-name-${habit.habitId}'),
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      '${goalHabitTargetLabel(context, targetCount: habit.targetCount, window: habit.window)}'
                      '${habit.successfulWeeks == null ? '' : ' · ${habit.successfulWeeks} / 6'}',
                      key: ValueKey('goal-watching-meta-${habit.habitId}'),
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          for (var index = 0; index < progress.metrics.length; index++) ...[
            if (progress.habits.isNotEmpty || index > 0)
              SizedBox(height: tokens.spacing.step3),
            Builder(
              builder: (context) {
                final metric = progress.metrics[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.name,
                      key: ValueKey(
                        'goal-watching-name-${metric.criterionId}',
                      ),
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      context.messages.goalWatchingMetric(
                        goalWindowLabel(context, metric.window),
                      ),
                      key: ValueKey(
                        'goal-watching-meta-${metric.criterionId}',
                      ),
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          SizedBox(height: tokens.spacing.step3),
          Text(
            context.messages.goalDetailWatchingSignals,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalHistorySection extends StatelessWidget {
  const _GoalHistorySection({required this.history});

  final List<GoalNudgeEntity> history;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.goalDetailTimelineTitle,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          for (var index = 0; index < history.length; index++) ...[
            if (index > 0)
              Divider(
                height: tokens.spacing.step4,
                color: tokens.colors.decorative.level01,
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '“${history[index].brief.headline}”',
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                Text(
                  goalNudgeStatusLabel(context, history[index].status),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _GoalDetailMenuAction { edit, internals, delete }

class _GoalActionsMenuButton extends ConsumerWidget {
  const _GoalActionsMenuButton({
    required this.agentId,
    required this.agentName,
    required this.canEdit,
  });

  final String agentId;
  final String agentName;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final danger = tokens.colors.alert.error.ink;
    return PopupMenuButton<_GoalDetailMenuAction>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) {
        switch (action) {
          case _GoalDetailMenuAction.edit:
            beamToNamed('/agents/details/$agentId/edit');
          case _GoalDetailMenuAction.internals:
            Navigator.of(context).push(
              AgentInternalsPanel.route(
                context: context,
                agentId: agentId,
                agentName: agentName,
              ),
            );
          case _GoalDetailMenuAction.delete:
            _confirmAndDelete(context, ref);
        }
      },
      itemBuilder: (context) => [
        if (canEdit)
          PopupMenuItem<_GoalDetailMenuAction>(
            value: _GoalDetailMenuAction.edit,
            child: Row(
              children: [
                const Icon(Icons.edit_outlined),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    context.messages.goalFormEditTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        PopupMenuItem<_GoalDetailMenuAction>(
          value: _GoalDetailMenuAction.internals,
          child: Row(
            children: [
              const Icon(Icons.tune_rounded),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  context.messages.aiCardOpenAgentInternals,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<_GoalDetailMenuAction>(
          value: _GoalDetailMenuAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: danger),
              SizedBox(width: tokens.spacing.step3),
              Text(
                context.messages.goalDeleteMenuItem,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: danger,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final messages = dialogContext.messages;
        return AlertDialog(
          title: Text(messages.goalDeleteDialogTitle),
          content: Text(messages.goalDeleteDialogContent),
          actions: [
            DesignSystemButton(
              label: messages.cancelButton,
              variant: DesignSystemButtonVariant.tertiary,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            DesignSystemButton(
              label: messages.goalDeleteConfirmButton,
              variant: DesignSystemButtonVariant.danger,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      try {
        final deleted = await ref
            .read(goalAgentServiceProvider)
            .deleteGoalAgent(agentId);
        if (!deleted || !context.mounted) return;
        beamToNamed('/agents');
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.messages.goalBannerActionFailed)),
          );
      }
    }
  }
}

/// The structured sections a report carries, or null when it has none —
/// a free-form report, or one written before sections were persisted.
Map<String, Object?>? _sectionsOf(AgentReportEntity? report) {
  final raw = report?.provenance[GoalReportProvenanceKeys.sections];
  if (raw is! Map) return null;
  final sections = <String, Object?>{};
  for (final entry in raw.entries) {
    if (entry.key is String) sections[entry.key as String] = entry.value;
  }
  return sections.isEmpty ? null : sections;
}

/// The expanded report, rendered as titled sections.
///
/// Headings come from the app's catalogs rather than the model, so they read
/// in the user's language whatever language the report was written in, and a
/// section the model left empty is simply absent rather than a heading with
/// nothing beneath it.
class _GoalReportSections extends StatelessWidget {
  const _GoalReportSections({required this.sections});

  final Map<String, Object?> sections;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final ordered = <(String, String)>[
      for (final (key, heading) in <(String, String)>[
        (
          GoalReportSectionKeys.currentPeriod,
          messages.goalReportSectionStanding,
        ),
        (GoalReportSectionKeys.rollingWindow, messages.goalReportSectionWindow),
        (GoalReportSectionKeys.latestChange, messages.goalReportSectionChange),
        (GoalReportSectionKeys.coverage, messages.goalReportSectionCoverage),
      ])
        if (sections[key] case final String body when body.trim().isNotEmpty)
          (heading, body.trim()),
    ];
    final actions = <String>[
      for (final action
          in (sections[GoalReportSectionKeys.nextActions] as List<Object?>? ??
              const <Object?>[]))
        if (action is String && action.trim().isNotEmpty) action.trim(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, (heading, body)) in ordered.indexed) ...[
          if (index > 0) SizedBox(height: tokens.spacing.step4),
          Text(
            heading,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
          AgentMarkdownView(
            body,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
        if (actions.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step4),
          Text(
            messages.goalReportSectionNext,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
          // A list, because that is what it is. Run together as prose, the
          // actions were the part of the report most likely to be skimmed
          // past — which is the opposite of what an action is for.
          for (final action in actions)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.step1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step1),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: IconSizes.s,
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step1),
                  Expanded(
                    child: AgentMarkdownView(
                      action,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
