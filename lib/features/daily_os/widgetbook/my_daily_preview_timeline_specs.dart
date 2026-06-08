part of 'my_daily_widgetbook.dart';

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
