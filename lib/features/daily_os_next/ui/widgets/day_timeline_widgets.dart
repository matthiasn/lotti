part of 'day_timeline.dart';

enum _TimelineComparisonMode { paged, both }

class _TimelineToolbar extends StatelessWidget {
  const _TimelineToolbar({
    required this.mode,
    required this.arrangeMode,
    required this.showHint,
    required this.onToggleMode,
    required this.onToggleArrange,
    this.leading,
    this.trailing,
    this.lanes,
  });

  /// The paged lanes' controller, while the lanes are pages: the toolbar
  /// then names them with a Plan / Actual toggle that follows the swipe, so
  /// the recorded lane is one visible tap away rather than a gesture to
  /// discover.
  final PageController? lanes;

  /// See [DayTimeline.toolbarLeading]. Takes the coaching line's room.
  final Widget? leading;

  /// See [DayTimeline.toolbarTrailing].
  final Widget? trailing;

  final _TimelineComparisonMode mode;
  final bool arrangeMode;

  /// One-shot coaching line; retired by the host once the user has
  /// demonstrated the gestures. The mode-toggle icon stays — it is an
  /// affordance, not narration.
  final bool showHint;

  final VoidCallback onToggleMode;
  final VoidCallback? onToggleArrange;

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
            child: switch (leading) {
              final leading? => Align(
                alignment: AlignmentDirectional.centerStart,
                child: leading,
              ),
              // On a 320 pt phone the two labels and the control buttons
              // want a few points more than the row has: the toggle shrinks
              // to fit rather than overflow.
              null when lanes != null => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: _LaneToggle(lanes: lanes!),
              ),
              // Side by side, the lanes need no switch: a one-shot line
              // names what the two columns are.
              null when showHint && showingBoth => Text(
                messages.dailyOsNextTimelineBoth,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
              null => const SizedBox.shrink(),
            },
          ),
          _TimelineControlButtons(
            showingBoth: showingBoth,
            arrangeMode: arrangeMode,
            onToggleMode: onToggleMode,
            onToggleArrange: onToggleArrange,
          ),
          ?trailing,
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
    required this.onEditBlock,
    required this.isRedacted,
    required this.arrangeMode,
    required this.onRescheduleBlock,
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
  final ValueChanged<TimeBlock>? onEditBlock;
  final bool Function(TimeBlock block)? isRedacted;
  final bool arrangeMode;
  final Future<bool> Function(
    TimeBlock block,
    DateTime start,
    DateTime end,
  )?
  onRescheduleBlock;

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
            // The lane's width decides how peer columns and cascade indents
            // resolve to pixels, so the overlap layout is built inside it.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slots = layoutTimelineBlocks(
                  blocks,
                  peerWindow: _peerWindow(
                    tokens,
                    textScaler: MediaQuery.textScalerOf(context),
                  ),
                );
                final insets = resolveTimelineBlockInsets(
                  slots,
                  laneWidth: constraints.maxWidth,
                  edgeInset: tokens.spacing.step3,
                  indent: tokens.spacing.step5,
                  columnGap: tokens.spacing.step2,
                );
                return Stack(
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
                    // Slots come in paint order: floor first, raised later.
                    for (final slot in slots)
                      BlockPosition(
                        key: ValueKey('daily-os-position-${slot.block.id}'),
                        block: slot.block,
                        horizontal: insets[slot.block.id]!,
                        raised: slot.isRaised,
                        windowStart: windowStart,
                        foldingState: foldingState,
                        pxPerMinute: pxPerMinute,
                        tracked: tracked,
                        onRename: onRenameBlock == null
                            ? null
                            : (title) => onRenameBlock!(slot.block, title),
                        onEdit: onEditBlock,
                        arrangeMode: arrangeMode,
                        onReschedule: onRescheduleBlock,
                        redacted: isRedacted?.call(slot.block) ?? false,
                      ),
                    if (now != null)
                      NowLine(
                        windowStart: windowStart,
                        now: now!,
                        foldingState: foldingState,
                        pxPerMinute: pxPerMinute,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// How far apart two overlapping blocks must start before the later one
  /// can sit on top of the earlier without hiding its title: the readable
  /// block height — at the user's text scale — in minutes at the current
  /// zoom. Zooming out or enlarging text widens the window and turns a tight
  /// cascade into side-by-side columns.
  Duration _peerWindow(DsTokens tokens, {required TextScaler textScaler}) =>
      Duration(
        minutes:
            (minimumReadableBlockHeight(tokens, textScaler: textScaler) /
                    pxPerMinute)
                .ceil(),
      );
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

  static const _nowDotSize = 6.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final textScaler = MediaQuery.textScalerOf(context);
    final hourLabelStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final hourLabelExtent = textScaler.scale(
      tokens.typography.lineHeight.caption,
    );
    final hourLabelCenterOffset = hourLabelExtent / 2;
    // The chip is one bodySmall line plus step1 padding top and bottom.
    final nowChipExtent =
        textScaler.scale(tokens.typography.lineHeight.bodySmall) +
        tokens.spacing.step2;
    // Labels whose center sits closer to the now-line than half the
    // combined label+chip extents (plus a breathing gap) would be half
    // occluded by the chip — a sheared "16:00" reads as a rendering bug
    // on the rail's marquee element, so suppress those labels.
    final hourLabelCollisionBand =
        (hourLabelExtent + nowChipExtent) / 2 + tokens.spacing.step2;
    final nowTop = now == null
        ? null
        : foldingState.positionForDate(
            now!,
            windowStart: windowStart,
            pxPerMinute: pxPerMinute,
          );
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
                if (segment is! TimelineFoldRegion || segment.isExpanded)
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
                if (nowTop == null ||
                    (foldingState.positionForHour(hour, pxPerMinute) - nowTop)
                            .abs() >
                        hourLabelCollisionBand)
                  Positioned(
                    top:
                        topInset +
                        foldingState.positionForHour(hour, pxPerMinute) -
                        hourLabelCenterOffset,
                    right: tokens.spacing.step6,
                    child: Text(
                      formatTimelineHourLabel(context, hour),
                      style: hourLabelStyle,
                    ),
                  ),
              if (nowTop != null) ...[
                // The single now-dot lives on the rail (not per pane) so
                // the peeking page in swipe mode never shows a stray
                // second dot mid-screen; panes draw only the line.
                Positioned(
                  top: topInset + nowTop - _nowDotSize / 2,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: _nowDotSize,
                      height: _nowDotSize,
                      decoration: BoxDecoration(
                        color: tokens.colors.interactive.enabled,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: topInset + nowTop - nowChipExtent / 2,
                  right: tokens.spacing.step5,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step2,
                      vertical: tokens.spacing.step1,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.colors.interactive.enabled,
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                    ),
                    child: Text(
                      formatClock(context, now!),
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.onInteractiveAlert,
                        fontWeight: tokens.typography.weight.semiBold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
                color: tokens.colors.decorative.level01,
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

/// The lane-format toggle and, when the timeline can arrange, the arrange
/// toggle — the same two buttons wherever they are shown.
class _TimelineControlButtons extends StatelessWidget {
  const _TimelineControlButtons({
    required this.showingBoth,
    required this.arrangeMode,
    required this.onToggleMode,
    required this.onToggleArrange,
  });

  final bool showingBoth;
  final bool arrangeMode;
  final VoidCallback onToggleMode;
  final VoidCallback? onToggleArrange;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: showingBoth
              ? messages.dailyOsNextTimelineShowPaged
              : messages.dailyOsNextTimelineShowBoth,
          child: IconButton(
            key: const Key('daily_os_timeline_mode_toggle'),
            iconSize: context.designTokens.typography.size.subtitle1,
            onPressed: onToggleMode,
            icon: Icon(
              showingBoth ? LottiIcons.viewCarousel : LottiIcons.viewColumns,
            ),
          ),
        ),
        if (onToggleArrange != null)
          Tooltip(
            message: messages.dailyOsNextTimelineArrange,
            child: IconButton(
              key: const Key('daily_os_timeline_arrange_toggle'),
              iconSize: context.designTokens.typography.size.subtitle1,
              isSelected: arrangeMode,
              onPressed: onToggleArrange,
              // Selected, the button says how to finish: done arranging.
              selectedIcon: const Icon(LottiIcons.confirm),
              icon: const Icon(LottiIcons.drag),
            ),
          ),
      ],
    );
  }
}

/// One lane of the phone's paged timeline, revealed in step with the swipe.
///
/// The pager shows a sliver of the next lane as a cue that there is one, but
/// at full width that sliver cut its blocks to two-letter fragments. Here a
/// lane that is a whole page away shows only its leading `step3` — the
/// blocks' colour stripes — and opens up as it slides into view. The clip
/// also bounds hit-testing, so the cue cannot be tapped by accident.
class _PagedLane extends StatelessWidget {
  const _PagedLane({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cue = context.designTokens.spacing.step3;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final page = controller.hasClients && controller.position.haveDimensions
            ? controller.page ?? controller.initialPage.toDouble()
            : controller.initialPage.toDouble();
        final away = (page - index).abs().clamp(0.0, 1.0);
        return ClipRect(
          clipper: _LeadingClip(open: 1 - away, minWidth: cue),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _LeadingClip extends CustomClipper<Rect> {
  const _LeadingClip({required this.open, required this.minWidth});

  /// How much of the lane is revealed, from 0 (only [minWidth]) to 1 (all).
  final double open;
  final double minWidth;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0,
    0,
    math.max(minWidth, size.width * open),
    size.height,
  );

  @override
  bool shouldReclip(_LeadingClip oldClipper) =>
      oldClipper.open != open || oldClipper.minWidth != minWidth;
}

/// Plan | Actual over the phone's paged lanes: the selected segment follows
/// the pager, and a tap pages to the other lane.
class _LaneToggle extends StatelessWidget {
  const _LaneToggle({required this.lanes});

  final PageController lanes;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return AnimatedBuilder(
      animation: lanes,
      builder: (context, _) {
        final page = lanes.hasClients && lanes.position.haveDimensions
            ? lanes.page ?? lanes.initialPage.toDouble()
            : lanes.initialPage.toDouble();
        return DsSegmentedToggle<int>(
          key: const Key('daily_os_timeline_lane_toggle'),
          selected: page.round(),
          onChanged: (lane) => lanes.animateToPage(
            lane,
            duration: MotionDurations.medium1,
            curve: MotionCurves.standard,
          ),
          segments: [
            DsSegment(0, messages.dailyOsNextTimelinePlanned),
            DsSegment(1, messages.dailyOsNextTimelineActual),
          ],
        );
      },
    );
  }
}
