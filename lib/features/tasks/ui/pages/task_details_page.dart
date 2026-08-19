import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/mixins/highlight_scroll_mixin.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked_from.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_with_timer.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/task_app_bar.dart';
import 'package:lotti/features/tasks/ui/task_form.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:lotti/features/tasks/ui/widgets/task_first_run_actions.dart';
import 'package:lotti/features/tasks/ui/widgets/task_history_section.dart';
import 'package:lotti/features/tasks/ui/widgets/viewport_stable_animated_size.dart';
import 'package:lotti/features/tasks/util/scroll_anchor.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/media_import.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/widgets/media/media_drop_target.dart';

/// Full-screen detail view for a single task identified by [taskId].
///
/// Renders a [CustomScrollView] with a sliver app bar, the [TaskForm]
/// (header, AI summary, checklists, linked tasks), and the task's dated
/// log-entry history below — collapsed by default behind a
/// [TaskHistorySection] header, force-expanded when a focus intent targets
/// an entry inside it. A sticky [TaskActionBar] sits in the `bottomNavigationBar`
/// slot; `extendBody` lets its glass blur read the scrolling body and a
/// trailing [SliverPadding] reserves the bar's height so the last entry can
/// scroll clear of it. Listens to the task focus controller to auto-scroll
/// to a target entry or the AI suggestions, and accepts dropped media via
/// [MediaDropTarget] to link and (optionally) analyze it.
class TaskDetailsPage extends ConsumerStatefulWidget {
  const TaskDetailsPage({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  ConsumerState<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends ConsumerState<TaskDetailsPage>
    with HighlightScrollMixin {
  final _scrollController = ViewportStableScrollController();
  final void Function() _listener = getIt<UserActivityService>().updateActivity;
  late final void Function() _updateOffsetListener;
  final Map<String, GlobalKey> _entryKeys = {};
  final GlobalKey<State<StatefulWidget>> _suggestionsKey = GlobalKey(
    debugLabel: 'task_suggestions',
  );

  /// Anchors the seam just below the AI card (the linked-entries sliver). When
  /// the card grows while scrolled fully above the viewport, pinning this seam
  /// keeps the visible content from being shoved down. See
  /// [_holdBelowCardIfCardOffscreen].
  final GlobalKey _belowCardKey = GlobalKey(debugLabel: 'task_below_card');

  /// Marks the AI card band inside [TaskForm] so [_isCardRegionAboveViewport]
  /// can measure it. Deliberately the band's own box rather than the seam below
  /// it: the same answer decides both which anchor is armed and whether the
  /// card band reports its height deltas, and measuring two different edges
  /// would let those decisions disagree in the gap between them.
  final GlobalKey _cardRegionKey = GlobalKey(debugLabel: 'task_ai_card_region');

  /// Marks the linked-tasks band, so [_onLinkedTasksChanged] can tell whether
  /// a background link write happened anywhere the user can see.
  final GlobalKey _linkedTasksRegionKey = GlobalKey(
    debugLabel: 'task_linked_tasks_region',
  );
  Timer? _suggestionsRetryTimer;

  /// Fallback anchor for above-card changes that do not report their own size
  /// delta to [_scrollController]. With the AI card sitting right below the
  /// header, the header band is the only content above the proposals; this
  /// anchor covers proposal-driven header mutations (title, tagline,
  /// metadata) that slip past the pre-paint correction path.
  late final ScrollAnchor _suggestionsAnchor;

  /// Holds the content below the AI card fixed while the card grows off-screen
  /// above the viewport (a new suggestion landing), so the visible area never
  /// jumps. The dual of [_suggestionsAnchor], which guards shrink-above-card.
  late final ScrollAnchor _belowCardAnchor;

  /// Spans the card's `EnterTransition` reveal (`MotionDurations.medium2`) plus
  /// a buffer, so the below-card pin holds for the whole growth animation.
  static final Duration _belowCardGrowthHold =
      MotionDurations.medium2 + const Duration(milliseconds: 200);

  /// Covers delayed checklist completion collapse plus a small persistence and
  /// notification buffer. Repeated resolve starts refresh this window, which
  /// keeps a sequential confirm-all batch armed until its final mutation.
  static final Duration _suggestionResolveHold =
      checklistCompletionAnimationDuration +
      checklistCompletionFadeDuration +
      const Duration(milliseconds: 200);
  int? _lastOpenSuggestionCount;

  /// Baseline for [_onLinkedTasksChanged], reset alongside
  /// [_lastOpenSuggestionCount] when the page is reused for another task.
  ///
  /// The resolved groups rather than their count: `TaskLinkGroupsController`
  /// re-emits whenever any watched linked task's data changes, and a synced
  /// title growing from one rendered line to two resizes the band without
  /// changing how many links there are.
  TaskLinkGroups? _lastLinkGroups;

  /// The task the [_lastOpenSuggestionCount] belongs to. If this page's state is
  /// reused for a different task (e.g. a master-detail pane), the count is reset
  /// so a stale previous-task count can't falsely trigger the scroll anchor.
  String? _lastTaskId;

  /// Whether the dated log-entry history is expanded. Collapsed by default —
  /// the history is the page's longest region — and force-expanded when a
  /// focus intent targets an entry inside it, because a collapsed section has
  /// no mounted entry keys to scroll to.
  bool _historyExpanded = false;

  @override
  void initState() {
    final provider = taskAppBarControllerProvider(widget.taskId);
    _updateOffsetListener = () => ref
        .read(provider.notifier)
        .updateOffset(
          _scrollController.offset,
        );

    _scrollController
      ..addListener(_listener)
      ..addListener(_updateOffsetListener);

    _suggestionsAnchor = ScrollAnchor(
      controller: _scrollController,
      locate: _suggestionsViewportTop,
      // Cover a checked-off item's *delayed* row collapse: confirming a
      // "check off" proposal leaves the checklist row in place, then collapses
      // it (hold + cross-fade) ~a second later. The checklist sits below the
      // card now, so that shrink no longer displaces the proposals — but the
      // window still has to span header-band mutations from the same batch.
      // The hold bows out early if the user scrolls in the meantime.
      holdDuration: _suggestionResolveHold,
    );

    _belowCardAnchor = ScrollAnchor(
      controller: _scrollController,
      locate: _belowCardViewportTop,
      holdDuration: _belowCardGrowthHold,
    );

    super.initState();
  }

  @override
  void dispose() {
    disposeHighlight();
    _suggestionsRetryTimer?.cancel();
    _suggestionsAnchor.dispose();
    _belowCardAnchor.dispose();
    _scrollController
      ..removeListener(_listener)
      ..removeListener(_updateOffsetListener)
      ..dispose();
    super.dispose();
  }

  /// Global-Y of the AI proposals section, or null when it isn't laid out.
  double? _suggestionsViewportTop() {
    final renderObject = _suggestionsKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    return renderObject.localToGlobal(Offset.zero).dy;
  }

  /// Arms exactly one stabilization geometry before proposal persistence
  /// begins.
  ///
  /// The header — the only band above the card — always reports its height
  /// deltas to [_scrollController], which corrects during viewport layout so
  /// no displaced frame is painted. The checklist and linked-tasks bands sit
  /// below the card and report only while the below-card hold is armed. What
  /// changes is *which point* has to stay still, and that flips when the card
  /// leaves the screen:
  ///
  /// * **Card visible** — the proposals under the user's pointer must not move,
  ///   so [_suggestionsAnchor] holds. The card's own collapse is the reflow the
  ///   user is watching, so the card band stays silent.
  /// * **Card fully above the viewport** — the user is reading the content
  ///   below it, and every resolved proposal — confirmed or dismissed
  ///   alike — collapses a row and shrinks
  ///   the card, dragging that content up. [_suggestionsAnchor] is structurally
  ///   blind to it, because a row collapsing *inside* the proposals section does
  ///   not move the section's top. So the card band reports its own shrink for a
  ///   pre-paint correction — as do the checklist and linked-tasks bands, which
  ///   sit between the card and the seam — and [_belowCardAnchor] pins the
  ///   linked-entries seam.
  ///
  /// The two anchors are never armed together. They sit either side of the
  /// change, so the correction that holds one still moves the other by exactly
  /// that height change — which the other then reads as drift and undoes on the
  /// next post-frame. Both holding means both jumping, every frame.
  ///
  /// The layers cooperate via [CooperativeScrollStabilizer] so neither mistakes
  /// the other's correction for a user scroll and disarms mid-batch.
  void _holdSuggestionsStable() {
    final cardOffscreen = _isCardRegionAboveViewport();
    _scrollController.hold(
      _suggestionResolveHold,
      includeOffscreenRegions: cardOffscreen,
    );
    if (cardOffscreen) {
      _suggestionsAnchor.release();
      _belowCardAnchor.hold(duration: _suggestionResolveHold);
    } else {
      _belowCardAnchor.release();
      _suggestionsAnchor.hold();
    }
  }

  /// Drops both baselines when the page's state is reused for a different task
  /// (e.g. a master-detail pane), so a previous task's state can't make the
  /// next task's first emission look like a change and fire an anchor.
  ///
  /// Returns whether it reset, so a caller cannot then fall back to the
  /// listener's `previous` value — which belongs to the task just navigated
  /// away from.
  bool _resetBaselinesIfTaskChanged() {
    if (_lastTaskId == widget.taskId) return false;
    _lastTaskId = widget.taskId;
    _lastOpenSuggestionCount = null;
    _lastLinkGroups = null;
    // The next task starts with its history collapsed again; no setState —
    // this runs from listeners and the taskId change rebuilds the page
    // anyway.
    _historyExpanded = false;
    return true;
  }

  /// When the open-proposal count drops (a proposal was confirmed/dismissed),
  /// pin the proposals' position so the relayout above them doesn't yank the
  /// page down under the user's eyes.
  void _onSuggestionsChanged(
    AsyncValue<UnifiedSuggestionList>? previous,
    AsyncValue<UnifiedSuggestionList> next,
  ) {
    _resetBaselinesIfTaskChanged();
    final nextOpen = next.value?.open.length;
    final previousOpen = _lastOpenSuggestionCount;
    if (nextOpen != null) _lastOpenSuggestionCount = nextOpen;
    if (nextOpen == null) return;
    if (previousOpen != null && nextOpen < previousOpen) {
      _holdSuggestionsStable();
    } else if (nextOpen > (previousOpen ?? 0)) {
      // A new proposal grew the card. If it has scrolled fully above the
      // viewport (the user can't see it), pin the content below the card so the
      // growth doesn't push the visible area down. A visible card is left to
      // the card's own EnterTransition, which eases the growth in smoothly.
      _holdBelowCardIfCardOffscreen();
    }
  }

  /// Global-Y of the first content below the AI card (the linked-entries
  /// sliver's top), or null when it isn't laid out / attached.
  double? _belowCardViewportTop() {
    final renderObject = _belowCardKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    return renderObject.localToGlobal(Offset.zero).dy;
  }

  /// Global-Y of the top of the scroll viewport (where the slivers begin to be
  /// painted), or null when it isn't available.
  double? _viewportTopGlobal() {
    return viewportTopGlobal(
      _belowCardKey.currentContext?.findRenderObject(),
    );
  }

  /// Global-Y of the bottom of the AI card band, or null when it isn't laid
  /// out. `SliverToBoxAdapter` lays its child out at any scroll offset, so this
  /// stays valid however far the card has scrolled away.
  double? _cardRegionBottomGlobal() {
    final renderObject = _cardRegionKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset(0, renderObject.size.height)).dy;
  }

  /// Whether the AI card has scrolled fully above the viewport — the user can't
  /// see it change size, so its own growth or shrink must not move what they
  /// *are* looking at.
  ///
  /// Measured on the card band rather than the seam below it wherever
  /// possible: the seam (the linked-entries sliver) sits a whole two sections
  /// — checklists and linked tasks — lower, and in that span the card is
  /// already out of sight while the seam is not.
  ///
  /// Once the card's sliver has scrolled beyond the viewport's cache extent the
  /// framework drops its subtree, so the band has no render object to measure.
  /// The seam below it answers the same question then — it is the first content
  /// that survives — and it disambiguates the other reason the band can be
  /// missing: a card that has not been reached yet is *below* the viewport, and
  /// so is its seam. Nothing needs correcting while the band is unmounted (an
  /// unlaid-out card cannot change height), but the post-frame anchor still has
  /// to be the below-card one.
  bool _isCardRegionAboveViewport() {
    final viewportTop = _viewportTopGlobal();
    if (viewportTop == null) return false;
    final cardBottom = _cardRegionBottomGlobal();
    if (cardBottom != null) return cardBottom <= viewportTop;
    final belowTop = _belowCardViewportTop();
    return belowTop != null && belowTop <= viewportTop;
  }

  /// A new proposal grew the card. Pin the content below it *only* when the
  /// card has scrolled fully above the viewport top — i.e. the user can't see
  /// the card grow. A visible / partly-visible card is deliberately left alone
  /// so its entrance reveals the growth in place rather than the page scrolling
  /// under the user.
  ///
  /// The controller hold is armed alongside the anchor so the card band's own
  /// growth is corrected pre-paint. Without it the post-frame anchor lags one
  /// frame behind every frame of the reveal, which reads as jitter rather than
  /// as a single displacement.
  void _holdBelowCardIfCardOffscreen() {
    if (!_isCardRegionAboveViewport()) return;
    _scrollController.hold(
      _belowCardGrowthHold,
      includeOffscreenRegions: true,
    );
    _suggestionsAnchor.release();
    _belowCardAnchor.hold();
  }

  /// Whether the band marked by [key] starts below everything the user can see.
  ///
  /// A height change down there moves nothing that is on screen, so
  /// compensating it would scroll the page under content that had no reason to
  /// move. Unknown geometry answers `false`: an unlaid-out band reports no
  /// delta either, so arming is inert rather than wrong.
  bool _isRegionBelowViewport(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return false;
    }
    final viewportBottom = viewportBottomGlobal(renderObject);
    if (viewportBottom == null) return false;
    return renderObject.localToGlobal(Offset.zero).dy >= viewportBottom;
  }

  /// Re-arms stabilization when the linked-tasks band changes height.
  ///
  /// `create_follow_up_task` links its new task only *after* awaiting agent
  /// content generation, so the relayout can land seconds after the tap — long
  /// past the window [_holdSuggestionsStable] armed at gesture time. Watching
  /// the band's own count catches it whenever it actually lands, and covers
  /// user-initiated linking too.
  ///
  /// Unlike the gesture path, this fires without the user having touched
  /// anything — a sync or another background writer can change the link set at
  /// any scroll position. When the band sits entirely below the viewport its
  /// growth moves nothing on screen, and correcting for it would drag the
  /// content the user *is* reading upwards. So that case is left alone; a
  /// band that is visible or above stays worth arming for, because the
  /// linked entries below it would otherwise shift. (While the card is
  /// visible the armed hold ignores this band's delta anyway — the band sits
  /// below the proposals, so its growth is the visible reflow.)
  ///
  /// The baseline falls back to the listener's own [previous] value, because
  /// `taskLinkGroupsControllerProvider` is cached for `entryCacheDuration`: a
  /// page mounting onto an already-resolved provider gets no emission for the
  /// value already there, so without the fallback the first real change would
  /// only establish the baseline and arm nothing.
  void _onLinkedTasksChanged(
    AsyncValue<TaskLinkGroups>? previous,
    AsyncValue<TaskLinkGroups> next,
  ) {
    final didReset = _resetBaselinesIfTaskChanged();
    final nextGroups = next.value;
    if (nextGroups == null) return;
    final previousGroups =
        _lastLinkGroups ?? (didReset ? null : previous?.value);
    _lastLinkGroups = nextGroups;
    if (previousGroups == null) return;
    // Compare the resolved entries, not their count. The controller re-emits
    // only when they actually differ, and any such difference — a retitled
    // task wrapping onto a second line, a status glyph appearing — can change
    // the band's height even when the number of links is identical.
    if (_linkGroupsEqual(previousGroups, nextGroups)) return;
    if (_isRegionBelowViewport(_linkedTasksRegionKey)) return;
    _holdSuggestionsStable();
  }

  /// Deep equality over both link buckets. `TaskLinkGroups` itself carries only
  /// identity equality, and giving it value equality would change when Riverpod
  /// notifies its other consumers.
  static bool _linkGroupsEqual(TaskLinkGroups a, TaskLinkGroups b) =>
      listEquals(a.flat, b.flat) && listEquals(a.typed, b.typed);

  GlobalKey _getEntryKey(String entryId) {
    return _entryKeys.putIfAbsent(
      entryId,
      () => GlobalKey<State>(debugLabel: 'entry_$entryId'),
    );
  }

  /// The dated entry stream: outgoing linked entries plus reverse links.
  /// Both widgets collapse to nothing on a task without entries.
  Widget _buildEntryStream(Task task, String? highlightedEntryId) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        LinkedEntriesWithTimer(
          item: task,
          entryKeyBuilder: _getEntryKey,
          highlightedEntryId: highlightedEntryId,
          hideTaskEntries: true,
        ),
        LinkedFromEntriesWidget(
          task,
          hideTaskEntries: true,
        ),
      ],
    ).animate().fadeIn(duration: const Duration(milliseconds: 100));
  }

  @override
  Widget build(BuildContext context) {
    final focusProvider = taskFocusControllerProvider(widget.taskId);

    void handleFocus(TaskFocusIntent? intent, {bool isInitialLoad = false}) {
      if (intent == null) return;
      switch (intent.target) {
        case TaskFocusTarget.entry:
          final entryId = intent.entryId;
          if (entryId == null) {
            ref.read(focusProvider.notifier).clearIntent();
            return;
          }
          // The target lives inside the collapsed history — open it first so
          // the entry mounts and the retrying scroll can find its key.
          if (!_historyExpanded) {
            setState(() => _historyExpanded = true);
          }
          scrollToEntry(
            entryId,
            intent.alignment,
            getEntryKey: _getEntryKey,
            onScrolled: () => ref.read(focusProvider.notifier).clearIntent(),
            isInitialLoad: isInitialLoad,
          );
        case TaskFocusTarget.suggestions:
          _scrollToSuggestions(
            intent.alignment,
            onScrolled: () => ref.read(focusProvider.notifier).clearIntent(),
            isInitialLoad: isInitialLoad,
          );
      }
    }

    ref
      ..listen<TaskFocusIntent?>(
        focusProvider,
        (previous, next) => handleFocus(next, isInitialLoad: previous == null),
      )
      // Hold the AI proposals in place when one is confirmed (which can grow
      // the header above them) so the page doesn't jump under the user.
      ..listen<AsyncValue<UnifiedSuggestionList>>(
        unifiedSuggestionListProvider(widget.taskId),
        _onSuggestionsChanged,
      )
      // A confirmed follow-up task links itself only after its agent content
      // has been generated, so this band can resize long after the resolve
      // window closed. Re-arm whenever it actually does.
      ..listen<AsyncValue<TaskLinkGroups>>(
        taskLinkGroupsControllerProvider(widget.taskId),
        _onLinkedTasksChanged,
      );

    final provider = entryControllerProvider(widget.taskId);
    final asyncTask = ref.watch(provider);
    final task = asyncTask.value?.entry;

    // Only attempt to scroll after task data is loaded
    if (asyncTask.hasValue && task != null && task is Task) {
      // Check for pre-existing intent after task is loaded (navigation from calendar)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final intent = ref.read(focusProvider);
        if (intent != null) {
          handleFocus(intent, isInitialLoad: true);
        }
      });
    }

    if (task == null || task is! Task) {
      return const EmptyScaffoldWithTitle('');
    }

    // An empty task narrows the whole column to the first-run block's measure,
    // so the title field, the chip lane and the block share one right edge.
    // At the full reading width the three disagreed by hundreds of points and
    // the only card on the page floated far left of the window's centre — the
    // "nothing lines up with anything" read every reviewer described.
    final isFirstRun = watchTaskIsFirstRun(ref, task);
    final contentMaxWidth = isFirstRun
        ? TaskFirstRunActions.maxWidth
        : kDetailContentMaxWidth;

    final scaffold = Scaffold(
      backgroundColor: context.designTokens.colors.background.level01,
      // extendBody so the BackdropFilter inside [TaskActionBar]'s
      // glass strip has body content underneath to actually blur. The
      // body's bottom inset is reserved automatically for the
      // bottomNavigationBar slot, so we don't need a magic-number
      // bottom padding on the slivers.
      extendBody: true,
      // The mobile shell hides its bottom nav bar whenever the
      // current beamer route is `/tasks/<uuid>` (see
      // _AppScreenState._isTaskDetailRoute), so the action bar
      // sits flush with the home indicator. TaskActionBar handles its
      // own bottom safe-inset padding.
      bottomNavigationBar: TaskActionBar(
        task: task,
        topSlot: AiRunningDecoderBars(
          entryId: widget.taskId,
          isInteractive: true,
          responseTypes: const {
            AiResponseType.imageAnalysis,
            AiResponseType.audioTranscription,
            AiResponseType.promptGeneration,
            AiResponseType.imageGeneration,
          },
        ),
      ),
      // Builder so MediaQuery.paddingOf reads the Scaffold-modified
      // value: with extendBody: true, Scaffold adds the
      // bottomNavigationBar slot height (action bar + inline AI activity
      // slot when running) to padding.bottom on the body's MediaQuery. The
      // trailing SliverPadding consumes that inset so the last entry
      // can scroll fully above the bar instead of being hidden behind.
      body: Builder(
        builder: (context) => TaskScrollStabilityScope(
          controller: _scrollController,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              TaskSliverAppBar(taskId: widget.taskId),
              // On a first-run task the page has one short card and nothing
              // else, so the remainder is composed rather than left over:
              // `SliverFillRemaining` claims the rest of the viewport and the
              // group settles above optical centre. Four review rounds in a
              // row, every reviewer read the top-anchored version the same way
              // — "the page stopped loading" — because every authored gap on
              // it was 8–28pt and then one silence ran a third of the window.
              _FirstSliver(
                fillRemaining: isFirstRun,
                child: Center(
                  child: AnimatedContainer(
                    // The first content tap flips `isFirstRun`, and with it
                    // this measure (520 → 960). Snapping it in a single frame
                    // was the page punishing the exact tap it invites —
                    // animated, the column eases out to the reading width
                    // while `_FirstSliver` releases its anchoring on the same
                    // clock.
                    duration: MotionDurations.medium2,
                    curve: MotionCurves.standard,
                    // Cap the content measure on wide windows so the task reads
                    // as a centered column rather than full-bleed text; this is
                    // non-binding at phone / narrow-pane widths.
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Padding(
                      // The page owns the content gutter, once. The header,
                      // its breadcrumb and this sliver each used to add a
                      // little of their own, which put five different left
                      // edges (15 / 21 / 23 / 24.5 / 27 logical) in the top
                      // hundred points of the page — the loudest single cue
                      // that nothing here was laid out on purpose.
                      padding: EdgeInsets.only(
                        left: context.designTokens.spacing.step5,
                        right: context.designTokens.spacing.step5,
                        top: context.designTokens.spacing.step4,
                      ),
                      child: TaskForm(
                        taskId: widget.taskId,
                        suggestionsFocusKey: _suggestionsKey,
                        cardRegionKey: _cardRegionKey,
                        linkedTasksRegionKey: _linkedTasksRegionKey,
                        onSuggestionResolveStart: _holdSuggestionsStable,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  key: _belowCardKey,
                  child: AnimatedContainer(
                    // Same clock as the first sliver's measure, so the two
                    // bands widen as one column instead of shearing.
                    duration: MotionDurations.medium2,
                    curve: MotionCurves.standard,
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Padding(
                      // Same gutter as the sliver above, so the linked
                      // entries share the header's left rail instead of
                      // sitting 5pt inside it.
                      padding: EdgeInsets.only(
                        top: context.designTokens.spacing.step3,
                        left: context.designTokens.spacing.step5,
                        right: context.designTokens.spacing.step5,
                      ),
                      // The dated log history lives behind a collapsed-by-
                      // default section: it is the page's longest region, and
                      // the summary / todos / linked tasks above it are what a
                      // reader needs first. A first-run task drops the
                      // History header — but NOT the entry widgets: the
                      // first-run predicate examines only *outgoing* links,
                      // so a blank task can still carry entries that link TO
                      // it, and hiding the whole subtree would disappear
                      // them with no way to expand. The bare column renders
                      // nothing when there is truly nothing.
                      child: isFirstRun
                          ? _buildEntryStream(task, highlightedEntryId)
                          : TaskHistorySection(
                              expanded: _historyExpanded,
                              onToggle: () => setState(
                                () => _historyExpanded = !_historyExpanded,
                              ),
                              child: _buildEntryStream(
                                task,
                                highlightedEntryId,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Scope toasts triggered from inside the task details subtree to a
    // nested ScaffoldMessenger so SnackBars float above the sticky
    // [TaskActionBar] (the Scaffold's bottomNavigationBar) instead of the
    // screen / window bottom edge — on mobile the bar would otherwise
    // cover the toast, on desktop it would sit visually detached at the
    // app window's bottom edge.
    final body = ScaffoldMessenger(child: scaffold);

    return MediaDropTarget(
      onFiles: (files) => handleDroppedMediaFiles(
        files,
        linkedId: task.meta.id,
        categoryId: task.meta.categoryId,
        analysisTrigger: ref.read(automaticImageAnalysisTriggerProvider),
      ),
      child: body,
    );
  }

  void _scrollToSuggestions(
    double alignment, {
    required VoidCallback onScrolled,
    required bool isInitialLoad,
  }) {
    final delay = isInitialLoad
        ? initialScrollDelay
        : const Duration(milliseconds: 100);

    _suggestionsRetryTimer?.cancel();
    _suggestionsRetryTimer = Timer(delay, () {
      _scrollToSuggestionsWithRetry(
        alignment,
        attempt: 0,
        onScrolled: onScrolled,
      );
    });
  }

  void _scrollToSuggestionsWithRetry(
    double alignment, {
    required int attempt,
    required VoidCallback onScrolled,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final context = _suggestionsKey.currentContext;
      if (context != null) {
        try {
          await Scrollable.ensureVisible(
            context,
            alignment: alignment,
            duration: scrollDuration,
            curve: Curves.easeInOut,
          );
        } catch (error) {
          DevLogger.warning(
            name: 'TaskDetailsPage',
            message: 'Failed to scroll to task suggestions: $error',
          );
        } finally {
          _suggestionsRetryTimer?.cancel();
          if (mounted) {
            onScrolled();
          }
        }
        return;
      }

      if (attempt < maxScrollRetries - 1) {
        _suggestionsRetryTimer?.cancel();
        _suggestionsRetryTimer = Timer(scrollRetryDelay, () {
          _scrollToSuggestionsWithRetry(
            alignment,
            attempt: attempt + 1,
            onScrolled: onScrolled,
          );
        });
        return;
      }

      DevLogger.warning(
        name: 'TaskDetailsPage',
        message:
            'Failed to scroll to task suggestions after $maxScrollRetries attempts',
      );
      _suggestionsRetryTimer?.cancel();
      if (mounted) {
        onScrolled();
      }
    });
  }
}

/// The task page's first content sliver.
///
/// Normally a plain [SliverToBoxAdapter] that takes its child's height. On a
/// first-run task — one short card and nothing below it — it instead grows to
/// at least the remaining viewport and settles the group above optical centre,
/// so the leftover space reads as margin rather than as a page that stopped
/// rendering.
///
/// Deliberately **not** `SliverFillRemaining(hasScrollBody: false)`: that
/// measures the child's intrinsic height, and the subtree contains
/// `LayoutBuilder`s (the header's meta row, the linked-tasks header) which
/// cannot answer an intrinsic query. A `minHeight` constraint gets the same
/// composition without ever asking. It is a floor, not a fixed height, so a
/// long title or a large text scale grows the sliver and scrolls normally
/// instead of clipping.
class _FirstSliver extends StatefulWidget {
  const _FirstSliver({required this.child, required this.fillRemaining});

  final Widget child;
  final bool fillRemaining;

  @override
  State<_FirstSliver> createState() => _FirstSliverState();
}

class _FirstSliverState extends State<_FirstSliver> {
  /// Vertical alignment of the group within the filled height. Above the
  /// geometric centre — optical centre, where the eye expects a short
  /// composition to sit — but only just, so the breadcrumb stays tied to the
  /// app bar above it rather than floating free in the middle of the window.
  static const Alignment _opticalCentre = Alignment(0, -0.45);

  /// Whether the measuring branch (the [SliverLayoutBuilder]) is mounted.
  ///
  /// The first content tap flips [_FirstSliver.fillRemaining] off, but the
  /// composed fill cannot simply switch to the plain branch in the same frame
  /// — that snaps the group from optical centre to the top in one jump, half
  /// of the "layout earthquake" the page fired at the exact tap it invited.
  /// Instead the layout branch stays mounted while the height floor and the
  /// alignment ease out on the shared `medium2` clock, and only then does the
  /// sliver settle into the plain adapter that ordinary tasks use (so normal
  /// scrolling never pays the layout-builder's rebuild-on-scroll cost).
  late bool _fillLayout = widget.fillRemaining;

  @override
  void didUpdateWidget(covariant _FirstSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fillRemaining && !_fillLayout) {
      setState(() => _fillLayout = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_fillLayout) return SliverToBoxAdapter(child: widget.child);
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverToBoxAdapter(
        child: AnimatedContainer(
          duration: MotionDurations.medium2,
          curve: MotionCurves.standard,
          constraints: BoxConstraints(
            minHeight: widget.fillRemaining
                ? constraints.remainingPaintExtent
                : 0,
          ),
          onEnd: () {
            if (!widget.fillRemaining && mounted) {
              setState(() => _fillLayout = false);
            }
          },
          child: AnimatedAlign(
            duration: MotionDurations.medium2,
            curve: MotionCurves.standard,
            alignment: widget.fillRemaining
                ? _opticalCentre
                : Alignment.topCenter,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
