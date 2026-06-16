import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:clock/clock.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_block.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_fold_surface.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_folding.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

export 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_block.dart';

part 'day_timeline_widgets.dart';

/// Hour-by-hour timeline rendering of a [DraftPlan]. Read-only in
/// this milestone.
///
/// Layout:
/// - Left rail (50 px) with hour labels over a midnight-to-midnight day.
/// - Content column with hour grid lines, energy bands behind, blocks
///   positioned absolutely by `start` / `end` minutes, and a now-line
///   if the current time falls inside the window.
/// - Drafted blocks gain a 1 px dashed outline so the whole frame
///   reads as provisional; committed blocks render solid.
class DayTimeline extends StatefulWidget {
  const DayTimeline({
    required this.draft,
    this.startHour = 0,
    this.endHour = 24,
    this.pxPerMinute = 1.0,
    this.actualBlocks,
    this.onRenameBlock,
    this.clock,
    this.showGestureHint = true,
    this.onGesturesLearned,
    super.key,
  });

  final DraftPlan draft;
  final int startHour;
  final int endHour;
  final double pxPerMinute;

  /// Whether the toolbar shows the one-shot "Swipe for actual · pinch to
  /// zoom" coaching line. Hosts pass false once the user has demonstrated
  /// the gestures (see [onGesturesLearned]); chrome should not keep
  /// explaining what the hands already know.
  final bool showGestureHint;

  /// Fired once per widget lifetime on the first lane page, pinch zoom,
  /// or lane-mode toggle — the host persists it and retires the hint.
  final VoidCallback? onGesturesLearned;

  /// Recorded work sessions projected from the real journal. Falls back
  /// to [DraftPlan.actualBlocks] for tests and mock fixtures.
  final List<TimeBlock>? actualBlocks;

  /// Inline rename for standalone planned blocks (handoff v2 item 3).
  /// Only the plan pane offers editing; tracked blocks already
  /// happened and stay read-only.
  final void Function(TimeBlock block, String title)? onRenameBlock;

  /// Injected clock used by the now-line. Defaults to `DateTime.now`.
  /// Tests pass a fixed `DateTime` to render the line deterministically.
  final DateTime Function()? clock;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  static const _minPxPerMinute = 0.55;
  static const _maxPxPerMinute = 3.2;
  static const _horizontalPeekFraction = 0.9;

  Timer? _timer;
  late DateTime _now;
  late double _pxPerMinute;
  late final PageController _pageController;
  late final ScrollController _timelineScrollController;
  final Map<int, Offset> _activePointers = <int, Offset>{};
  double? _pinchStartVerticalDistance;
  double? _pinchStartHorizontalDistance;
  late double _pinchStartPxPerMinute;
  double _timelineScrollOffset = 0;
  bool _timelineScrollRestoreScheduled = false;
  final Set<int> _expandedFoldRegionStarts = <int>{};
  _TimelineComparisonMode? _comparisonModeOverride;
  _TimelineComparisonMode _lastAutoComparisonMode =
      _TimelineComparisonMode.paged;

  /// Folding state from the most recent build, reused by [_centerOnNow]
  /// (which runs post-frame) instead of recomputing it from the blocks.
  TimelineFoldingState? _builtFoldingState;

  /// Debounces [DayTimeline.onGesturesLearned] to one firing per lifetime.
  bool _gesturesLearnedFired = false;

  void _markGesturesLearned() {
    if (_gesturesLearnedFired) return;
    _gesturesLearnedFired = true;
    widget.onGesturesLearned?.call();
  }

  @override
  void initState() {
    super.initState();
    _pxPerMinute = widget.pxPerMinute;
    _pageController = PageController(
      viewportFraction: _horizontalPeekFraction,
    )..addListener(_onLanePageScroll);
    _timelineScrollController = ScrollController()
      ..addListener(_recordTimelineScrollOffset);
    _pinchStartPxPerMinute = _pxPerMinute;
    _now = (widget.clock ?? clock.now)();
    if (widget.clock == null) {
      // Re-render once per minute when using the ambient clock so the
      // now-line tracks time. Skipped under test (fixed clock param).
      _scheduleNextMinute();
    }
    // Open with the now-line framed in the upper half of the viewport so
    // "where am I in the day" needs no scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnNow());
  }

  @override
  void didUpdateWidget(covariant DayTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pxPerMinute != widget.pxPerMinute) {
      _pxPerMinute = widget.pxPerMinute;
    }
  }

  void _onLanePageScroll() {
    final page = _pageController.hasClients ? _pageController.page : null;
    // Half a page of travel = the swipe gesture has been demonstrated.
    if (page != null && page > 0.5) _markGesturesLearned();
  }

  void _scheduleNextMinute() {
    final now = clock.now();
    final delay = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _now = clock.now());
      _scheduleNextMinute();
    });
  }

  /// Scrolls the timeline so the now-line sits ~45% down the viewport.
  /// No-op when now is outside the day's window or nothing scrolls.
  ///
  /// Runs post-frame, so [_builtFoldingState] from the build that just
  /// laid out the scrollable is the geometry the viewport actually shows.
  void _centerOnNow() {
    if (!mounted || !_timelineScrollController.hasClients) return;
    final foldingState = _builtFoldingState;
    if (foldingState == null) return;
    final position = _timelineScrollController.position;
    if (position.maxScrollExtent <= 0) return;
    final dayDate = widget.draft.dayDate;
    final windowStart = DateTime(
      dayDate.year,
      dayDate.month,
      dayDate.day,
      widget.startHour,
    );
    final windowEnd = windowStart.add(
      Duration(hours: widget.endHour - widget.startHour),
    );
    if (!_now.isAfter(windowStart) ||
        !_now.isBefore(windowEnd) ||
        !_isSameDay(_now, dayDate)) {
      return;
    }
    final nowTop = foldingState.positionForDate(
      _now,
      windowStart: windowStart,
      pxPerMinute: _pxPerMinute,
    );
    final target = (nowTop - position.viewportDimension * 0.45).clamp(
      0.0,
      position.maxScrollExtent,
    );
    _timelineScrollController.jumpTo(target);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController
      ..removeListener(_onLanePageScroll)
      ..dispose();
    _timelineScrollController
      ..removeListener(_recordTimelineScrollOffset)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hours = widget.endHour - widget.startHour;
    final actualBlocks = widget.actualBlocks ?? widget.draft.actualBlocks;
    final foldingState = TimelineFoldingState.fromBlocks(
      blocks: [...widget.draft.blocks, ...actualBlocks],
      dayDate: widget.draft.dayDate,
      startHour: widget.startHour,
      endHour: widget.endHour,
      expandedRegionStarts: _expandedFoldRegionStarts,
      collapsedHourHeight: tokens.spacing.step3,
    );
    _builtFoldingState = foldingState;
    final totalHeight = foldingState.totalHeight(_pxPerMinute);

    final windowStart = DateTime(
      widget.draft.dayDate.year,
      widget.draft.dayDate.month,
      widget.draft.dayDate.day,
      widget.startHour,
    );
    final windowEnd = windowStart.add(Duration(hours: hours));
    final nowInWindow =
        _now.isAfter(windowStart) &&
        _now.isBefore(windowEnd) &&
        _isSameDay(_now, widget.draft.dayDate);
    final paneLabelHeight =
        tokens.typography.lineHeight.overline + tokens.spacing.step2;
    final timelineTopInset = paneLabelHeight + tokens.spacing.step3;
    final timelineContentHeight = totalHeight + tokens.spacing.step9;
    // Hour labels and the now-chip live on the rail; widen it with the
    // user's text scale so "09:00" never clips at accessibility sizes.
    final timeRailWidth = math.max(
      tokens.spacing.step10,
      MediaQuery.textScalerOf(context).scale(tokens.spacing.step10),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final comparisonMode = _comparisonModeForWidth(constraints.maxWidth);
        return Column(
          children: [
            _TimelineToolbar(
              mode: comparisonMode,
              showHint: widget.showGestureHint,
              onToggleMode: _toggleComparisonMode,
            ),
            Expanded(
              child: Listener(
                onPointerDown: _handlePointerDown,
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerEnd,
                onPointerCancel: _handlePointerEnd,
                onPointerPanZoomStart: _handlePointerPanZoomStart,
                onPointerPanZoomUpdate: _handlePointerPanZoomUpdate,
                onPointerPanZoomEnd: _handlePointerPanZoomEnd,
                child: SingleChildScrollView(
                  key: const Key('daily_os_timeline_scroll'),
                  controller: _timelineScrollController,
                  child: SizedBox(
                    height: timelineContentHeight,
                    child: Stack(
                      children: [
                        Positioned(
                          left: timeRailWidth,
                          top: timelineTopInset,
                          right: tokens.spacing.step3,
                          height: totalHeight,
                          child: _GridLines(
                            foldingState: foldingState,
                            pxPerMinute: _pxPerMinute,
                          ),
                        ),
                        Positioned.fill(
                          left: timeRailWidth,
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: tokens.spacing.step3,
                            ),
                            child:
                                comparisonMode == _TimelineComparisonMode.both
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: _TimelinePane(
                                          label: context
                                              .messages
                                              .dailyOsNextTimelinePlanned,
                                          blocks: widget.draft.blocks,
                                          bands: widget.draft.bands,
                                          paneKey: const Key(
                                            'daily_os_timeline_plan_pane',
                                          ),
                                          foldingState: foldingState,
                                          labelHeight: paneLabelHeight,
                                          totalHeight: totalHeight,
                                          windowStart: windowStart,
                                          pxPerMinute: _pxPerMinute,
                                          now: nowInWindow ? _now : null,
                                          showBands: true,
                                          tracked: false,
                                          onRenameBlock: widget.onRenameBlock,
                                        ),
                                      ),
                                      SizedBox(width: tokens.spacing.step3),
                                      Expanded(
                                        child: _TimelinePane(
                                          label: context
                                              .messages
                                              .dailyOsNextTimelineActual,
                                          blocks: actualBlocks,
                                          bands: const [],
                                          paneKey: const Key(
                                            'daily_os_timeline_actual_pane',
                                          ),
                                          foldingState: foldingState,
                                          labelHeight: paneLabelHeight,
                                          totalHeight: totalHeight,
                                          windowStart: windowStart,
                                          pxPerMinute: _pxPerMinute,
                                          now: nowInWindow ? _now : null,
                                          showBands: false,
                                          tracked: true,
                                          onRenameBlock: null,
                                        ),
                                      ),
                                    ],
                                  )
                                : PageView(
                                    controller: _pageController,
                                    padEnds: false,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(
                                          right: tokens.spacing.step3,
                                        ),
                                        child: _TimelinePane(
                                          label: context
                                              .messages
                                              .dailyOsNextTimelinePlanned,
                                          blocks: widget.draft.blocks,
                                          bands: widget.draft.bands,
                                          paneKey: const Key(
                                            'daily_os_timeline_plan_pane',
                                          ),
                                          foldingState: foldingState,
                                          labelHeight: paneLabelHeight,
                                          totalHeight: totalHeight,
                                          windowStart: windowStart,
                                          pxPerMinute: _pxPerMinute,
                                          now: nowInWindow ? _now : null,
                                          showBands: true,
                                          tracked: false,
                                          onRenameBlock: widget.onRenameBlock,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                          right: tokens.spacing.step3,
                                        ),
                                        child: _TimelinePane(
                                          label: context
                                              .messages
                                              .dailyOsNextTimelineActual,
                                          blocks: actualBlocks,
                                          bands: const [],
                                          paneKey: const Key(
                                            'daily_os_timeline_actual_pane',
                                          ),
                                          foldingState: foldingState,
                                          labelHeight: paneLabelHeight,
                                          totalHeight: totalHeight,
                                          windowStart: windowStart,
                                          pxPerMinute: _pxPerMinute,
                                          now: nowInWindow ? _now : null,
                                          showBands: false,
                                          tracked: true,
                                          onRenameBlock: null,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        Positioned(
                          left: timeRailWidth,
                          top: timelineTopInset,
                          right: tokens.spacing.step3,
                          height: totalHeight,
                          child: FoldRegionLayer(
                            foldingState: foldingState,
                            pxPerMinute: _pxPerMinute,
                            onToggleFoldRegion: _toggleFoldRegion,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: timeRailWidth,
                          child: _SharedHourRail(
                            foldingState: foldingState,
                            pxPerMinute: _pxPerMinute,
                            now: nowInWindow ? _now : null,
                            windowStart: windowStart,
                            topInset: timelineTopInset,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleComparisonMode() {
    // Discovering the lane toggle teaches the same fact as the swipe.
    _markGesturesLearned();
    final comparisonMode = _effectiveComparisonMode;
    setState(() {
      _comparisonModeOverride = comparisonMode == _TimelineComparisonMode.paged
          ? _TimelineComparisonMode.both
          : _TimelineComparisonMode.paged;
    });
  }

  void _toggleFoldRegion(int startHour) {
    setState(() {
      if (!_expandedFoldRegionStarts.remove(startHour)) {
        _expandedFoldRegionStarts.add(startHour);
      }
    });
    _scheduleTimelineScrollRestore();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 2) {
      final distances = _pointerDistances();
      _pinchStartVerticalDistance = distances.$1;
      _pinchStartHorizontalDistance = distances.$2;
      _pinchStartPxPerMinute = _pxPerMinute;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length != 2) return;

    final startVertical = _pinchStartVerticalDistance;
    final startHorizontal = _pinchStartHorizontalDistance;
    if (startVertical == null || startHorizontal == null) return;

    final distances = _pointerDistances();
    final verticalScale = startVertical <= 0
        ? 1.0
        : distances.$1 / startVertical;
    final horizontalScale = startHorizontal <= 0
        ? 1.0
        : distances.$2 / startHorizontal;

    final horizontalDelta = (horizontalScale - 1).abs();
    final verticalDelta = (verticalScale - 1).abs();
    if (horizontalDelta > 0.16 && horizontalDelta > verticalDelta * 1.35) {
      final comparisonMode = _effectiveComparisonMode;
      final nextMode = horizontalScale < 0.82
          ? _TimelineComparisonMode.both
          : horizontalScale > 1.08
          ? _TimelineComparisonMode.paged
          : comparisonMode;
      if (nextMode != comparisonMode) {
        setState(() => _comparisonModeOverride = nextMode);
      }
      return;
    }

    if (verticalDelta < 0.02) return;
    _applyScaleFromStart(verticalScale);
  }

  void _handlePointerPanZoomStart(PointerPanZoomStartEvent event) {
    _pinchStartPxPerMinute = _pxPerMinute;
  }

  void _handlePointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final scale = event.scale;
    if (!scale.isFinite || (scale - 1).abs() < 0.01) return;
    _applyScaleFromStart(scale);
  }

  void _handlePointerPanZoomEnd(PointerPanZoomEndEvent event) {
    _pinchStartPxPerMinute = _pxPerMinute;
  }

  void _applyScaleFromStart(double scale) {
    final currentPxPerMinute = _pxPerMinute;
    final next = (_pinchStartPxPerMinute * scale).clamp(
      _minPxPerMinute,
      _maxPxPerMinute,
    );
    if ((next - currentPxPerMinute).abs() >= 0.01) {
      _markGesturesLearned();
      final currentOffset = _currentTimelineScrollOffset();
      final scrollScale = next / currentPxPerMinute;
      setState(() {
        _pxPerMinute = next;
        _timelineScrollOffset = currentOffset * scrollScale;
      });
      _scheduleTimelineScrollRestore();
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) {
      _pinchStartVerticalDistance = null;
      _pinchStartHorizontalDistance = null;
      _pinchStartPxPerMinute = _pxPerMinute;
    }
  }

  (double, double) _pointerDistances() {
    final values = _activePointers.values.toList(growable: false);
    if (values.length < 2) return (0, 0);
    return (
      (values[0].dy - values[1].dy).abs(),
      (values[0].dx - values[1].dx).abs(),
    );
  }

  _TimelineComparisonMode _comparisonModeForWidth(double width) {
    _lastAutoComparisonMode = width >= kDesktopBreakpoint
        ? _TimelineComparisonMode.both
        : _TimelineComparisonMode.paged;
    return _effectiveComparisonMode;
  }

  _TimelineComparisonMode get _effectiveComparisonMode =>
      _comparisonModeOverride ?? _lastAutoComparisonMode;

  double _currentTimelineScrollOffset() {
    if (_timelineScrollController.hasClients) {
      return _timelineScrollController.position.pixels;
    }
    return _timelineScrollOffset;
  }

  void _recordTimelineScrollOffset() {
    if (!_timelineScrollController.hasClients) return;
    _timelineScrollOffset = _timelineScrollController.position.pixels;
  }

  void _scheduleTimelineScrollRestore() {
    if (_timelineScrollRestoreScheduled) return;
    _timelineScrollRestoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timelineScrollRestoreScheduled = false;
      if (!mounted || !_timelineScrollController.hasClients) return;
      final position = _timelineScrollController.position;
      final offset = _timelineScrollOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - offset).abs() >= 0.5) {
        _timelineScrollController.jumpTo(offset);
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
