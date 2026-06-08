import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_folding.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/editable_title.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/why_chip.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

part 'day_timeline_block.dart';
part 'day_timeline_fold_surface.dart';

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
    super.key,
  });

  final DraftPlan draft;
  final int startHour;
  final int endHour;
  final double pxPerMinute;

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
    final foldingState = TimelineFoldingState.fromBlocks(
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
    required this.tracked,
    required this.onRenameBlock,
  });

  final String label;
  final List<TimeBlock> blocks;
  final List<EnergyBand> bands;
  final Key paneKey;
  final TimelineFoldingState foldingState;
  final double labelHeight;
  final double totalHeight;
  final DateTime windowStart;
  final double pxPerMinute;
  final DateTime? now;
  final bool showBands;

  /// True for the recorded-sessions pane — its blocks render in the
  /// neutral "tracked" treatment (they already happened).
  final bool tracked;

  final void Function(TimeBlock block, String title)? onRenameBlock;

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
                style: calmEyebrowStyle(tokens),
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
                    tracked: tracked,
                    onRename: onRenameBlock == null
                        ? null
                        : (title) => onRenameBlock!(block, title),
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

  final TimelineFoldingState foldingState;
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
                if (segment is TimelineFoldRegion && !segment.isExpanded)
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
                    formatTimelineHourLabel(hour),
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

  final TimelineFoldingState foldingState;
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

class _EnergyBandBox extends StatelessWidget {
  const _EnergyBandBox({
    required this.band,
    required this.windowStart,
    required this.foldingState,
    required this.pxPerMinute,
  });

  final EnergyBand band;
  final DateTime windowStart;
  final TimelineFoldingState foldingState;
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
