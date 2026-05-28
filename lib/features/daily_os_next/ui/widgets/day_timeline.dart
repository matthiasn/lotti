import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/why_chip.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
    this.clock,
    super.key,
  });

  final DraftPlan draft;
  final int startHour;
  final int endHour;
  final double pxPerMinute;

  /// Recorded work sessions projected from the real journal. Falls back
  /// to [DraftPlan.actualBlocks] for tests and mock fixtures.
  final List<TimeBlock>? actualBlocks;

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

  @override
  void initState() {
    super.initState();
    _pxPerMinute = widget.pxPerMinute;
    _pageController = PageController(
      viewportFraction: _horizontalPeekFraction,
    );
    _timelineScrollController = ScrollController()
      ..addListener(_recordTimelineScrollOffset);
    _pinchStartPxPerMinute = _pxPerMinute;
    _now = (widget.clock ?? DateTime.now)();
    if (widget.clock == null) {
      // Re-render once per minute when using the real clock so the
      // now-line tracks time. Skipped under test (fixed clock).
      _scheduleNextMinute();
    }
  }

  @override
  void didUpdateWidget(covariant DayTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pxPerMinute != widget.pxPerMinute) {
      _pxPerMinute = widget.pxPerMinute;
    }
  }

  void _scheduleNextMinute() {
    final now = DateTime.now();
    final delay = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleNextMinute();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
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
    final foldingState = _TimelineFoldingState.fromBlocks(
      blocks: [...widget.draft.blocks, ...actualBlocks],
      dayDate: widget.draft.dayDate,
      startHour: widget.startHour,
      endHour: widget.endHour,
      expandedRegionStarts: _expandedFoldRegionStarts,
      collapsedHourHeight: tokens.spacing.step3,
    );
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
    final timeRailWidth = tokens.spacing.step10;

    return LayoutBuilder(
      builder: (context, constraints) {
        final comparisonMode = _comparisonModeForWidth(constraints.maxWidth);
        return Column(
          children: [
            _TimelineToolbar(
              mode: comparisonMode,
              onToggleMode: _toggleComparisonMode,
            ),
            _TimeSpentSummary(blocks: _actualBlocksForSummary()),
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
                          child: _FoldRegionLayer(
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

  List<TimeBlock> _actualBlocksForSummary() {
    final actualBlocks = widget.actualBlocks ?? widget.draft.actualBlocks;
    if (actualBlocks.isNotEmpty) return actualBlocks;
    return widget.draft.blocks
        .where(
          (block) =>
              block.state == TimeBlockState.completed ||
              block.state == TimeBlockState.inProgress,
        )
        .toList();
  }

  void _toggleComparisonMode() {
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

enum _TimelineComparisonMode { paged, both }

class _TimelineFoldingState {
  _TimelineFoldingState({
    required this.startHour,
    required this.endHour,
    required this.segments,
  });
  factory _TimelineFoldingState.fromBlocks({
    required List<TimeBlock> blocks,
    required DateTime dayDate,
    required int startHour,
    required int endHour,
    required Set<int> expandedRegionStarts,
    required double collapsedHourHeight,
  }) {
    final occupiedHours = <int>{};
    final dayStart = DateTime(dayDate.year, dayDate.month, dayDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    for (final block in blocks) {
      final effectiveStart = block.start.isBefore(dayStart)
          ? dayStart
          : block.start;
      final effectiveEnd = block.end.isAfter(dayEnd) ? dayEnd : block.end;
      if (!effectiveStart.isBefore(effectiveEnd)) continue;

      final start = effectiveStart.hour;
      final end = effectiveEnd == dayEnd
          ? 24
          : effectiveEnd.hour + (effectiveEnd.minute > 0 ? 1 : 0);
      if (start >= endHour || end <= startHour) continue;

      final clampedStart = start.clamp(startHour, endHour - 1);
      final clampedEnd = end.clamp(startHour + 1, endHour);
      for (var hour = clampedStart; hour < clampedEnd; hour++) {
        occupiedHours.add(hour);
      }
    }

    if (occupiedHours.isEmpty) {
      return _TimelineFoldingState(
        startHour: startHour,
        endHour: endHour,
        segments: [
          _TimelineVisibleRegion(startHour: startHour, endHour: endHour),
        ],
      );
    }

    final sortedHours = occupiedHours.toList()..sort();
    final clusters = <_TimelineVisibleRegion>[];
    var clusterStart = sortedHours.first;
    var clusterEnd = clusterStart + 1;

    for (var i = 1; i < sortedHours.length; i++) {
      final hour = sortedHours[i];
      if (hour <= clusterEnd) {
        clusterEnd = hour + 1;
        continue;
      }

      final gap = hour - clusterEnd;
      if (gap >= _gapThresholdHours) {
        clusters.add(
          _TimelineVisibleRegion(startHour: clusterStart, endHour: clusterEnd),
        );
        clusterStart = hour;
      }
      clusterEnd = hour + 1;
    }
    clusters.add(
      _TimelineVisibleRegion(startHour: clusterStart, endHour: clusterEnd),
    );

    if (clusters.first.startHour - startHour < _gapThresholdHours) {
      clusters[0] = _TimelineVisibleRegion(
        startHour: startHour,
        endHour: clusters.first.endHour,
      );
    }

    final lastCluster = clusters.last;
    if (endHour - lastCluster.endHour < _gapThresholdHours) {
      clusters[clusters.length - 1] = _TimelineVisibleRegion(
        startHour: lastCluster.startHour,
        endHour: endHour,
      );
    }

    final segments = <_TimelineRegion>[];
    var cursor = startHour;
    for (final cluster in clusters) {
      if (cluster.startHour - cursor >= _gapThresholdHours) {
        segments.add(
          _TimelineFoldRegion(
            startHour: cursor,
            endHour: cluster.startHour,
            isExpanded: expandedRegionStarts.contains(cursor),
            collapsedHourHeight: collapsedHourHeight,
          ),
        );
      }
      segments.add(cluster);
      cursor = cluster.endHour;
    }

    if (endHour - cursor >= _gapThresholdHours) {
      segments.add(
        _TimelineFoldRegion(
          startHour: cursor,
          endHour: endHour,
          isExpanded: expandedRegionStarts.contains(cursor),
          collapsedHourHeight: collapsedHourHeight,
        ),
      );
    }

    return _TimelineFoldingState(
      startHour: startHour,
      endHour: endHour,
      segments: segments,
    );
  }

  static const _gapThresholdHours = 4;
  final int startHour;
  final int endHour;
  final List<_TimelineRegion> segments;

  Iterable<_TimelineFoldRegion> get compressedRegions =>
      segments.whereType<_TimelineFoldRegion>();

  List<int> get visibleHourLabels {
    final labels = <int>{};
    for (final segment in segments) {
      if (segment is _TimelineFoldRegion && !segment.isExpanded) continue;
      for (var hour = segment.startHour; hour <= segment.endHour; hour++) {
        labels.add(hour);
      }
    }
    return labels.toList()..sort();
  }

  double totalHeight(double pxPerMinute) {
    return segments.fold<double>(
      0,
      (height, segment) => height + segment.height(pxPerMinute),
    );
  }

  double positionForDate(
    DateTime date, {
    required DateTime windowStart,
    required double pxPerMinute,
  }) {
    final rawHour = startHour + date.difference(windowStart).inMinutes / 60.0;
    return positionForHourValue(
      rawHour.clamp(startHour.toDouble(), endHour.toDouble()),
      pxPerMinute,
    );
  }

  double positionForHour(int hour, double pxPerMinute) {
    return positionForHourValue(hour.toDouble(), pxPerMinute);
  }

  double positionForHourValue(double hourValue, double pxPerMinute) {
    var position = 0.0;
    for (final segment in segments) {
      if (hourValue <= segment.startHour) return position;
      if (hourValue <= segment.endHour) {
        final hoursIntoSegment = hourValue - segment.startHour;
        return position + segment.hourHeight(pxPerMinute) * hoursIntoSegment;
      }
      position += segment.height(pxPerMinute);
    }
    return position;
  }
}

sealed class _TimelineRegion {
  const _TimelineRegion({
    required this.startHour,
    required this.endHour,
  });

  final int startHour;
  final int endHour;

  int get hourCount => endHour - startHour;

  double hourHeight(double pxPerMinute);

  double height(double pxPerMinute) => hourCount * hourHeight(pxPerMinute);
}

class _TimelineVisibleRegion extends _TimelineRegion {
  const _TimelineVisibleRegion({
    required super.startHour,
    required super.endHour,
  });

  @override
  double hourHeight(double pxPerMinute) => 60 * pxPerMinute;
}

class _TimelineFoldRegion extends _TimelineRegion {
  const _TimelineFoldRegion({
    required super.startHour,
    required super.endHour,
    required this.isExpanded,
    required this.collapsedHourHeight,
  });

  final bool isExpanded;
  final double collapsedHourHeight;

  @override
  double hourHeight(double pxPerMinute) =>
      isExpanded ? 60 * pxPerMinute : collapsedHourHeight;
}

class _TimelineToolbar extends StatelessWidget {
  const _TimelineToolbar({
    required this.mode,
    required this.onToggleMode,
  });

  final _TimelineComparisonMode mode;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final showingBoth = mode == _TimelineComparisonMode.both;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              showingBoth
                  ? messages.dailyOsNextTimelineBoth
                  : messages.dailyOsNextTimelineSwipeHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ),
          Tooltip(
            message: showingBoth
                ? messages.dailyOsNextTimelineShowPaged
                : messages.dailyOsNextTimelineShowBoth,
            child: IconButton(
              onPressed: onToggleMode,
              icon: Icon(
                showingBoth
                    ? Icons.view_carousel_outlined
                    : Icons.view_week_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSpentSummary extends StatelessWidget {
  const _TimeSpentSummary({required this.blocks});

  final List<TimeBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final totalMinutes = blocks.fold<int>(
      0,
      (sum, block) => sum + block.duration.inMinutes,
    );
    final completedTaskIds = blocks
        .where((block) => block.state == TimeBlockState.completed)
        .map((block) => block.taskId ?? block.id)
        .toSet();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step2,
      ),
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  messages.dailyOsNextTimeSpentTitle,
                  style: tokens.typography.styles.others.overline.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
              Text(
                messages.dailyOsNextTimeSpentSummary(
                  _formatMinutes(totalMinutes),
                  completedTaskIds.length,
                ),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          if (blocks.isEmpty)
            Text(
              messages.dailyOsNextTimeSpentEmpty,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            )
          else
            _ActualCategoryBars(blocks: blocks),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _ActualCategoryBars extends StatelessWidget {
  const _ActualCategoryBars({required this.blocks});

  final List<TimeBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final totals = <String, ({DayAgentCategory category, int minutes})>{};
    for (final block in blocks) {
      final existing = totals[block.category.id];
      totals[block.category.id] = (
        category: block.category,
        minutes: (existing?.minutes ?? 0) + block.duration.inMinutes,
      );
    }
    final entries = totals.values.toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    final maxMinutes = entries.first.minutes == 0 ? 1 : entries.first.minutes;
    return Column(
      children: [
        for (final entry in entries) ...[
          Row(
            children: [
              SizedBox(
                width: tokens.spacing.step9,
                child: Text(
                  entry.category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radii.xs),
                  child: LinearProgressIndicator(
                    minHeight: tokens.spacing.step2,
                    value: entry.minutes / maxMinutes,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      categoryColorFromHex(entry.category.colorHex),
                    ),
                    backgroundColor: tokens.colors.background.level03,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Text(
                _formatMinutes(entry.minutes),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ),
          if (entry != entries.last) SizedBox(height: tokens.spacing.step2),
        ],
      ],
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _TimelinePane extends StatelessWidget {
  const _TimelinePane({
    required this.label,
    required this.blocks,
    required this.bands,
    required this.paneKey,
    required this.foldingState,
    required this.labelHeight,
    required this.totalHeight,
    required this.windowStart,
    required this.pxPerMinute,
    required this.now,
    required this.showBands,
  });

  final String label;
  final List<TimeBlock> blocks;
  final List<EnergyBand> bands;
  final Key paneKey;
  final _TimelineFoldingState foldingState;
  final double labelHeight;
  final double totalHeight;
  final DateTime windowStart;
  final double pxPerMinute;
  final DateTime? now;
  final bool showBands;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: labelHeight,
          child: Padding(
            padding: EdgeInsets.only(left: tokens.spacing.step5),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                label,
                style: tokens.typography.styles.others.overline.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          key: paneKey,
          height: totalHeight + tokens.spacing.step5,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (showBands)
                  for (final band in bands)
                    _EnergyBandBox(
                      band: band,
                      windowStart: windowStart,
                      foldingState: foldingState,
                      pxPerMinute: pxPerMinute,
                    ),
                for (final block in blocks)
                  _BlockPosition(
                    block: block,
                    windowStart: windowStart,
                    foldingState: foldingState,
                    pxPerMinute: pxPerMinute,
                  ),
                if (now != null)
                  _NowLine(
                    windowStart: windowStart,
                    now: now!,
                    foldingState: foldingState,
                    pxPerMinute: pxPerMinute,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SharedHourRail extends StatelessWidget {
  const _SharedHourRail({
    required this.foldingState,
    required this.pxPerMinute,
    required this.now,
    required this.windowStart,
    required this.topInset,
  });

  final _TimelineFoldingState foldingState;
  final double pxPerMinute;
  final DateTime? now;
  final DateTime windowStart;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hourLabelStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final hourLabelCenterOffset = tokens.typography.lineHeight.caption / 2;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: tokens.spacing.step2,
          sigmaY: tokens.spacing.step2,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                tokens.colors.background.level01.withValues(alpha: 0.96),
                tokens.colors.background.level01.withValues(alpha: 0.72),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.colors.background.level01.withValues(alpha: 0.56),
                blurRadius: tokens.spacing.step5,
                offset: Offset(tokens.spacing.step1, 0),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final segment in foldingState.segments)
                if (segment is _TimelineFoldRegion && !segment.isExpanded)
                  Positioned(
                    top:
                        topInset +
                        foldingState.positionForHour(
                          segment.startHour,
                          pxPerMinute,
                        ),
                    right: 0,
                    width: tokens.spacing.step1 / 2,
                    height: segment.height(pxPerMinute),
                    child: const SizedBox.shrink(),
                  )
                else
                  Positioned(
                    top:
                        topInset +
                        foldingState.positionForHour(
                          segment.startHour,
                          pxPerMinute,
                        ),
                    right: 0,
                    width: tokens.spacing.step1 / 2,
                    height: segment.height(pxPerMinute),
                    child: ColoredBox(
                      color: tokens.colors.decorative.level01.withValues(
                        alpha: 0.36,
                      ),
                    ),
                  ),
              for (final hour in foldingState.visibleHourLabels)
                Positioned(
                  top:
                      topInset +
                      foldingState.positionForHour(hour, pxPerMinute) -
                      hourLabelCenterOffset,
                  right: tokens.spacing.step6,
                  child: Text(
                    _formatHour(hour),
                    style: hourLabelStyle,
                  ),
                ),
              if (now != null)
                Positioned(
                  top:
                      topInset +
                      foldingState.positionForDate(
                        now!,
                        windowStart: windowStart,
                        pxPerMinute: pxPerMinute,
                      ) -
                      tokens.spacing.step3 -
                      tokens.spacing.step1,
                  right: tokens.spacing.step5,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step2,
                      vertical: tokens.spacing.step1,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.colors.background.level01,
                      borderRadius: BorderRadius.circular(tokens.radii.xs),
                    ),
                    child: Text(
                      _formatNow(now!),
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.alert.error.defaultColor,
                        fontWeight: tokens.typography.weight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatHour(int hour24) {
    final displayHour = hour24 == 24 ? 24 : hour24 % 24;
    return '${displayHour.toString().padLeft(2, '0')}:00';
  }

  String _formatNow(DateTime now) {
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _GridLines extends StatelessWidget {
  const _GridLines({
    required this.foldingState,
    required this.pxPerMinute,
  });

  final _TimelineFoldingState foldingState;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return IgnorePointer(
      child: Stack(
        children: [
          for (final hour in foldingState.visibleHourLabels)
            Positioned(
              top: foldingState.positionForHour(hour, pxPerMinute),
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: tokens.colors.text.lowEmphasis.withValues(alpha: 0.10),
              ),
            ),
        ],
      ),
    );
  }
}

class _FoldRegionLayer extends StatelessWidget {
  const _FoldRegionLayer({
    required this.foldingState,
    required this.pxPerMinute,
    required this.onToggleFoldRegion,
  });

  final _TimelineFoldingState foldingState;
  final double pxPerMinute;
  final ValueChanged<int> onToggleFoldRegion;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final region in foldingState.compressedRegions)
          Positioned(
            top: foldingState.positionForHour(region.startHour, pxPerMinute),
            left: 0,
            right: 0,
            height: region.height(pxPerMinute),
            child: _FoldRegionToggle(
              key: Key(
                'daily_os_timeline_fold_${region.startHour}_${region.endHour}',
              ),
              region: region,
              pxPerMinute: pxPerMinute,
              onTap: () => onToggleFoldRegion(region.startHour),
            ),
          ),
      ],
    );
  }
}

class _FoldRegionToggle extends StatelessWidget {
  const _FoldRegionToggle({
    required this.region,
    required this.pxPerMinute,
    required this.onTap,
    super.key,
  });

  final _TimelineFoldRegion region;
  final double pxPerMinute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (!region.isExpanded) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: _CompressedFoldSurface(
            region: region,
            label: _formatFoldRange(region),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02.withValues(
              alpha: region.isExpanded ? 0.10 : 0.32,
            ),
            border: Border.symmetric(
              horizontal: BorderSide(
                color: tokens.colors.decorative.level01.withValues(
                  alpha: 0.28,
                ),
              ),
            ),
          ),
          child: Stack(
            children: [
              for (var i = 0; i <= region.hourCount; i++)
                Positioned(
                  top: i * region.hourHeight(pxPerMinute),
                  left: 0,
                  right: 0,
                  child: Container(
                    height: tokens.spacing.step1 / 2,
                    color: tokens.colors.decorative.level01.withValues(
                      alpha: 0.10,
                    ),
                  ),
                ),
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step2,
                    vertical: tokens.spacing.step1,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.colors.background.level03.withValues(
                      alpha: 0.88,
                    ),
                    borderRadius: BorderRadius.circular(tokens.radii.xs),
                    border: Border.all(
                      color: tokens.colors.decorative.level01.withValues(
                        alpha: 0.32,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.unfold_less,
                        size: tokens.spacing.step3,
                        color: tokens.colors.text.lowEmphasis,
                      ),
                      SizedBox(width: tokens.spacing.step1),
                      Text(
                        _formatFoldRange(region),
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFoldRange(_TimelineFoldRegion region) {
    String label(int hour, {required bool isRangeEnd}) {
      final displayHour = isRangeEnd && hour == 24 ? 24 : hour % 24;
      return '${displayHour.toString().padLeft(2, '0')}:00';
    }

    return '${label(region.startHour, isRangeEnd: false)}-'
        '${label(region.endHour, isRangeEnd: true)}';
  }
}

class _CompressedFoldSurface extends StatelessWidget {
  const _CompressedFoldSurface({
    required this.region,
    required this.label,
  });

  final _TimelineFoldRegion region;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return CustomPaint(
      painter: _CompressedFoldPainter(
        hourCount: region.hourCount,
        hourHeight: region.collapsedHourHeight,
        foldDepth: tokens.spacing.step3,
        strokeWidth: tokens.spacing.step1 / 2,
        frontColor: tokens.colors.background.level02.withValues(alpha: 0.22),
        backColor: tokens.colors.background.level02.withValues(alpha: 0.12),
        hourLineColor: tokens.colors.decorative.level01.withValues(alpha: 0.18),
        creaseColor: tokens.colors.decorative.level01.withValues(alpha: 0.26),
        spineColor: tokens.colors.text.lowEmphasis.withValues(alpha: 0.54),
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step2,
            vertical: tokens.spacing.step1,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.background.level03.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(tokens.radii.xs),
            border: Border.all(
              color: tokens.colors.decorative.level01.withValues(alpha: 0.32),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.unfold_more,
                size: tokens.spacing.step3,
                color: tokens.colors.text.lowEmphasis,
              ),
              SizedBox(width: tokens.spacing.step1),
              Text(
                label,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompressedFoldPainter extends CustomPainter {
  const _CompressedFoldPainter({
    required this.hourCount,
    required this.hourHeight,
    required this.foldDepth,
    required this.strokeWidth,
    required this.frontColor,
    required this.backColor,
    required this.hourLineColor,
    required this.creaseColor,
    required this.spineColor,
  });

  final int hourCount;
  final double hourHeight;
  final double foldDepth;
  final double strokeWidth;
  final Color frontColor;
  final Color backColor;
  final Color hourLineColor;
  final Color creaseColor;
  final Color spineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final depth = math.min(foldDepth, size.width);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = backColor
        ..style = PaintingStyle.fill,
    );
    final hourLinePaint = Paint()
      ..color = hourLineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final creasePaint = Paint()
      ..color = creaseColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final spinePaint = Paint()
      ..color = spineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final leftSpinePath = Path()..moveTo(0, 0);
    final rightSpinePath = Path()..moveTo(size.width, 0);
    for (var i = 0; i < hourCount; i++) {
      final y0 = i * hourHeight;
      final y1 = math.min((i + 1) * hourHeight, size.height);
      final midY = (y0 + y1) / 2;
      const leftBase = 0.0;
      final leftPeak = depth;
      final rightBase = size.width;
      final rightPeak = size.width - depth;
      final panelPaint = Paint()
        ..color = i.isEven ? frontColor : backColor
        ..style = PaintingStyle.fill;
      final panelPath = Path()
        ..moveTo(leftBase, y0)
        ..lineTo(rightBase, y0)
        ..lineTo(rightPeak, midY)
        ..lineTo(rightBase, y1)
        ..lineTo(leftBase, y1)
        ..lineTo(leftPeak, midY)
        ..close();

      canvas
        ..drawPath(panelPath, panelPaint)
        ..drawLine(Offset(0, y0), Offset(size.width, y0), hourLinePaint)
        ..drawLine(Offset(leftBase, y0), Offset(leftPeak, midY), creasePaint)
        ..drawLine(Offset(leftPeak, midY), Offset(leftBase, y1), creasePaint)
        ..drawLine(Offset(rightBase, y0), Offset(rightPeak, midY), creasePaint)
        ..drawLine(Offset(rightPeak, midY), Offset(rightBase, y1), creasePaint);
      leftSpinePath
        ..lineTo(leftPeak, midY)
        ..lineTo(leftBase, y1);
      rightSpinePath
        ..lineTo(rightPeak, midY)
        ..lineTo(rightBase, y1);
    }

    canvas
      ..drawLine(
        Offset(0, size.height),
        Offset(size.width, size.height),
        hourLinePaint,
      )
      ..drawPath(leftSpinePath, spinePaint)
      ..drawPath(rightSpinePath, spinePaint);
  }

  @override
  bool shouldRepaint(covariant _CompressedFoldPainter oldDelegate) {
    return hourCount != oldDelegate.hourCount ||
        hourHeight != oldDelegate.hourHeight ||
        foldDepth != oldDelegate.foldDepth ||
        strokeWidth != oldDelegate.strokeWidth ||
        frontColor != oldDelegate.frontColor ||
        backColor != oldDelegate.backColor ||
        hourLineColor != oldDelegate.hourLineColor ||
        creaseColor != oldDelegate.creaseColor ||
        spineColor != oldDelegate.spineColor;
  }
}

class _EnergyBandBox extends StatelessWidget {
  const _EnergyBandBox({
    required this.band,
    required this.windowStart,
    required this.foldingState,
    required this.pxPerMinute,
  });

  final EnergyBand band;
  final DateTime windowStart;
  final _TimelineFoldingState foldingState;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final top = foldingState.positionForDate(
      band.start,
      windowStart: windowStart,
      pxPerMinute: pxPerMinute,
    );
    final end = foldingState.positionForDate(
      band.end,
      windowStart: windowStart,
      pxPerMinute: pxPerMinute,
    );
    final height = math.max(0, end - top).toDouble();

    final color = switch (band.level) {
      EnergyLevel.high => tokens.colors.interactive.enabled,
      EnergyLevel.low => tokens.colors.text.lowEmphasis,
      EnergyLevel.secondWind => tokens.colors.alert.info.defaultColor,
    };

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: IgnorePointer(
        child: Semantics(
          label: band.label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.08),
                  color.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockPosition extends StatelessWidget {
  const _BlockPosition({
    required this.block,
    required this.windowStart,
    required this.foldingState,
    required this.pxPerMinute,
  });

  final TimeBlock block;
  final DateTime windowStart;
  final _TimelineFoldingState foldingState;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final top = foldingState.positionForDate(
      block.start,
      windowStart: windowStart,
      pxPerMinute: pxPerMinute,
    );
    final end = foldingState.positionForDate(
      block.end,
      windowStart: windowStart,
      pxPerMinute: pxPerMinute,
    );
    final rawHeight = math.max(0, end - top).toDouble();
    final minimumReadableHeight =
        tokens.typography.lineHeight.bodySmall + tokens.spacing.step2 * 2;
    final preferredGap = tokens.spacing.step1;
    final blockGap = rawHeight > minimumReadableHeight + preferredGap
        ? math.min(preferredGap, rawHeight / 3)
        : 0.0;
    final height = math.max(0, rawHeight - blockGap).toDouble();
    return Positioned(
      top: top + blockGap / 2,
      left: tokens.spacing.step3,
      right: tokens.spacing.step3,
      height: height,
      child: DayBlock(block: block),
    );
  }
}

/// A single placed block on the Day timeline.
class DayBlock extends StatelessWidget {
  const DayBlock({required this.block, super.key});

  final TimeBlock block;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = _categoryColor();
    final isBuffer = block.type == TimeBlockType.buffer;
    final isDrafted = block.state == TimeBlockState.drafted;

    final fill = isBuffer
        ? Colors.transparent
        : category.withValues(alpha: 0.12);
    final leftStripeColor = isBuffer
        ? tokens.colors.text.lowEmphasis.withValues(alpha: 0.32)
        : category;

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: isDrafted
            ? Border.all(
                color: tokens.colors.text.lowEmphasis.withValues(alpha: 0.20),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: leftStripeColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(tokens.radii.m),
                bottomLeft: Radius.circular(tokens.radii.m),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step2,
              ),
              child: _BlockContent(block: block),
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor() => categoryColorFromHex(block.category.colorHex);
}

class _BlockContent extends StatelessWidget {
  const _BlockContent({required this.block});

  final TimeBlock block;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isBuffer = block.type == TimeBlockType.buffer;
    final isCal = block.type == TimeBlockType.cal;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Per the prototype: blocks shorter than 36 px collapse to the
        // title row only. The sub-title row would otherwise overflow
        // the block on 30-min cal events.
        final showSubtitle = !isBuffer && constraints.maxHeight >= 36;
        final titleMaxLines = constraints.maxHeight >= 56 ? 2 : 1;
        return ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCal) ...[
                    Icon(
                      Icons.event_rounded,
                      size: 12,
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    SizedBox(width: tokens.spacing.step1),
                  ],
                  Expanded(
                    child: Text(
                      block.title,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.highEmphasis,
                        fontWeight: FontWeight.w600,
                        fontStyle: isBuffer
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.fade,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              if (block.reason != null &&
                  block.type == TimeBlockType.ai &&
                  constraints.maxHeight >= 72) ...[
                SizedBox(height: tokens.spacing.step1),
                WhyChip(reason: block.reason!),
              ],
              if (showSubtitle)
                Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step1),
                  child: Text(
                    _subTitle(context, block),
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _subTitle(BuildContext context, TimeBlock block) {
    final parts = <String>[_formatRange(block)];
    if (block.sessionIndex != null && block.sessionTotal != null) {
      parts.add(
        context.messages.dailyOsNextTimelineSessionOf(
          block.sessionIndex!,
          block.sessionTotal!,
        ),
      );
    }
    if (block.location != null) parts.add(block.location!);
    return parts.join(' · ');
  }

  String _formatRange(TimeBlock block) {
    return '${_clock(block.start)}–${_clock(block.end)}';
  }

  String _clock(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({
    required this.windowStart,
    required this.now,
    required this.foldingState,
    required this.pxPerMinute,
  });

  final DateTime windowStart;
  final DateTime now;
  final _TimelineFoldingState foldingState;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final red = tokens.colors.alert.error.defaultColor;
    final top = foldingState.positionForDate(
      now,
      windowStart: windowStart,
      pxPerMinute: pxPerMinute,
    );
    return Positioned(
      top: top - 0.75,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: red, shape: BoxShape.circle),
            ),
            Expanded(
              child: Container(height: 1.5, color: red),
            ),
          ],
        ),
      ),
    );
  }
}
