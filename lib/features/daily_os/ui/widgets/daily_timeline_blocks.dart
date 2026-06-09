part of 'daily_timeline.dart';

/// A visible (unfolded) section of the timeline.
class _VisibleTimelineSection extends ConsumerWidget {
  const _VisibleTimelineSection({
    required this.data,
    required this.startHour,
    required this.endHour,
    required this.foldingState,
    required this.expandedRegions,
    this.onDragActiveChanged,
    this.canCollapse = false,
    this.onCollapse,
  });

  final DailyTimelineData data;
  final int startHour;
  final int endHour;
  final TimelineFoldingState foldingState;
  final Set<int> expandedRegions;
  final DragActiveChangedCallback? onDragActiveChanged;

  /// Whether this section can be collapsed (was expanded from a compressed
  /// region).
  final bool canCollapse;

  /// Callback to collapse this section back to compressed state.
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalHours = endHour - startHour;
    final sectionHeight = totalHours * DailyTimeline._hourHeight;

    // Filter slots to only those that overlap with this section.
    // A slot overlaps if it starts before the section ends AND ends after the
    // section starts.
    final sectionPlannedSlots = data.plannedSlots.where((slot) {
      return _slotOverlapsSection(slot.startTime, slot.endTime);
    }).toList();

    final sectionActualSlots = data.actualSlots.where((slot) {
      return _slotOverlapsSection(slot.startTime, slot.endTime);
    }).toList();

    return SizedBox(
      height: sectionHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hour grid lines
          ...List.generate(totalHours + 1, (i) {
            final hour = startHour + i;
            return Positioned(
              top: i * DailyTimeline._hourHeight,
              left: 0,
              right: 0,
              child: _HourGridLine(hour: hour, isFirst: i == 0),
            );
          }),

          // Time axis labels
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: DailyTimeline._timeAxisWidth,
            child: Column(
              children: List.generate(totalHours, (i) {
                final hour = startHour + i;
                return SizedBox(
                  height: DailyTimeline._hourHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.7),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Collapse button for expanded regions
          if (canCollapse && onCollapse != null)
            Positioned(
              top: 4,
              left: 4,
              child: GestureDetector(
                onTap: onCollapse,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: context.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.unfold_less,
                        size: 14,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        context.messages.dailyOsFold,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Planned blocks lane
          Positioned(
            top: 0,
            bottom: 0,
            left: DailyTimeline._timeAxisWidth,
            width: DailyTimeline._laneWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: sectionPlannedSlots.map((slot) {
                return DraggablePlannedBlock(
                  key: ValueKey('planned-block-${slot.block.id}'),
                  slot: slot,
                  sectionStartHour: startHour,
                  sectionEndHour: endHour,
                  date: data.date,
                  foldingState: foldingState,
                  expandedRegions: expandedRegions,
                  onDragActiveChanged: onDragActiveChanged,
                );
              }).toList(),
            ),
          ),

          // Actual blocks lane with overlap handling and nesting
          Positioned(
            top: 0,
            bottom: 0,
            left: DailyTimeline._timeAxisWidth + DailyTimeline._laneWidth + 8,
            right: 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final assignments = assignLanes(sectionActualSlots);
                final laneCount = laneCountFor(assignments);
                final laneWidth = constraints.maxWidth / laneCount;

                return Stack(
                  children: assignments.map((assignment) {
                    return _ActualBlockWidget(
                      slot: assignment.slot,
                      date: data.date,
                      startHour: startHour,
                      laneIndex: assignment.laneIndex,
                      laneCount: laneCount,
                      laneWidth: laneWidth,
                      nestedChildren: assignment.children,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Checks if a slot overlaps with this section's time range.
  ///
  /// A slot overlaps if it starts before the section ends AND ends after the
  /// section starts. This handles slots that span section boundaries.
  bool _slotOverlapsSection(DateTime slotStart, DateTime slotEnd) {
    final slotStartMinutes = minutesFromDate(data.date, slotStart);
    final slotEndMinutes = minutesFromDate(data.date, slotEnd);

    final sectionStartMinutes = startHour * 60;
    final sectionEndMinutes = endHour * 60;

    return slotStartMinutes < sectionEndMinutes &&
        slotEndMinutes > sectionStartMinutes;
  }
}

/// Horizontal grid line for each hour.
class _HourGridLine extends StatelessWidget {
  const _HourGridLine({required this.hour, this.isFirst = false});

  final int hour;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: context.colorScheme.outlineVariant.withValues(
        alpha: isFirst ? 0 : 0.3,
      ),
    );
  }
}

/// Widget for an actual time entry, with optional nested children.
class _ActualBlockWidget extends ConsumerWidget {
  const _ActualBlockWidget({
    required this.slot,
    required this.date,
    required this.startHour,
    required this.laneIndex,
    required this.laneCount,
    required this.laneWidth,
    this.nestedChildren = const [],
  });

  final ActualTimeSlot slot;
  final DateTime date;
  final int startHour;
  final int laneIndex;
  final int laneCount;
  final double laneWidth;

  /// Nested child entries that render inside this block (same category).
  final List<ActualTimeSlot> nestedChildren;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotStartMinutes = minutesFromDate(date, slot.startTime);
    final slotEndMinutes = minutesFromDate(date, slot.endTime);
    final startMinutes = slotStartMinutes - (startHour * 60);
    final durationMinutes = (slotEndMinutes - slotStartMinutes).clamp(
      0,
      kMaxMinutesInDay,
    );
    final top = startMinutes * DailyTimeline._hourHeight / 60;
    final height = durationMinutes * DailyTimeline._hourHeight / 60;

    final category = slot.category;
    final categoryId = category?.id;
    final categoryColor = category != null
        ? colorFromCssHex(category.color)
        : context.colorScheme.primary;

    final highlightedId = ref.watch(highlightedCategoryIdProvider);
    final isHighlighted = categoryId != null && highlightedId == categoryId;

    // Calculate horizontal position based on lane assignment
    final left = laneIndex * laneWidth;
    // Add small gap between lanes for visual separation
    final gap = laneCount > 1 ? 2.0 : 0;
    final width = laneWidth - gap;

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: _ActualBlockContent(
        slot: slot,
        date: date,
        categoryColor: categoryColor,
        isHighlighted: isHighlighted,
        nestedChildren: nestedChildren,
        parentStartTime: slot.startTime,
        parentWidth: width,
        startHour: startHour,
      ),
    );
  }
}

/// The interactive content of an actual block, including nested children.
class _ActualBlockContent extends ConsumerWidget {
  const _ActualBlockContent({
    required this.slot,
    required this.date,
    required this.categoryColor,
    required this.isHighlighted,
    required this.nestedChildren,
    required this.parentStartTime,
    required this.parentWidth,
    required this.startHour,
    this.nestingDepth = 0,
  });

  final ActualTimeSlot slot;
  final DateTime date;
  final Color categoryColor;
  final bool isHighlighted;
  final List<ActualTimeSlot> nestedChildren;
  final DateTime parentStartTime;
  final double parentWidth;
  final int startHour;
  final int nestingDepth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ratings are children of time entries, not parent navigation targets.
    final linkedFrom = switch (slot.linkedFrom) {
      RatingEntry() => null,
      final value => value,
    };
    final entryId = slot.entry.meta.id;
    final categoryId = slot.categoryId;

    // Determine styling based on nesting depth
    final isNested = nestingDepth > 0;
    final alpha = isNested ? 0.95 : 0.85;
    final borderWidth = isNested ? 2.0 : (isHighlighted ? 2.0 : 0.0);
    final borderColor = isNested
        ? categoryColor.withValues(alpha: 1)
        : context.colorScheme.onSurface;

    return GestureDetector(
      onTap: () {
        if (linkedFrom is Task) {
          ref
              .read(
                taskFocusControllerProvider(id: linkedFrom.meta.id).notifier,
              )
              .publishTaskFocus(
                entryId: entryId,
                alignment: kDefaultScrollAlignment,
              );
          beamToNamed('/tasks/${linkedFrom.meta.id}');
        } else {
          beamToNamed('/journal/$entryId');
        }
      },
      onLongPress: () {
        if (categoryId != null) {
          ref
              .read(dailyOsControllerProvider.notifier)
              .highlightCategory(categoryId);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: categoryColor.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(isNested ? 4 : 6),
          border: (isHighlighted || isNested)
              ? Border.all(color: borderColor, width: borderWidth)
              : null,
          boxShadow: isNested
              ? null
              : [
                  BoxShadow(
                    color: categoryColor.withValues(
                      alpha: isHighlighted ? 0.5 : 0.3,
                    ),
                    blurRadius: isHighlighted ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Accessibility label
            Semantics(
              label: slot.category?.name ?? '',
              child: const SizedBox.expand(),
            ),
            // Render nested children with lane assignment for overlapping siblings
            ..._buildNestedChildWidgets(
              nestedChildren: nestedChildren,
              parent: slot,
              parentWidth: parentWidth,
              nestingDepth: nestingDepth + 1,
              startHour: startHour,
              date: date,
            ),
          ],
        ),
      ),
    );
  }
}

/// A nested child block rendered inside its parent.
class _NestedChildBlock extends ConsumerWidget {
  const _NestedChildBlock({
    required this.child,
    required this.parent,
    required this.parentWidth,
    required this.nestingDepth,
    required this.startHour,
    required this.date,
    required this.laneIndex,
    required this.laneCount,
  });

  final ActualTimeSlot child;
  final ActualTimeSlot parent;
  final double parentWidth;
  final int nestingDepth;
  final int startHour;
  final DateTime date;
  final int laneIndex;
  final int laneCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calculate position relative to parent
    final parentStartMinutes = minutesFromDate(date, parent.startTime);
    final childStartMinutes = minutesFromDate(date, child.startTime);

    // Offset from parent's top edge
    final relativeTopMinutes = childStartMinutes - parentStartMinutes;
    final relativeTop = relativeTopMinutes * DailyTimeline._hourHeight / 60;

    final childStart = minutesFromDate(date, child.startTime);
    final childEnd = minutesFromDate(date, child.endTime);
    final childDurationMinutes = (childEnd - childStart).clamp(
      0,
      kMaxMinutesInDay,
    );
    final childHeight = childDurationMinutes * DailyTimeline._hourHeight / 60;

    // Inset from edges based on nesting depth
    final inset = _nestedInset * nestingDepth;
    final availableWidth = parentWidth - (inset * 2);
    final laneWidth = availableWidth / laneCount;
    final leftOffset = inset + (laneIndex * laneWidth);
    final gap = laneCount > 1 ? 1.0 : 0;

    final category = child.category;
    final categoryColor = category != null
        ? colorFromCssHex(category.color)
        : context.colorScheme.primary;

    final highlightedId = ref.watch(highlightedCategoryIdProvider);
    final isHighlighted =
        child.categoryId != null && highlightedId == child.categoryId;

    return Positioned(
      top: relativeTop + inset,
      left: leftOffset,
      width: laneWidth - gap,
      height: math.max(childHeight - (inset * 2), 8),
      child: _ActualBlockContent(
        slot: child,
        date: date,
        categoryColor: categoryColor,
        isHighlighted: isHighlighted,
        nestedChildren: const [], // Children don't have further nesting for now
        parentStartTime: parent.startTime,
        parentWidth: laneWidth - gap,
        startHour: startHour,
        nestingDepth: nestingDepth,
      ),
    );
  }
}

/// Current time indicator line.
///
/// Uses [timeToFoldedPosition] to correctly position the indicator
/// accounting for compressed/expanded regions in the folded timeline.
class _CurrentTimeIndicator extends StatelessWidget {
  const _CurrentTimeIndicator({
    required this.foldingState,
    required this.expandedRegions,
  });

  final TimelineFoldingState foldingState;
  final Set<int> expandedRegions;

  @override
  Widget build(BuildContext context) {
    final now = clock.now();

    // Hide indicator if current time is in a collapsed compressed region
    if (isHourInCompressedRegion(
      hour: now.hour,
      foldingState: foldingState,
      expandedRegions: expandedRegions,
    )) {
      return const SizedBox.shrink();
    }

    // Calculate position using the folding-aware utility
    final top = timeToFoldedPosition(
      hour: now.hour,
      minute: now.minute,
      foldingState: foldingState,
      expandedRegions: expandedRegions,
    );

    if (top < 0) return const SizedBox.shrink();

    return Positioned(
      top: top,
      left: DailyTimeline._timeAxisWidth - 4,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading state.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Error state.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingLarge),
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: context.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      child: Row(
        children: [
          Icon(
            MdiIcons.alertCircle,
            color: context.colorScheme.error,
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Text(
              context.messages.dailyOsFailedToLoadTimeline,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
