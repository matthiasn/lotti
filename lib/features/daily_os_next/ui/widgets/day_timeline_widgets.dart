part of 'day_timeline.dart';

enum _TimelineComparisonMode { paged, both }

class _TimelineToolbar extends StatelessWidget {
  const _TimelineToolbar({
    required this.mode,
    required this.showHint,
    required this.onToggleMode,
  });

  final _TimelineComparisonMode mode;

  /// One-shot coaching line; retired by the host once the user has
  /// demonstrated the gestures. The mode-toggle icon stays — it is an
  /// affordance, not narration.
  final bool showHint;

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
            child: showHint
                ? Text(
                    showingBoth
                        ? messages.dailyOsNextTimelineBoth
                        : messages.dailyOsNextTimelineSwipeHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  )
                : const SizedBox.shrink(),
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
                  BlockPosition(
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
                  NowLine(
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
                      formatTimelineHourLabel(hour),
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
                        color: tokens.colors.alert.error.defaultColor,
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
