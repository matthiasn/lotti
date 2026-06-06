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

class _MyDailyTimelineConnectorPainter extends CustomPainter {
  const _MyDailyTimelineConnectorPainter({
    required this.blocks,
    required this.selectedCategoryIds,
    required this.showFilter,
  });

  final List<_MyDailyTimelineBlockSpec> blocks;
  final Set<String> selectedCategoryIds;
  final bool showFilter;

  @override
  void paint(Canvas canvas, Size size) {
    final groups = <String, List<_MyDailyTimelineBlockSpec>>{};
    for (final block in blocks) {
      final connectorGroupId = block.connectorGroupId;
      if (connectorGroupId == null) {
        continue;
      }
      groups.putIfAbsent(connectorGroupId, () => []).add(block);
    }

    for (final entries in groups.values) {
      entries.sort((left, right) => left.top.compareTo(right.top));
      for (var index = 0; index < entries.length - 1; index++) {
        final current = entries[index];
        final next = entries[index + 1];
        final opacity = _resolveTimelineOpacity(
          filterId: current.filterId,
          selectedCategoryIds: selectedCategoryIds,
          showFilter: showFilter,
        );
        final paint = Paint()
          ..color = current.strokeColor.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _myDailyTimelineConnectorStrokeWidth;
        final connectorX =
            math.max(current.left + current.width, next.left + next.width) +
            _myDailyTimelineConnectorInset;
        final currentCenterY = current.top + (current.height / 2);
        final nextCenterY = next.top + (next.height / 2);
        final path = Path()
          ..moveTo(current.left + current.width, currentCenterY)
          ..lineTo(connectorX, currentCenterY)
          ..lineTo(connectorX, nextCenterY)
          ..lineTo(next.left + next.width, nextCenterY);
        canvas
          ..drawPath(path, paint)
          ..drawCircle(
            Offset(next.left + next.width, nextCenterY),
            _myDailyTimelineConnectorEndpointRadius,
            Paint()
              ..color = (current.badgeColor ?? current.strokeColor).withValues(
                alpha: opacity,
              ),
          );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MyDailyTimelineConnectorPainter oldDelegate) {
    return oldDelegate.blocks != blocks ||
        oldDelegate.selectedCategoryIds != selectedCategoryIds ||
        oldDelegate.showFilter != showFilter;
  }
}

enum _MyDailyTimelineBlockStyle {
  detailed,
  pill,
  split,
}

class _MyDailyTimelineSectionSpec {
  const _MyDailyTimelineSectionSpec({
    required this.filterId,
    required this.label,
    required this.icon,
    required this.color,
    required this.top,
    required this.height,
  });

  final String filterId;
  final String label;
  final IconData icon;
  final Color color;
  final double top;
  final double height;
}

class _MyDailyTimelineBlockSpec {
  const _MyDailyTimelineBlockSpec({
    required this.id,
    required this.filterId,
    required this.style,
    required this.density,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.title,
    required this.trailingLabel,
    required this.fillColor,
    required this.strokeColor,
    required this.padding,
    this.subtitle,
    this.metaLabel,
    this.badgeLabel,
    this.badgeColor,
    this.glowColor,
    this.leadingIcon,
    this.inlineChip,
    this.showWarning = false,
    this.connectorGroupId,
  });

  final String id;
  final String filterId;
  final _MyDailyTimelineBlockStyle style;
  final MyDailyTimelineBlockDensity density;
  final double left;
  final double top;
  final double width;
  final double height;
  final String title;
  final String trailingLabel;
  final String? subtitle;
  final String? metaLabel;
  final String? badgeLabel;
  final Color? badgeColor;
  final Color fillColor;
  final Color strokeColor;
  final Color? glowColor;
  final EdgeInsets padding;
  final IconData? leadingIcon;
  final _TimelineInlineChipSpec? inlineChip;
  final bool showWarning;
  final String? connectorGroupId;
}

class _TimelineInlineChipSpec {
  const _TimelineInlineChipSpec({
    required this.color,
    required this.width,
    // ignore: unused_element_parameter
    this.label,
  });

  final Color color;
  final double width;
  final String? label;
}

const _timelineBlockTitleStyle = TextStyle(
  color: Color.fromRGBO(255, 255, 255, 0.88),
  fontSize: 12,
  fontWeight: FontWeight.w500,
  height: 1.333,
);

const _timelineBlockMetaStyle = TextStyle(
  color: Color.fromRGBO(255, 255, 255, 0.32),
  fontSize: 10,
  fontWeight: FontWeight.w400,
  height: 1.6,
);

const _timelineTrailingStyle = TextStyle(
  color: Color.fromRGBO(255, 255, 255, 0.64),
  fontSize: 10,
  fontWeight: FontWeight.w500,
  height: 1.6,
);

const _timelineChipLabelStyle = TextStyle(
  color: Color(0xFF122029),
  fontSize: 10,
  fontWeight: FontWeight.w600,
  height: 1.6,
);

double _resolveTimelineOpacity({
  required String filterId,
  required Set<String> selectedCategoryIds,
  required bool showFilter,
}) {
  if (!showFilter || selectedCategoryIds.contains(filterId)) {
    return 1;
  }
  return _myDailyTimelineDimmedOpacity;
}

List<_MyDailyTimelineSectionSpec> _buildTimelineSections(BuildContext context) {
  return [
    _MyDailyTimelineSectionSpec(
      filterId: _holidayCategoryId,
      label: _labelForCategory(context, _holidayCategoryId),
      icon: _iconForCategory(_holidayCategoryId),
      color: _colorForCategory(_holidayCategoryId),
      top: 75,
      height: 209,
    ),
    _MyDailyTimelineSectionSpec(
      filterId: _tasksCategoryId,
      label: _labelForCategory(context, _tasksCategoryId),
      icon: _iconForCategory(_tasksCategoryId),
      color: _colorForCategory(_tasksCategoryId),
      top: 309,
      height: 105,
    ),
    _MyDailyTimelineSectionSpec(
      filterId: _hikingCategoryId,
      label: _labelForCategory(context, _hikingCategoryId),
      icon: _iconForCategory(_hikingCategoryId),
      color: _colorForCategory(_hikingCategoryId),
      top: 414,
      height: 414,
    ),
  ];
}

List<_MyDailyTimelineBlockSpec> _buildTimelineBlockSpecs(BuildContext context) {
  final holidayBase = _colorForCategory(_holidayCategoryId);
  final holidayFill = holidayBase.withValues(alpha: 0.16);
  final holidayStroke = holidayBase.withValues(alpha: 0.4);
  final holidayGlow = holidayBase.withValues(alpha: 0.55);
  final tasksBase = _colorForCategory(_tasksCategoryId);
  final tasksFill = tasksBase.withValues(alpha: 0.16);
  final tasksStroke = tasksBase.withValues(alpha: 0.8);
  final tasksGlow = tasksBase.withValues(alpha: 0.35);
  final hikingBase = _colorForCategory(_hikingCategoryId);
  final hikingFill = hikingBase.withValues(alpha: 0.16);
  final hikingStroke = hikingBase.withValues(alpha: 0.4);
  final hikingGlow = hikingBase.withValues(alpha: 0.55);
  const neutralFill = Color(0xFF2C2C2C);
  const neutralStroke = Color.fromRGBO(255, 255, 255, 0.12);

  return [
    _MyDailyTimelineBlockSpec(
      id: 'skiing',
      filterId: _holidayCategoryId,
      style: _MyDailyTimelineBlockStyle.detailed,
      density: MyDailyTimelineBlockDensity.expanded,
      left: 88,
      top: 78,
      width: 274,
      height: 87,
      title: context.messages.designSystemMyDailySkiWithMattTitle,
      badgeLabel: 'P1',
      badgeColor: _myDailyDefaultBadgeColor,
      trailingLabel: '1h 35m',
      subtitle: _formatLocalizedPreviewTimeRange(
        context,
        startHour: 8,
        startMinute: 5,
        endHour: 9,
        endMinute: 40,
      ),
      metaLabel: '4 sessions',
      fillColor: holidayFill,
      strokeColor: holidayStroke,
      glowColor: holidayGlow,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      connectorGroupId: _holidayCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'skiing-recap',
      filterId: _holidayCategoryId,
      style: _MyDailyTimelineBlockStyle.pill,
      density: MyDailyTimelineBlockDensity.compact,
      left: 88,
      top: 179,
      width: 274,
      height: 24,
      title: '2 of 4',
      trailingLabel: '25m',
      fillColor: holidayFill,
      strokeColor: holidayStroke,
      glowColor: holidayGlow,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leadingIcon: Icons.timelapse_rounded,
      connectorGroupId: _holidayCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'lunch-break',
      filterId: _tasksCategoryId,
      style: _MyDailyTimelineBlockStyle.pill,
      density: MyDailyTimelineBlockDensity.compact,
      left: 88,
      top: 311,
      width: 274,
      height: 16,
      title: context.messages.designSystemMyDailyLunchBreakTitle,
      trailingLabel: '15m',
      metaLabel: '3 sessions',
      fillColor: tasksFill,
      strokeColor: tasksStroke,
      glowColor: tasksGlow,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      inlineChip: const _TimelineInlineChipSpec(
        color: Color(0xFF2094FF),
        width: 28,
      ),
      connectorGroupId: _tasksCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'tasks-progress',
      filterId: _tasksCategoryId,
      style: _MyDailyTimelineBlockStyle.pill,
      density: MyDailyTimelineBlockDensity.compact,
      left: 88,
      top: 336,
      width: 136,
      height: 24,
      title: '2 of 3',
      trailingLabel: '25m',
      fillColor: tasksFill,
      strokeColor: tasksStroke,
      glowColor: tasksGlow,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leadingIcon: Icons.timelapse_rounded,
      connectorGroupId: _tasksCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'holiday-progress',
      filterId: _holidayCategoryId,
      style: _MyDailyTimelineBlockStyle.pill,
      density: MyDailyTimelineBlockDensity.compact,
      left: 226,
      top: 346,
      width: 136,
      height: 24,
      title: '3 of 4',
      trailingLabel: '20m',
      fillColor: holidayFill,
      strokeColor: holidayStroke,
      glowColor: holidayGlow,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leadingIcon: Icons.timelapse_rounded,
      showWarning: true,
      connectorGroupId: _holidayCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'focus-left',
      filterId: _tasksCategoryId,
      style: _MyDailyTimelineBlockStyle.split,
      density: MyDailyTimelineBlockDensity.regular,
      left: 88,
      top: 439,
      width: 136,
      height: 53,
      title: _formatLocalizedPreviewTimeRange(
        context,
        startHour: 15,
        startMinute: 0,
        endHour: 16,
        endMinute: 0,
      ),
      trailingLabel: '1h',
      metaLabel: '3 of 3',
      fillColor: const Color.fromRGBO(52, 68, 65, 0.72),
      strokeColor: const Color.fromRGBO(116, 143, 137, 0.28),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      showWarning: true,
      connectorGroupId: _tasksCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'focus-right',
      filterId: _holidayCategoryId,
      style: _MyDailyTimelineBlockStyle.split,
      density: MyDailyTimelineBlockDensity.regular,
      left: 226,
      top: 439,
      width: 136,
      height: 53,
      title: _formatLocalizedPreviewTimeRange(
        context,
        startHour: 15,
        startMinute: 0,
        endHour: 16,
        endMinute: 0,
      ),
      trailingLabel: '1h',
      metaLabel: '4 of 4',
      fillColor: holidayFill,
      strokeColor: holidayStroke,
      glowColor: holidayGlow,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      showWarning: true,
      connectorGroupId: _holidayCategoryId,
    ),
    _MyDailyTimelineBlockSpec(
      id: 'hiking',
      filterId: _hikingCategoryId,
      style: _MyDailyTimelineBlockStyle.detailed,
      density: MyDailyTimelineBlockDensity.regular,
      left: 88,
      top: 517,
      width: 274,
      height: 53,
      title: context.messages.designSystemMyDailyHikeWithDanielaTitle,
      badgeLabel: 'P2',
      badgeColor: const Color(0xFF2094FF),
      trailingLabel: '1h',
      subtitle: _formatLocalizedPreviewTimeRange(
        context,
        startHour: 16,
        startMinute: 30,
        endHour: 17,
        endMinute: 30,
      ),
      fillColor: hikingFill,
      strokeColor: hikingStroke,
      glowColor: hikingGlow,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    ),
    _MyDailyTimelineBlockSpec(
      id: 'meeting',
      filterId: _meetingsCategoryId,
      style: _MyDailyTimelineBlockStyle.detailed,
      density: MyDailyTimelineBlockDensity.regular,
      left: 88,
      top: 577,
      width: 274,
      height: 53,
      title: context.messages.designSystemMyDailyMeetingWithDannyTitle,
      badgeLabel: 'P0',
      badgeColor: const Color(0xFFF06A74),
      trailingLabel: '1h',
      subtitle: _formatLocalizedPreviewTimeRange(
        context,
        startHour: 17,
        startMinute: 40,
        endHour: 18,
        endMinute: 40,
      ),
      fillColor: neutralFill,
      strokeColor: neutralStroke,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      showWarning: true,
    ),
  ];
}

class _NowIndicator extends StatelessWidget {
  const _NowIndicator({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      key: const Key('my-daily-now-indicator'),
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step2,
            vertical: tokens.spacing.step1 / 2,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.alert.error.defaultColor,
            borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          ),
          child: Text(
            _formatLocalizedPreviewTime(context, now),
            style: tokens.typography.styles.others.overline.copyWith(
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(left: tokens.spacing.step2),
            height: 2,
            color: tokens.colors.alert.error.defaultColor,
          ),
        ),
      ],
    );
  }
}

class _MyDailyActionButton extends StatelessWidget {
  const _MyDailyActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Semantics(
      button: true,
      label: context.messages.designSystemNavigationNewLabel,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: tokens.colors.interactive.enabled,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: tokens.colors.interactive.enabled.withValues(alpha: 0.3),
                blurRadius: tokens.spacing.step4,
                offset: Offset(0, tokens.spacing.step2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Icon(
              Icons.add_rounded,
              color: tokens.colors.text.onInteractiveAlert,
              size: tokens.typography.lineHeight.subtitle1,
            ),
          ),
        ),
      ),
    );
  }
}

class _MyDailyBottomNavigation extends StatelessWidget {
  const _MyDailyBottomNavigation();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final items = widgetbookNavigationDestinations(context)
        .map(
          (destination) => DesignSystemNavigationTabBarItem(
            label: destination.label,
            icon: Icon(destination.icon),
            active: destination.active,
            onTap: widgetbookNoop,
          ),
        )
        .toList();

    return Column(
      children: [
        SizedBox(
          height: 68,
          child: Center(
            child: SizedBox(
              width: 354,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 278,
                    child: DesignSystemNavigationFrostedSurface(
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                      padding: EdgeInsets.all(tokens.spacing.step2),
                      child: Row(
                        children: [
                          for (var index = 0; index < items.length; index++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == items.length - 1
                                      ? 0
                                      : tokens.spacing.step1,
                                ),
                                child: _MyDailyBottomNavigationItem(
                                  item: items[index],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label:
                        context.messages.designSystemMyDailyProfileActionLabel,
                    child: DesignSystemNavigationFrostedSurface(
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                      child: SizedBox.square(
                        dimension: 60,
                        child: Center(
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: tokens.typography.lineHeight.subtitle1,
                            color: tokens.colors.text.highEmphasis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: Center(
            child: Container(
              width: 134,
              height: 5,
              decoration: BoxDecoration(
                color: tokens.colors.text.mediumEmphasis,
                borderRadius: BorderRadius.circular(tokens.radii.xl),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyDailyBottomNavigationItem extends StatelessWidget {
  const _MyDailyBottomNavigationItem({required this.item});

  final DesignSystemNavigationTabBarItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final iconColor = item.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.mediumEmphasis;
    final labelColor = item.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.highEmphasis;

    return Semantics(
      button: true,
      selected: item.active,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          onTap: item.onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step1,
              vertical: tokens.spacing.step2,
            ),
            decoration: BoxDecoration(
              color: item.active
                  ? tokens.colors.background.level01
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme.merge(
                  data: IconThemeData(
                    size: 20,
                    color: iconColor,
                  ),
                  child: item.icon,
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
