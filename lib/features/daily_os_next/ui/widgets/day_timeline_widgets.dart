part of 'day_timeline.dart';

enum _TimelineComparisonMode { paged, both }

class _TimelineToolbar extends StatelessWidget {
  const _TimelineToolbar({
    required this.mode,
    required this.arrangeMode,
    required this.onToggleMode,
    required this.onToggleArrange,
    required this.timeRailWidth,
    this.leading,
    this.trailing,
    this.lanes,
  });

  /// The hour rail's width: side by side, the toolbar names each lane over
  /// its own column, so it starts its labels where the lanes start.
  final double timeRailWidth;

  /// The paged lanes' controller, while the lanes are pages: the toolbar
  /// then names them with a Plan / Actual toggle that follows the swipe, so
  /// the recorded lane is one visible tap away rather than a gesture to
  /// discover.
  final PageController? lanes;

  /// See [DayTimeline.toolbarLeading]. Takes the lane names' room.
  final Widget? leading;

  /// See [DayTimeline.toolbarTrailing].
  final Widget? trailing;

  final _TimelineComparisonMode mode;
  final bool arrangeMode;

  final VoidCallback onToggleMode;
  final VoidCallback? onToggleArrange;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final showingBoth = mode == _TimelineComparisonMode.both;
    if (showingBoth && leading == null) {
      // Side by side, the toolbar is the lanes' header: each name over its
      // own column, at the tier every group on the page is named at, and
      // pinned, so the names stay in view however far the day scrolls.
      // Arrange sits over the lane it changes, the plan. A lane too narrow
      // for a name and a worded button — a phone shown both lanes, or large
      // text — takes the buttons' glyphs instead.
      Widget name(String text) => Padding(
        padding: EdgeInsets.only(left: tokens.spacing.step5),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          final laneWidth =
              (constraints.maxWidth -
                  timeRailWidth -
                  tokens.spacing.step3 * 2) /
              2;
          final compact =
              laneWidth <
              MediaQuery.textScalerOf(context).scale(_laneWordsMinWidth);
          return Padding(
            padding: EdgeInsets.only(
              left: timeRailWidth,
              right: tokens.spacing.step3,
              top: tokens.spacing.step2,
              bottom: tokens.spacing.step2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: name(messages.dailyOsNextTimelinePlanned),
                      ),
                      if (onToggleArrange case final onToggle?)
                        _fitted(
                          _ArrangeToggle(
                            arranging: arrangeMode,
                            onToggle: onToggle,
                            compact: compact,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: name(messages.dailyOsNextTimelineActual),
                      ),
                      _fitted(
                        _ModeToggle(
                          showingBoth: true,
                          onToggle: onToggleMode,
                          compact: compact,
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    // Paged, on a phone: the lane names start where the rows' words would
    // — on the row inset, less the names' own tap padding — and the buttons
    // keep their words unless the row is too narrow for them.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _wordsMinWidth;
        return Padding(
          padding: EdgeInsetsDirectional.only(
            // Never negative, whatever the tokens.
            start: leading == null
                ? math.max(
                    0,
                    DayRowScaffold.inset(context) - tokens.spacing.step3,
                  )
                : tokens.spacing.step5,
            end: tokens.spacing.step3,
            top: tokens.spacing.step2,
            bottom: tokens.spacing.step2,
          ),
          child: Row(
            children: [
              Expanded(
                child: switch (leading) {
                  final leading? => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: leading,
                  ),
                  // Paged lanes always come with their controller. Where the
                  // row is a few points short, the names shrink to fit
                  // rather than overflow.
                  null => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: _LaneToggle(lanes: lanes!),
                  ),
                },
              ),
              _ModeToggle(
                showingBoth: showingBoth,
                onToggle: onToggleMode,
                compact: compact,
              ),
              if (onToggleArrange case final onToggle?) ...[
                SizedBox(width: tokens.spacing.step2),
                _ArrangeToggle(
                  arranging: arrangeMode,
                  onToggle: onToggle,
                  compact: compact,
                ),
              ],
              ?trailing,
            ],
          ),
        );
      },
    );
  }

  /// The narrowest toolbar that fits the lane names and both buttons with
  /// their words; below it the buttons show their glyphs.
  static const double _wordsMinWidth = 340;

  /// Side by side, the narrowest lane — at the default text size — that fits
  /// its name and a worded button; the threshold grows with the text.
  static const double _laneWordsMinWidth = 200;

  /// A side-by-side header button that shrinks to its lane rather than
  /// overflow it — "Done", which keeps its word, in a lane narrower than the
  /// word at large text.
  static Widget _fitted(Widget button) => Flexible(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerEnd,
      child: button,
    ),
  );
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
    required this.currentTime,
    required this.showBands,
    required this.tracked,
    required this.onRenameBlock,
    required this.onEditBlock,
    required this.isRedacted,
    required this.arrangeMode,
    required this.onRescheduleBlock,
  });

  /// The lane's name over its hours, or null when the toolbar names it.
  final String? label;
  final List<TimeBlock> blocks;
  final List<EnergyBand> bands;
  final Key paneKey;
  final TimelineFoldingState foldingState;
  final double labelHeight;
  final double totalHeight;
  final DateTime windowStart;
  final double pxPerMinute;
  final DateTime? now;

  /// The time now, whether or not the now-line is in this window: blocks
  /// that ended before it are past (see [DayBlock.past]).
  final DateTime currentTime;
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
              child: switch (label) {
                final label? => Text(label, style: calmEyebrowStyle(tokens)),
                null => null,
              },
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
                        past: slot.block.end.isBefore(currentTime),
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

    // A neutral wash, stronger where energy is high: teal and info blue
    // already mean "now" and "selected" on this page, and a band is neither.
    final color = switch (band.level) {
      EnergyLevel.high ||
      EnergyLevel.secondWind => tokens.colors.text.mediumEmphasis,
      EnergyLevel.low => tokens.colors.text.lowEmphasis,
    };

    // Inset by the lane's block edge, so a band sits under the blocks it
    // tints rather than wider than them.
    return Positioned(
      top: top,
      left: tokens.spacing.step3,
      right: tokens.spacing.step3,
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

/// The lane-format toggle, a design-system button like Arrange beside it:
/// "One lane" side by side, "Both lanes" when paged. Where a phone is too
/// narrow for words ([compact]), its glyph alone, with the words as its
/// tooltip and semantics.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.showingBoth,
    required this.onToggle,
    this.compact = false,
  });

  final bool showingBoth;
  final VoidCallback onToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return _ToolbarButton(
      key: const Key('daily_os_timeline_mode_toggle'),
      label: showingBoth
          ? messages.dailyOsNextTimelineOneLane
          : messages.dailyOsNextTimelineBothLanes,
      description: showingBoth
          ? messages.dailyOsNextTimelineShowPaged
          : messages.dailyOsNextTimelineShowBoth,
      icon: showingBoth ? LottiIcons.viewCarousel : LottiIcons.viewColumns,
      compact: compact,
      onPressed: onToggle,
    );
  }
}

/// Arrange, in words wherever they fit — a touch screen has no tooltip to
/// explain a glyph. While arranging it is the filled "Done", so the mode
/// cannot be missed and the way out is in plain sight.
class _ArrangeToggle extends StatelessWidget {
  const _ArrangeToggle({
    required this.arranging,
    required this.onToggle,
    this.compact = false,
  });

  final bool arranging;
  final VoidCallback onToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return _ToolbarButton(
      key: const Key('daily_os_timeline_arrange_toggle'),
      label: arranging
          ? messages.doneButton
          : messages.dailyOsNextTimelineArrangeShort,
      description: messages.dailyOsNextTimelineArrange,
      icon: arranging ? LottiIcons.confirm : LottiIcons.drag,
      primary: arranging,
      // Done keeps its word even on the narrowest phone: it is the way out.
      compact: compact && !arranging,
      onPressed: onToggle,
    );
  }
}

/// One dense design-system button of the timeline toolbar, secondary unless
/// [primary]; [compact] drops the label for the glyph, keeping the label's
/// meaning in a tooltip and the [description] as its semantics.
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.compact = false,
    super.key,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final button = DesignSystemButton(
      label: compact ? '' : label,
      semanticsLabel: description,
      leadingIcon: icon,
      variant: primary
          ? DesignSystemButtonVariant.primary
          : DesignSystemButtonVariant.secondary,
      size: DesignSystemButtonSize.dense,
      tapTargetSize: MaterialTapTargetSize.padded,
      onPressed: onPressed,
    );
    return compact ? Tooltip(message: label, child: button) : button;
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

/// Plan · Actual over the phone's paged lanes, named at the tier the page's
/// groups are (subtitle1) — not a second pill under the page's tabs. The lane in view is
/// high-emphasis over a teal `step1` underline, as a selected tab is; the
/// other is low-emphasis. The names follow the pager, and a tap pages to
/// the lane named.
class _LaneToggle extends StatelessWidget {
  const _LaneToggle({required this.lanes});

  final PageController lanes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return AnimatedBuilder(
      animation: lanes,
      builder: (context, _) {
        final page = lanes.hasClients && lanes.position.haveDimensions
            ? lanes.page!
            : lanes.initialPage.toDouble();
        final shown = page.round();
        Widget lane(int index, String name) {
          final selected = index == shown;
          return Semantics(
            key: Key('daily_os_timeline_lane_$index'),
            button: true,
            selected: selected,
            child: InkWell(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              onTap: () => lanes.animateToPage(
                index,
                duration: MotionDurations.medium1,
                curve: MotionCurves.standard,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: TapTargets.minimum,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step3,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: tokens.typography.styles.subtitle.subtitle1
                            .copyWith(
                              color: selected
                                  ? tokens.colors.text.highEmphasis
                                  : tokens.colors.text.lowEmphasis,
                            ),
                      ),
                      SizedBox(height: tokens.spacing.step1),
                      // Every name reserves the line, so selecting one
                      // never shifts the other.
                      Container(
                        height: tokens.spacing.step1,
                        width: tokens.spacing.step6,
                        decoration: BoxDecoration(
                          color: selected
                              ? tokens.colors.interactive.enabled
                              : null,
                          borderRadius: BorderRadius.circular(
                            tokens.radii.badgesPills,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Its own sheet for the names' ink, wherever the timeline is hosted.
        return Material(
          type: MaterialType.transparency,
          child: Row(
            key: const Key('daily_os_timeline_lane_toggle'),
            mainAxisSize: MainAxisSize.min,
            children: [
              lane(0, messages.dailyOsNextTimelinePlanned),
              lane(1, messages.dailyOsNextTimelineActual),
            ],
          ),
        );
      },
    );
  }
}
