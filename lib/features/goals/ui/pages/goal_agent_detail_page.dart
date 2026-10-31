import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_automation_row.dart';
import 'package:lotti/features/agents/ui/agent_chat_button.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/agent_menu_items.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_report_layout.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_stage_page.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/summary_read_aloud_button.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart'
    show WakeRunCompletion;
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/features/goals/service/goal_habit_completion_service.dart';
import 'package:lotti/features/goals/service/goal_health_refresh_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/charter/goal_charter_card.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_composer.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkins_card.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';
import 'package:lotti/features/goals/ui/goal_agent_lifetime_pills.dart';
import 'package:lotti/features/goals/ui/goal_assessment_widgets.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';
import 'package:lotti/features/goals/ui/goal_health_direction.dart';
import 'package:lotti/features/goals/ui/goal_log_today_sheet.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
import 'package:lotti/features/goals/ui/knowledge/goal_knowledge_section.dart';
import 'package:lotti/features/goals/ui/unified/goal_companion.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_status.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habits_chart_card.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_dock.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_exposure_tracker.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_widgets.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/ui/playback_failure_toast.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/goal_routes.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:lotti/widgets/day_indicators/day_track.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:lotti/widgets/misc/linked_scroll_group.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:lotti/widgets/modal/side_sheet.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';

part 'goal_agent_detail_page_cards_part.dart';
part 'goal_agent_detail_page_detail_list_part.dart';
part 'goal_agent_detail_page_report_part.dart';

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
    final pitch = dayTrackMetrics(context).pitch;
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

  /// What the desktop chat sheet's header shows, published by every build of
  /// this page. The sheet lives on its own route and does not rebuild with
  /// the page, so it listens here — its status pill and the page's can never
  /// disagree, even when a report lands while the conversation is open.
  final ValueNotifier<_GoalChatHeader?> _chatHeader = ValueNotifier(null);

  /// One scroll group for every extended day track — goal strip, habit
  /// rows, signal bars — so a span longer than the viewport scrolls in
  /// unison and the same date stays aligned down the page.
  final LinkedScrollGroup _trackScrollGroup = LinkedScrollGroup();

  /// Desktop's conversation: the shared side sheet, sliding in over the
  /// dimmed dashboard (which never reflows around it). The draft lives in the
  /// keep-alive chat controller, so closing the sheet loses nothing.
  void _openChat() => showSideSheetPane<void>(
    context: context,
    sideSheet: kAgentChatSideSheet,
    builder: (sheetContext) => ValueListenableBuilder<_GoalChatHeader?>(
      valueListenable: _chatHeader,
      builder: (context, header, _) => header == null
          ? const SizedBox.shrink()
          : _GoalChatDrawer(
              agentId: agentId,
              header: header,
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
    ),
  );

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
    _chatHeader.dispose();
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

  /// Opens the one-tap capture sheet for [progress]'s habits. The banner CTA
  /// only calls this when there is at least one habit to tick off.
  void _logToday(GoalProgressView progress) {
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

    final inputs = (
      tokens: tokens,
      healthAsync: healthAsync,
      agentState: agentState,
      goalIdentity: goalIdentity,
      isActive: isActive,
      health: health,
      spec: spec,
      rangeFailed: rangeFailed,
      progress: progress,
      renderedTimeSpanDays: renderedTimeSpanDays,
      assessments: assessments,
      nudges: nudges,
      hasStandingAssessment: hasStandingAssessment,
      latestReport: latestReport,
      openComposer: openComposer,
      checkInsCard: checkInsCard,
    );

    final desktop = isDesktopLayout(context);
    final chatAvailable = isActive;

    final chatHeader = (
      identity: goalIdentity,
      status: unifiedStatus,
      hasStandingAssessment: hasStandingAssessment,
      recoveryHint: switch (health?.deficit) {
        final int deficit when deficit > 0 =>
          context.messages.goalDaysToRecover(
            deficit,
          ),
        _ => null,
      },
    );
    if (_chatHeader.value != chatHeader) {
      // After the frame: the sheet listening to it is another route, and
      // notifying it mid-build would rebuild it during this build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _chatHeader.value = chatHeader;
      });
    }

    Widget dashboard(double paneWidth) {
      return railFits(paneWidth)
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _detailList(
                    context,
                    inputs,
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
          : _detailList(
              context,
              inputs,
              showChatAction: !desktop && chatAvailable,
              contentMaxWidth: desktop ? kUnifiedGoalsContentMaxWidth : null,
            );
    }

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
                // The sparkle, as on the desktop button and the person
                // page: it means "the agent" everywhere in the app.
                icon: const Icon(LottiIcons.aiSpark),
                tooltip: context.messages.goalChatTalkToAgent,
                onPressed: () => beamToNamed(goalChatPath(agentId)),
              ),
            // Desktop: the conversation's named doorway (§4b header).
            if (desktop && chatAvailable)
              Padding(
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
                  child: AgentChatButton(
                    key: const ValueKey('goal-detail-talk-to'),
                    onPressed: _openChat,
                  ),
                ),
              ),
            _GoalActionsMenuButton(
              agentId: agentId,
              agentName: goalIdentity.displayName,
              // Editing rebuilds the criteria from what this build decoded;
              // an unknown kind decoded as its id alone (ADR 0145).
              canEdit:
                  isActive &&
                  spec != null &&
                  !goalCriterionHasUnsupported(spec.criteria),
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
          // The desktop reading measure is a property of the pane, not of
          // chat: a dormant goal must not stretch its cards across the whole
          // window, and a narrow pane behind a wide sidebar must not get the
          // rail. The conversation never takes a column of its own — it
          // slides in over the page as a side sheet.
          child: LayoutBuilder(
            builder: (context, constraints) {
              _scheduleAutoSpan(
                context,
                paneWidth: constraints.maxWidth,
                railShown: railFits(constraints.maxWidth),
              );
              return dashboard(constraints.maxWidth);
            },
          ),
        ),
      ),
    );
  }
}
