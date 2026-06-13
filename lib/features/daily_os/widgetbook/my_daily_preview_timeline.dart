part of 'my_daily_widgetbook.dart';

class _MyDailyTimeline extends StatelessWidget {
  const _MyDailyTimeline({
    required this.state,
    required this.now,
    required this.selectedCategoryIds,
    required this.filterEnabled,
  });

  final DailyOsState state;
  final DateTime now;
  final Set<String> selectedCategoryIds;
  final bool filterEnabled;

  @override
  Widget build(BuildContext context) {
    final sections = _buildTimelineSections(context);
    final blocks = _buildTimelineBlockSpecs(context);
    final showFilter = filterEnabled && selectedCategoryIds.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var hour = 7; hour <= 26; hour++)
          Positioned(
            left: 0,
            right: 0,
            top:
                _myDailyTimelineHourRowTop +
                ((hour - 7) * _myDailyTimelineHourRowHeight),
            child: _MyDailyTimelineHourRule(hour: hour),
          ),
        for (final section in sections)
          Positioned(
            left: _myDailyTimelinePanelLeft,
            top: section.top,
            width: _myDailyTimelinePanelWidth,
            height: section.height,
            child: Opacity(
              key: Key('my-daily-category-opacity-${section.filterId}'),
              opacity: _resolveTimelineOpacity(
                filterId: section.filterId,
                selectedCategoryIds: selectedCategoryIds,
                showFilter: showFilter,
              ),
              child: _MyDailyTimelineSectionPanel(section: section),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _MyDailyTimelineConnectorPainter(
                blocks: blocks,
                selectedCategoryIds: selectedCategoryIds,
                showFilter: showFilter,
              ),
            ),
          ),
        ),
        for (final block in blocks)
          Positioned(
            left: block.left,
            top: block.top,
            width: block.width,
            height: block.height,
            child: Opacity(
              opacity: _resolveTimelineOpacity(
                filterId: block.filterId,
                selectedCategoryIds: selectedCategoryIds,
                showFilter: showFilter,
              ),
              child: _MyDailyTimelineBlock(block: block),
            ),
          ),
        if (DateUtils.dateOnly(now) == DateUtils.dateOnly(state.selectedDate))
          Positioned(
            left: 0,
            right: 0,
            top: _myDailyTimelineNowIndicatorTop,
            child: _NowIndicator(now: now),
          ),
      ],
    );
  }
}

class _MyDailyTimelineHourRule extends StatelessWidget {
  const _MyDailyTimelineHourRule({required this.hour});

  final int hour;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final uses24HourClock = _uses24HourClock(context);
    final labelWidth = uses24HourClock ? 18.0 : _myDailyTimelineLabelLineOffset;
    final lineInset = _myDailyTimelineLabelLineOffset - labelWidth;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            _formatTimelineHour(context, hour),
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.right,
            style: tokens.typography.styles.others.overline.copyWith(
              color: Colors.white.withValues(alpha: 0.32),
              fontSize: 10,
              height: 1,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 7, left: lineInset),
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyDailyTimelineSectionPanel extends StatelessWidget {
  const _MyDailyTimelineSectionPanel({required this.section});

  final _MyDailyTimelineSectionSpec section;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            section.color.withValues(alpha: 0.18),
            section.color.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: section.color.withValues(alpha: 0.26),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _myDailyTimelineBandWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.28),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _myDailyTimelineBandWidth,
            child: RotatedBox(
              quarterTurns: 3,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        section.icon,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        section.label,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyDailyTimelineBlock extends StatelessWidget {
  const _MyDailyTimelineBlock({required this.block});

  final _MyDailyTimelineBlockSpec block;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('my-daily-block-${block.id}'),
      decoration: BoxDecoration(
        color: block.fillColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: block.strokeColor),
        boxShadow: block.glowColor == null
            ? null
            : [
                BoxShadow(
                  color: block.glowColor!,
                  blurRadius: 4,
                ),
              ],
      ),
      child: Padding(
        padding: block.padding,
        child: switch (block.style) {
          _MyDailyTimelineBlockStyle.detailed => _MyDailyDetailedBlockContent(
            block: block,
          ),
          _MyDailyTimelineBlockStyle.pill => _MyDailyPillBlockContent(
            block: block,
          ),
          _MyDailyTimelineBlockStyle.split => _MyDailySplitBlockContent(
            block: block,
          ),
        },
      ),
    );
  }
}

class _MyDailyDetailedBlockContent extends StatelessWidget {
  const _MyDailyDetailedBlockContent({required this.block});

  final _MyDailyTimelineBlockSpec block;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('my-daily-block-layout-${block.id}-${block.density.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      block.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _timelineBlockTitleStyle,
                    ),
                  ),
                  if (block.badgeLabel != null) ...[
                    const SizedBox(width: 4),
                    _TimelineBadge(
                      label: block.badgeLabel!,
                      tint: block.badgeColor ?? _myDailyDefaultBadgeColor,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _TimelineTrailingLabel(
              label: block.trailingLabel,
              showWarning: block.showWarning,
            ),
          ],
        ),
        if (block.subtitle != null) ...[
          const SizedBox(height: 2),
          _TimelineIconText(
            label: block.subtitle!,
            icon: Icons.schedule_rounded,
          ),
        ],
        if (block.metaLabel != null) ...[
          const SizedBox(height: 2),
          _TimelineIconText(
            label: block.metaLabel!,
            icon: Icons.timelapse_rounded,
          ),
        ],
      ],
    );
  }
}

class _MyDailyPillBlockContent extends StatelessWidget {
  const _MyDailyPillBlockContent({required this.block});

  final _MyDailyTimelineBlockSpec block;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('my-daily-block-layout-${block.id}-${block.density.name}'),
      children: [
        Expanded(
          child: Row(
            children: [
              if (block.leadingIcon != null) ...[
                Icon(
                  block.leadingIcon,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.64),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  block.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _timelineBlockTitleStyle,
                ),
              ),
              if (block.inlineChip != null) ...[
                const SizedBox(width: 6),
                _TimelineInlineChip(chip: block.inlineChip!),
              ],
              if (block.metaLabel != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: _TimelineIconText(
                    label: block.metaLabel!,
                    icon: Icons.timelapse_rounded,
                    inline: true,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _TimelineTrailingLabel(
          label: block.trailingLabel,
          showWarning: block.showWarning,
        ),
      ],
    );
  }
}

class _MyDailySplitBlockContent extends StatelessWidget {
  const _MyDailySplitBlockContent({required this.block});

  final _MyDailyTimelineBlockSpec block;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('my-daily-block-layout-${block.id}-${block.density.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _TimelineIconText(
                label: block.title,
                icon: Icons.schedule_rounded,
                inline: true,
              ),
            ),
            const SizedBox(width: 8),
            _TimelineTrailingLabel(
              label: block.trailingLabel,
              showWarning: block.showWarning,
            ),
          ],
        ),
        if (block.metaLabel != null) ...[
          const SizedBox(height: 4),
          _TimelineIconText(
            label: block.metaLabel!,
            icon: Icons.timelapse_rounded,
          ),
        ],
      ],
    );
  }
}

class _TimelineIconText extends StatelessWidget {
  const _TimelineIconText({
    required this.label,
    required this.icon,
    this.inline = false,
  });

  final String label;
  final IconData icon;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Icon(
          icon,
          size: 12,
          color: Colors.white.withValues(alpha: 0.32),
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _timelineBlockMetaStyle,
          ),
        ),
      ],
    );
  }
}

class _TimelineInlineChip extends StatelessWidget {
  const _TimelineInlineChip({required this.chip});

  final _TimelineInlineChipSpec chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: chip.width,
      height: 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: chip.color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: chip.label == null
          ? null
          : Text(
              chip.label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _timelineChipLabelStyle,
            ),
    );
  }
}

class _TimelineTrailingLabel extends StatelessWidget {
  const _TimelineTrailingLabel({
    required this.label,
    required this.showWarning,
  });

  final String label;
  final bool showWarning;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showWarning) ...[
          const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: Color(0xFFFFB43A),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: _timelineTrailingStyle,
        ),
      ],
    );
  }
}

class _TimelineBadge extends StatelessWidget {
  const _TimelineBadge({
    required this.label,
    required this.tint,
  });

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: _timelineChipLabelStyle.copyWith(
          color: const Color(0xFF122029),
        ),
      ),
    );
  }
}
