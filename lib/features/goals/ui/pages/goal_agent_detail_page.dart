import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_automation_row.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart'
    show WakeRunCompletion;
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/features/goals/service/goal_habit_completion_service.dart';
import 'package:lotti/features/goals/service/goal_health_refresh_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_chat_controller.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_composer.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkins_card.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';
import 'package:lotti/features/goals/ui/goal_agent_lifetime_pills.dart';
import 'package:lotti/features/goals/ui/goal_assessment_widgets.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';
import 'package:lotti/features/goals/ui/goal_health_direction.dart';
import 'package:lotti/features/goals/ui/goal_log_today_sheet.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/features/goals/ui/goal_routes.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_status.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habits_chart_card.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_dock.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_exposure_tracker.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/expandable_report_section.dart'
    show formatCountdown;
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// One goal — the §4b dashboard: header (name · unified status pill ·
/// trend), the hero stack (the timestamped Agent's-read card above the
/// deterministic Goal-days card, each at the full content width), active
/// banners and pending proposals, then the Habits and Signals evidence
/// sections — with the cost pills and automation controls riding the read
/// card itself.
/// Daily reflections live in the check-ins rail rather than the main
/// column, and the retired-banner timeline is gone — the rail is the one
/// place "what I've said about this goal" is read. Desktop hosts the
/// durable conversation as a non-modal right-overlay drawer; mobile opens
/// the same projection as a pushed page.
class GoalAgentDetailPage extends ConsumerStatefulWidget {
  const GoalAgentDetailPage({required this.agentId, super.key});

  final String agentId;

  @override
  ConsumerState<GoalAgentDetailPage> createState() =>
      _GoalAgentDetailPageState();
}

class _GoalAgentDetailPageState extends ConsumerState<GoalAgentDetailPage>
    with GoalHealthRefreshOnEntry {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _appBarTitleVisible = ValueNotifier<bool>(false);
  final GlobalKey _progressSectionKey = GlobalKey();
  final GlobalKey _headerKey = GlobalKey();
  GoalProgressView? _lastProgress;
  String? _lastProgressSpecId;
  int? _lastProgressSpanDays;
  int? _rangeRecoveryRequestedFor;

  /// Whether the user has explicitly chosen a range on this page. Until they
  /// do, the page runs in AUTO mode: the shared span is driven to the number
  /// of days that exactly fits the content width at the authored day-cell
  /// density — the default fills the card with days instead of leaving dead
  /// space, without stretching cells or gutters, and without a scroller.
  bool _rangePicked = false;

  /// The fitted span already requested, so auto mode issues one controller
  /// write per computed value rather than one per rebuild.
  int? _autoSpanRequestedFor;

  /// AUTO span: drives the shared range to the number of day columns that
  /// fit the content column at the authored pitch, from the PANE's measured
  /// width (the body [LayoutBuilder]'s constraint — the window width lied
  /// whenever a navigation sidebar or the check-in rail narrowed the pane).
  ///
  /// Called from layout, so the controller write is deferred past the frame;
  /// idempotent per computed value, and a no-op once the user has picked a
  /// preset.
  void _scheduleAutoSpan(
    BuildContext context, {
    required double paneWidth,
    required bool railShown,
  }) {
    if (_rangePicked) return;
    final tokens = context.designTokens;
    final pitch = goalDayTrackMetrics(context, dayCount: 1).pitch;
    final contentWidth =
        math.min(
          kUnifiedGoalsContentMaxWidth,
          paneWidth -
              (railShown ? kGoalTimelineRailWidth : 0) -
              tokens.spacing.step6 * 2,
        ) -
        tokens.spacing.cardPadding * 2;
    final fit = pitch <= 0 || contentWidth <= pitch
        ? 7
        : (contentWidth / pitch).floor().clamp(7, 90);
    if (_autoSpanRequestedFor == fit) return;
    _autoSpanRequestedFor = fit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _rangePicked) return;
      if (ref.read(habitsControllerProvider).timeSpanDays != fit) {
        ref.read(habitsControllerProvider.notifier).setTimeSpan(fit);
      }
    });
  }

  /// Whether the desktop chat drawer is open. The drawer stays MOUNTED
  /// either way (a slid-out overlay, not a conditional subtree), so the
  /// composer draft survives closing it.
  bool _chatOpen = false;

  /// One scroll group for every extended day track — goal strip, habit
  /// rows, signal bars — so a span longer than the viewport scrolls in
  /// unison and the same date stays aligned down the page.
  final LinkedScrollGroup _trackScrollGroup = LinkedScrollGroup();

  /// Focused when the drawer opens, so the Esc shortcut has a focus path
  /// even before the user clicks into the composer — CallbackShortcuts only
  /// sees keys travelling up from a focused descendant.
  final FocusNode _drawerFocusNode = FocusNode(
    debugLabel: 'goal-chat-drawer',
    skipTraversal: true,
  );

  void _setChatOpen({required bool open}) {
    setState(() => _chatOpen = open);
    if (open) {
      // Post-frame: while closed the node sits inside ExcludeFocus, and a
      // same-tick request is denied before the rebuild lifts the exclusion.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _chatOpen) _drawerFocusNode.requestFocus();
      });
    }
  }

  /// One tap-region group for the drawer and every control that opens it:
  /// a tap on the Talk-to button or the Ask-why link must not first count
  /// as "outside the drawer" and close what it is about to open.
  static const Object _chatRegionGroup = 'goal-detail-chat-drawer';

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
    _drawerFocusNode.dispose();
    _trackScrollGroup.dispose();
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
  /// Opens a day's reflection sheet.
  ///
  /// Shared by the day strip and the check-in timeline: a reflection beat has
  /// to reopen exactly what the strip does, and two call sites building the
  /// same sheet is how they stop agreeing.
  void _openReflection({
    required GoalSpecVersionEntity spec,
    required GoalProgressView progress,
    required List<GoalAssessmentRecord> assessments,
    required DateTime day,
  }) => showGoalDayAssessmentSheet(
    context,
    agentId: agentId,
    spec: spec,
    progress: progress,
    assessments: assessments,
    day: day,
  );

  /// Opens the anytime check-in composer.
  ///
  /// The ever-present affordance: reachable from the app bar, the check-ins
  /// header and any banner whose CTA asks for one, so "say what is going on"
  /// is never more than one tap away.
  void _openCheckInComposer({
    required String goalTitle,
    String? personaName,
    String? categoryId,
    String? preparedLine,
  }) {
    GoalCheckInComposer.show(
      context,
      agentId: agentId,
      goalTitle: goalTitle,
      personaName: personaName,
      categoryId: categoryId,
      preparedLine: preparedLine,
    );
  }

  void _logToday(GoalProgressView progress) {
    if (progress.habits.isEmpty) {
      _scrollToProgress();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // A scroll-controlled sheet can reach the top of the screen, and
      // `showModalBottomSheet` strips the top padding from its own subtree —
      // so an inner SafeArea sees nothing and the sheet's first line lands
      // under the status bar clock.
      useSafeArea: true,
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

  /// §4b's Ask-why: the conversation arrives pre-filled with the current
  /// computed state, so the agent is asked about the exact verdict on
  /// screen. An existing draft is never clobbered — the prefill only fills
  /// an empty composer.
  void _askWhy(UnifiedGoalStatus status) {
    final draft = ref.read(goalChatControllerProvider(agentId)).draft;
    if (draft.trim().isEmpty) {
      ref
          .read(goalChatControllerProvider(agentId).notifier)
          .updateDraft(
            context.messages.goalChatWhyPrefill(
              unifiedGoalStatusLabel(context.messages, status),
            ),
          );
    }
    if (isDesktopLayout(context)) {
      _setChatOpen(open: true);
    } else {
      beamToNamed(goalChatPath(agentId));
    }
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
    // return to the Goals root instead of pinning this child.
    final backToList = BackButton(
      onPressed: () => beamToNamed(goalsRootPath),
    );
    Widget popSafe(Widget child) => PopScope(
      // canPop stays TRUE: false would disable the iOS swipe-back
      // gesture entirely. The route pops normally; the completed pop
      // then persists the surface root through NavService.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Post-frame: the pop is mid-router-update — persisting the root
        // synchronously would re-enter the delegate while it notifies.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => beamToNamed(goalsRootPath),
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
    // Opening a goal pulls the health signals it watches forward, so the
    // cards are never a day behind the phone's health store.
    refreshHealthSignals([?spec?.criteria]);
    // The page's ONE time range: the same shared span the completion chart
    // reads, applied to every day track so any date lines up vertically
    // down the page.
    final timeSpanDays = ref.watch(
      habitsControllerProvider.select((state) => state.timeSpanDays),
    );
    // AUTO span: until the user picks a range here, [_scheduleAutoSpan]
    // (called from the body's LayoutBuilders, where the PANE width is known)
    // drives the shared span to the day count that fits the content width —
    // the completion chart, the heatmap data and every day track then follow
    // the same fitted span, so the page keeps its one-range contract in auto
    // mode too.
    final progressAsync = spec == null
        ? null
        : ref.watch(
            goalAgentProgressViewForSpanProvider((
              agentId: agentId,
              historyDays: timeSpanDays,
            )),
          );
    final progressSettled =
        progressAsync != null &&
        progressAsync.hasValue &&
        !progressAsync.isLoading &&
        !progressAsync.hasError;
    if (spec == null) {
      _lastProgress = null;
      _lastProgressSpecId = null;
      _lastProgressSpanDays = null;
    } else if (progressSettled) {
      _lastProgress = progressAsync.value;
      _lastProgressSpecId = spec.id;
      _lastProgressSpanDays = timeSpanDays;
    }
    final cacheMatchesSpec = spec != null && _lastProgressSpecId == spec.id;
    // A range change selects a different provider-family key. Keep the last
    // settled projection in place while that key loads so 14d → 30d → 90d
    // behaves as stale-while-revalidate instead of blanking the dashboard. If
    // the replacement fails, snap the shared selector back to the last span;
    // never leave old evidence under a new range label.
    final rangeFailed =
        (progressAsync?.hasError ?? false) &&
        !(progressAsync?.hasValue ?? false);
    final fallbackSpanDays = cacheMatchesSpec ? _lastProgressSpanDays : null;
    if (rangeFailed &&
        fallbackSpanDays != null &&
        fallbackSpanDays != timeSpanDays &&
        _rangeRecoveryRequestedFor != timeSpanDays) {
      _rangeRecoveryRequestedFor = timeSpanDays;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(habitsControllerProvider.notifier)
            .setTimeSpan(fallbackSpanDays);
      });
    } else if (!rangeFailed) {
      _rangeRecoveryRequestedFor = null;
    }
    final progress = progressSettled
        ? progressAsync.value
        : cacheMatchesSpec
        ? _lastProgress
        : null;
    final renderedTimeSpanDays = rangeFailed && fallbackSpanDays != null
        ? fallbackSpanDays
        : timeSpanDays;
    final assessments =
        ref.watch(goalAssessmentHistoryProvider(agentId)).value ?? const [];
    // Same render-time staleness contract as the strip: retained data
    // from a failed deadline reload keeps fresh banners (no-flash) but
    // never expired copy — whose tracker would keep counting exposure.
    final locallySnoozed = ref.watch(locallySnoozedNudgeDeadlinesProvider);
    // Unlike the shell dock, this page applies NO snooze filter: snoozing
    // quiets the rotating bar, but the goal's own page always shows the
    // current banner — captioned with when it returns to the bar, so the
    // banner never just vanishes without explanation.
    final nudges = [
      for (final entry
          in ref.watch(activeGoalNudgesProvider).value ??
              const <NudgeBannerEntry>[])
        if (entry.nudge.agentId == agentId &&
            (entry.nudge.staleAt == null ||
                clock.now().isBefore(entry.nudge.staleAt!)))
          (
            entry: entry,
            shellHiddenUntil: nudgeBannerShellHiddenUntil(
              entry,
              locallySnoozedDeadlines: locallySnoozed,
            ),
          ),
    ];
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
    final hasStandingAssessment =
        (latestReport?.tldr?.trim().isNotEmpty ?? false) ||
        latestReport?.content.trim().isNotEmpty == true ||
        (health?.reportOneLiner?.trim().isNotEmpty ?? false);
    final unifiedStatus = healthAsync.hasValue
        ? unifiedGoalStatusOf(health?.trackStatus)
        : null;
    final desktopLayout = isDesktopLayout(context);
    final goalTitle = spec?.title ?? goalIdentity.displayName;
    // The rail is a property of the available PANE width, not the window's:
    // the goals tab sits behind a navigation sidebar whose width varies, so
    // measuring the window let the rail appear on a 1280px window whose actual
    // content pane was only 780px — squeezing the dashboard into a sliver. The
    // pane width is measured at the layout site below, the way the chat
    // drawer's fold guard already does it; this is only the "is a rail
    // possible at all" half.
    bool railFits(double paneWidth) =>
        desktopLayout &&
        paneWidth >= kGoalTimelineRailFoldWidth + kGoalTimelineRailWidth;

    void openComposer() => _openCheckInComposer(
      goalTitle: goalTitle,
      personaName: goalIdentity.displayName,
      categoryId: spec == null
          ? null
          : goalIdentity.allowedCategoryIds.firstOrNull,
      preparedLine: latestReport?.tldr,
    );

    Widget checkInsCard({int? maxBeats}) => GoalCheckInsCard(
      agentId: agentId,
      maxBeats: maxBeats,
      onCreate: isActive ? openComposer : null,
      onSeeAll: maxBeats == null
          ? null
          : () => beamToNamed(goalTimelinePath(agentId)),
      onOpenReflection: !(isActive && spec != null && progress != null)
          ? null
          : (day) => _openReflection(
              spec: spec,
              progress: progress,
              assessments: assessments,
              day: day,
            ),
    );

    Widget detailList({
      required bool showChatAction,
      double? contentMaxWidth,
      bool showRail = false,
    }) {
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
            (agentState is AgentStateEntity ? agentState : null)
                ?.isReportStale ??
            false,
        // Ask-why needs a DISPLAYED verdict to ask about AND a read to
        // question (§4b ties it to the narrative card). "No data" never
        // qualifies: beside a standing assessment the page suppresses that
        // pill as self-contradictory, and a prefill quoting the suppressed
        // verdict would resurrect the contradiction in the composer.
        onAskWhy:
            unifiedStatus != null &&
                unifiedStatus != UnifiedGoalStatus.noData &&
                hasStandingAssessment &&
                isActive
            ? () => _askWhy(unifiedStatus)
            : null,
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
            // The mic is the feature's ever-present doorway: on a phone the
            // check-ins card can be below the fold, so "say what is going on"
            // must not depend on scrolling to it.
            if (isActive)
              IconButton(
                key: const ValueKey('goal-detail-checkin-action'),
                // The LIVE mic glyph, not `micIdle`: that token resolves to
                // Lucide's slashed mic-off, which on an enabled action reads
                // as "recording unavailable". This button starts a check-in
                // recording; nothing about it is muted.
                icon: const Icon(LottiIcons.mic),
                tooltip: context.messages.goalCheckInRecordCta,
                onPressed: openComposer,
              ),
            if (!desktop && chatAvailable)
              IconButton(
                key: const ValueKey('goal-detail-chat-action'),
                icon: const Icon(LottiIcons.chat),
                tooltip: context.messages.goalChatTalkToAgent,
                onPressed: () => beamToNamed(goalChatPath(agentId)),
              ),
            // Desktop: the drawer's named doorway (§4b header). In the
            // drawer's tap-region group so opening it never first registers
            // as an outside tap that closes it.
            if (desktop && chatAvailable)
              TapRegion(
                groupId: _chatRegionGroup,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: tokens.spacing.step2,
                  ),
                  // Goal names are user-written and unbounded; capped so a
                  // long persona name ellipsizes inside the button instead
                  // of overflowing the toolbar. The tooltip keeps the full
                  // name reachable.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: tokens.spacing.step13,
                    ),
                    child: Tooltip(
                      message: context.messages.goalChatTalkToAgent,
                      child: DesignSystemButton(
                        key: const ValueKey('goal-detail-talk-to'),
                        label: context.messages.goalChatTalkToAgent,
                        leadingIcon: LottiIcons.chat,
                        variant: DesignSystemButtonVariant.secondary,
                        size: DesignSystemButtonSize.dense,
                        onPressed: () => _setChatOpen(open: !_chatOpen),
                      ),
                    ),
                  ),
                ),
              ),
            _GoalActionsMenuButton(
              agentId: agentId,
              agentName: goalIdentity.displayName,
              canEdit: isActive && spec != null,
              onUpdateRead: isActive
                  ? () => ref
                        .read(goalHabitCompletionServiceProvider)
                        .requestReportRefresh(agentId)
                  : null,
              // The switch the AI card's compact footer no longer carries: a
              // set-once preference belongs behind the kebab, not on the hero
              // card the user re-reads daily.
              automaticUpdatesEnabled: isActive
                  ? GoalAgentService.automaticUpdatesEnabled(goalIdentity)
                  : null,
            ),
          ],
        ),
        body: SafeArea(
          child: !desktop || !chatAvailable
              // The desktop reading measure is a property of the pane, not of
              // chat: a dormant goal (no chat) must not stretch its cards
              // across the whole window.
              // The no-chat path measures its pane too: a dormant goal on a
              // wide desktop still earns the rail, and a narrow pane behind a
              // wide sidebar still must not get one.
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    _scheduleAutoSpan(
                      context,
                      paneWidth: constraints.maxWidth,
                      railShown: railFits(constraints.maxWidth),
                    );
                    return railFits(constraints.maxWidth)
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: detailList(
                                  showChatAction: false,
                                  contentMaxWidth: kUnifiedGoalsContentMaxWidth,
                                  showRail: true,
                                ),
                              ),
                              SizedBox(
                                width: kGoalTimelineRailWidth,
                                child: _CheckInRail(card: checkInsCard()),
                              ),
                            ],
                          )
                        : detailList(
                            showChatAction: !desktop && chatAvailable,
                            contentMaxWidth: desktop
                                ? kUnifiedGoalsContentMaxWidth
                                : null,
                          );
                  },
                )
              : CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): () {
                      if (_chatOpen) setState(() => _chatOpen = false);
                    },
                  },
                  // §4b: the dashboard is the page; conversation is a
                  // non-modal overlay drawer that slides over it without
                  // reflow. The drawer stays mounted while closed so its
                  // draft survives, and it takes no pointer/focus traffic
                  // off-screen.
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _scheduleAutoSpan(
                        context,
                        paneWidth: constraints.maxWidth,
                        railShown: railFits(constraints.maxWidth),
                      );
                      return Stack(
                        children: [
                          // The drawer overlays without reflowing the cards, but
                          // the COLUMN glides: closed, it centers in the window
                          // (a fixed left-aligned measure left the right half of
                          // wide windows dead); open, it centers in what the
                          // drawer leaves free. Clamped to the PANE's real
                          // constraints: with a wide navigation sidebar the pane
                          // can be barely wider than the drawer, and always
                          // subtracting the drawer span would squeeze the
                          // dashboard into an unusable sliver — below the fold
                          // width the drawer stays a true overlay instead.
                          AnimatedPadding(
                            duration: MotionDurations.medium2,
                            curve: MotionCurves.emphasizedDecelerate,
                            padding: EdgeInsetsDirectional.only(
                              end:
                                  _chatOpen &&
                                      constraints.maxWidth -
                                              kGoalChatDrawerWidth >=
                                          kPageHeaderFoldWidth
                                  ? kGoalChatDrawerWidth
                                  : 0,
                            ),
                            // Two columns, and the drawer still overlays rather
                            // than becoming a third: a conversation is transient
                            // and already owns correct focus, escape and
                            // semantics behaviour as an overlay. The glide moves
                            // BOTH columns.
                            child: railFits(constraints.maxWidth)
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: detailList(
                                          showChatAction: false,
                                          contentMaxWidth:
                                              kUnifiedGoalsContentMaxWidth,
                                          showRail: true,
                                        ),
                                      ),
                                      SizedBox(
                                        width: kGoalTimelineRailWidth,
                                        child: _CheckInRail(
                                          card: checkInsCard(),
                                        ),
                                      ),
                                    ],
                                  )
                                : detailList(
                                    showChatAction: false,
                                    contentMaxWidth:
                                        kUnifiedGoalsContentMaxWidth,
                                  ),
                          ),
                          PositionedDirectional(
                            top: 0,
                            bottom: 0,
                            end: 0,
                            child: TapRegion(
                              groupId: _chatRegionGroup,
                              onTapOutside: (_) {
                                if (_chatOpen) {
                                  setState(() => _chatOpen = false);
                                }
                              },
                              child: AnimatedSlide(
                                offset: _chatOpen
                                    ? Offset.zero
                                    : const Offset(1, 0),
                                duration: MotionDurations.medium2,
                                curve: MotionCurves.emphasizedDecelerate,
                                child: IgnorePointer(
                                  ignoring: !_chatOpen,
                                  // Off-screen means out of the semantics tree
                                  // too: without this a screen reader traverses
                                  // the slid-away drawer's composer and close
                                  // button.
                                  child: ExcludeSemantics(
                                    excluding: !_chatOpen,
                                    child: ExcludeFocus(
                                      excluding: !_chatOpen,
                                      child: Focus(
                                        focusNode: _drawerFocusNode,
                                        child: _GoalChatDrawer(
                                          agentId: agentId,
                                          identity: goalIdentity,
                                          status: unifiedStatus,
                                          hasStandingAssessment:
                                              hasStandingAssessment,
                                          recoveryHint:
                                              switch (health?.deficit) {
                                                final int deficit
                                                    when deficit > 0 =>
                                                  context.messages
                                                      .goalDaysToRecover(
                                                        deficit,
                                                      ),
                                                _ => null,
                                              },
                                          onClose: () =>
                                              setState(() => _chatOpen = false),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

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
    required this.onAskWhy,
  });

  final String agentId;
  final AgentIdentityEntity identity;
  final AgentStateEntity? agentState;
  final bool canRefresh;
  final AsyncValue<GoalAgentHealth> healthAsync;
  final AgentReportEntity? report;
  final bool isStale;
  final VoidCallback? onAskWhy;

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
    final age = clock.now().difference(generatedAt);
    final Duration untilNextBucket;
    if (age.inHours < 1) {
      untilNextBucket = Duration(seconds: 60 - (age.inSeconds % 60) + 1);
    } else if (age.inDays < 1) {
      untilNextBucket = Duration(seconds: 3600 - (age.inSeconds % 3600) + 1);
    } else {
      untilNextBucket = Duration(seconds: 86400 - (age.inSeconds % 86400) + 1);
    }
    _ageTick = Timer(untilNextBucket, () {
      if (mounted) setState(() {});
    });
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
    final String? freshness;
    if (widget.isStale && hasReadContent) {
      freshness = messages.taskAgentStatusOutOfDate;
      _ageTick?.cancel();
    } else if (generatedAt == null) {
      freshness = null;
      _ageTick?.cancel();
    } else {
      freshness = messages.goalDetailReadAsOf(
        _relativeAgo(messages, clock.now().difference(generatedAt)),
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
              playbackControl: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GoalAgentLifetimePills(agentId: widget.agentId, inline: true),
                  if (freshness != null) ...[
                    SizedBox(width: tokens.spacing.step3),
                    Text(
                      freshness,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: widget.isStale && hasReadContent
                            ? tokens.colors.alert.warning.ink
                            : tokens.colors.aiCard.metaText,
                      ),
                    ),
                  ],
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
                    // Both text actions share ONE line under the summary:
                    // "read the rest of it" and "argue with it" are the two
                    // things a reader does next, and a row apiece cost the
                    // card two rows to say so.
                    onAskWhy: widget.onAskWhy,
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

/// "as of …" bucketing for the read's generation timestamp. Reuses the
/// generic relative-age catalog entries (minute/hour/day granularity) so no
/// parallel vocabulary drifts per language.
String _relativeAgo(AppLocalizations messages, Duration age) {
  if (age.inMinutes < 1) return messages.conflictBannerAgoJustNow;
  if (age.inHours < 1) return messages.conflictBannerAgoMinutes(age.inMinutes);
  if (age.inDays < 1) return messages.conflictBannerAgoHours(age.inHours);
  return messages.conflictBannerAgoDays(age.inDays);
}

/// The §4b "About this agent" expander: the plumbing — lifetime cost pills
/// and the automatic-updates controls — folded behind one quiet row at the
/// foot of the dashboard, so what the agent SAYS outranks how it is kept
/// fresh everywhere above the fold.
class _GoalReportCard extends StatefulWidget {
  const _GoalReportCard({
    required this.report,
    required this.fallback,
    required this.fallbackMuted,
    required this.onAskWhy,
  });

  final AgentReportEntity? report;
  final String fallback;
  final bool fallbackMuted;

  /// Opens the chat with the read's verdict pre-quoted. Rides the same row as
  /// Show more; null while the goal has no conversation to open.
  final VoidCallback? onAskWhy;

  @override
  State<_GoalReportCard> createState() => _GoalReportCardState();
}

class _GoalReportCardState extends State<_GoalReportCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  /// Matches the task-details agent section: the body eases open rather than
  /// appearing, so the card reads as one surface revealing more of itself.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: MotionDurations.medium2,
  );
  late final Animation<double> _revealCurve = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

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
    final sections = _sectionsOf(report);
    // A renderable sections payload is expandable even when the flat text
    // happens to equal the TLDR: without this the toggle vanished and the
    // sections became unreachable.
    final expandable =
        hasTldr && (sections != null || (hasContent && content != tldr));
    final primary = hasTldr
        ? tldr
        : hasContent
        ? content
        : widget.fallback;

    // No card wrapper of its own: this body renders INSIDE the
    // Agent's-read hero card, which owns the surface, title and freshness
    // caption.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selectable, like the task-details agent section: a standing
        // report carries exact readings a user may well want to copy.
        SelectionArea(
          child: AgentMarkdownView(
            primary,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: report == null && widget.fallbackMuted
                  ? tokens.colors.text.lowEmphasis
                  : tokens.colors.text.highEmphasis,
            ),
          ),
        ),
        // The actions sit with the summary, not behind Show more. Inside
        // the expanded body they were reachable only by a tap most readers
        // never make — the one part of a standing report that asks
        // something of you, gated behind the part that only informs.
        if (_actionsOf(sections) case final actions?) ...[
          SizedBox(height: tokens.spacing.step3),
          SelectionArea(
            child: AgentMarkdownView(
              [for (final action in actions) '- $action'].join('\n'),
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        ],
        if (expandable)
          AnimatedBuilder(
            animation: _revealCurve,
            builder: (context, child) => _revealCurve.value == 0
                ? const SizedBox.shrink()
                : ClipRect(
                    child: Align(
                      alignment: Alignment.topLeft,
                      heightFactor: _revealCurve.value,
                      child: child,
                    ),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: tokens.spacing.step3),
                // Sections when the report carries them, the flat text when
                // it does not. The sentences are model-authored in the
                // user's own language, so the composer cannot wrap them in
                // headings without injecting English — the headings are
                // added here instead, which also means they follow the app
                // language rather than whichever one the report was
                // written in.
                SelectionArea(
                  child: sections != null
                      ? _GoalReportSections(sections: sections)
                      // Non-null by construction: with no sections,
                      // `expandable` is only true when there IS content.
                      : AgentMarkdownView(
                          content!,
                          style: tokens.typography.styles.body.bodySmall
                              .copyWith(
                                color: tokens.colors.text.highEmphasis,
                              ),
                        ),
                ),
              ],
            ),
          ),
        // One caption-tier action row, not one row per action. No hover
        // fill on either: a pill fading in mid-paragraph reads as a phantom
        // button — the accent ink already says these are actions, and it
        // still brightens under the pointer.
        if (expandable || widget.onAskWhy != null) ...[
          SizedBox(height: tokens.spacing.step1),
          Row(
            children: [
              if (expandable)
                DesignSystemButton(
                  label: _expanded
                      ? context.messages.aiResponseShowLess
                      : context.messages.aiResponseShowMore,
                  onPressed: _toggle,
                  variant: DesignSystemButtonVariant.tertiary,
                  size: DesignSystemButtonSize.dense,
                  trailingIcon: _expanded
                      ? LottiIcons.collapse
                      : LottiIcons.expand,
                  alignsLabelToLeadingEdge: true,
                  suppressHoverFill: true,
                ),
              if (widget.onAskWhy case final askWhy?)
                DesignSystemButton(
                  key: const ValueKey('goal-detail-ask-why'),
                  label: context.messages.goalDetailAskWhy,
                  onPressed: askWhy,
                  variant: DesignSystemButtonVariant.tertiary,
                  size: DesignSystemButtonSize.dense,
                  trailingIcon: LottiIcons.forward,
                  // Only the FIRST action on the row pulls onto the card's
                  // leading rail; a second pull would drag it back over the
                  // gap it just left.
                  alignsLabelToLeadingEdge: !expandable,
                  suppressHoverFill: true,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

enum _GoalDetailMenuAction {
  edit,
  updateRead,
  automaticUpdates,
  internals,
  delete,
}

class _GoalActionsMenuButton extends ConsumerWidget {
  const _GoalActionsMenuButton({
    required this.agentId,
    required this.agentName,
    required this.canEdit,
    required this.onUpdateRead,
    required this.automaticUpdatesEnabled,
  });

  final String agentId;
  final String agentName;
  final bool canEdit;

  /// Requests a report refresh (§4b overflow: "Update read"); null while
  /// the goal is not active.
  final VoidCallback? onUpdateRead;

  /// Current automatic-updates preference, or null while the goal is not
  /// active (the item is then omitted). The AI card's footer deliberately
  /// carries only freshness + the manual trigger; this menu is where the
  /// standing preference lives.
  final bool? automaticUpdatesEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final danger = tokens.colors.alert.error.ink;
    return PopupMenuButton<_GoalDetailMenuAction>(
      icon: const Icon(LottiIcons.moreVertical),
      onSelected: (action) async {
        switch (action) {
          case _GoalDetailMenuAction.edit:
            beamToNamed(goalEditPath(agentId));
          case _GoalDetailMenuAction.updateRead:
            onUpdateRead?.call();
          case _GoalDetailMenuAction.automaticUpdates:
            final enabled = automaticUpdatesEnabled;
            if (enabled != null) {
              try {
                await ref
                    .read(goalAgentServiceProvider)
                    .updateAutomaticUpdates(
                      agentId: agentId,
                      enabled: !enabled,
                    );
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.maybeOf(context)
                  ?..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(context.messages.saveFailedRetry)),
                  );
              }
            }
          case _GoalDetailMenuAction.internals:
            Navigator.of(context).push(
              AgentInternalsPanel.route(
                context: context,
                agentId: agentId,
                agentName: agentName,
              ),
            );
          case _GoalDetailMenuAction.delete:
            await _confirmAndDelete(context, ref);
        }
      },
      itemBuilder: (context) => [
        if (canEdit)
          PopupMenuItem<_GoalDetailMenuAction>(
            value: _GoalDetailMenuAction.edit,
            child: Row(
              children: [
                const Icon(LottiIcons.edit),
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
        if (onUpdateRead != null)
          PopupMenuItem<_GoalDetailMenuAction>(
            value: _GoalDetailMenuAction.updateRead,
            child: Row(
              children: [
                const Icon(LottiIcons.refresh),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    context.messages.taskAgentUpdateNow,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (automaticUpdatesEnabled != null)
          CheckedPopupMenuItem<_GoalDetailMenuAction>(
            value: _GoalDetailMenuAction.automaticUpdates,
            checked: automaticUpdatesEnabled!,
            child: Text(
              context.messages.taskAgentAutomaticUpdatesLabel,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        PopupMenuItem<_GoalDetailMenuAction>(
          value: _GoalDetailMenuAction.internals,
          child: Row(
            children: [
              const Icon(LottiIcons.tune),
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
              Icon(LottiIcons.delete, color: danger),
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
        beamToNamed(goalsRootPath);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.messages.saveFailedRetry)),
          );
      }
    }
  }
}

/// The report's current actions, or null when it has none.
///
/// Read by the card directly so they can sit with the summary rather than
/// inside the expandable body: an action reachable only behind "Show more"
/// is an action most readers never see.
List<String>? _actionsOf(Map<String, Object?>? sections) {
  if (sections == null) return null;
  final actions = <String>[
    if (sections[GoalReportSectionKeys.nextActions] case final List<Object?> a)
      for (final item in a)
        if (item case final String text when text.trim().isNotEmpty)
          text.trim(),
  ];
  return actions.isEmpty ? null : actions;
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
  // A payload has to RENDER something to count as a sectioned report. A map
  // of blanks — or one carrying only keys this build does not know — passed
  // the old non-empty check and won the branch, so the card opened on zero
  // headings and zero actions while `content` still held the real text.
  //
  // Only recognized keys count, for the same reason.
  var renderable = false;
  for (final key in const [
    GoalReportSectionKeys.currentPeriod,
    GoalReportSectionKeys.rollingWindow,
    GoalReportSectionKeys.latestChange,
    GoalReportSectionKeys.coverage,
  ]) {
    if (sections[key] case final String text when text.trim().isNotEmpty) {
      renderable = true;
    }
  }
  if (sections[GoalReportSectionKeys.nextActions] case final List<Object?> a) {
    if (a.any((item) => item is String && item.trim().isNotEmpty)) {
      renderable = true;
    }
  }
  return renderable ? sections : null;
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
          // One step below the TLDR above them. Set at bodyMedium the section
          // bodies were LARGER than the subtitle2 headings labelling them —
          // an inverted ramp — and identical to the summary they expand on,
          // which made the summary read as a duplicated first paragraph.
          AgentMarkdownView(
            body,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ],
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

/// The desktop check-in rail: its own scroll axis beside the dashboard, so a
/// long history never drags the cards with it.
class _CheckInRail extends StatelessWidget {
  const _CheckInRail({required this.card});

  final Widget card;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        0,
        tokens.spacing.step5,
        tokens.spacing.step6,
        tokens.spacing.step5,
      ),
      child: card,
    );
  }
}
