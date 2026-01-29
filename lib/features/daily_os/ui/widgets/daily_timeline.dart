import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/calendar/ui/pages/day_view_page.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/compressed_timeline_region.dart';
import 'package:lotti/features/daily_os/ui/widgets/daily_os_empty_states.dart';
import 'package:lotti/features/daily_os/ui/widgets/planned_block_edit_modal.dart';
import 'package:lotti/features/daily_os/util/timeline_folding_utils.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Represents a slot assigned to a specific lane, with optional nested children.
class _LaneAssignment {
  const _LaneAssignment({
    required this.slot,
    required this.laneIndex,
    this.children = const [],
  });

  final ActualTimeSlot slot;
  final int laneIndex;

  /// Nested children that render inside this slot (same category, contained).
  final List<ActualTimeSlot> children;
}

/// Tracks a lane's end time for priority queue ordering.
class _LaneEndTime {
  const _LaneEndTime({required this.laneIndex, required this.endTime});

  final int laneIndex;
  final DateTime endTime;
}

/// Checks if [parent] fully contains [child] (same category, time-wise).
bool _slotContains(ActualTimeSlot parent, ActualTimeSlot child) {
  // Must be same category
  if (parent.categoryId != child.categoryId) return false;
  if (parent.categoryId == null) return false;

  // Parent must fully contain child
  return !parent.startTime.isAfter(child.startTime) &&
      !parent.endTime.isBefore(child.endTime) &&
      // Must not be the exact same slot
      (parent.startTime != child.startTime || parent.endTime != child.endTime);
}

/// Groups same-category entries into parent-child relationships.
///
/// Returns a map where keys are parent slots and values are their nested children.
/// Entries without a parent are their own key with an empty children list.
Map<ActualTimeSlot, List<ActualTimeSlot>> _groupNestedSlots(
  List<ActualTimeSlot> slots,
) {
  if (slots.isEmpty) return {};

  // Sort by duration descending (longest first = potential parents)
  final sorted = [...slots]..sort((a, b) => b.duration.compareTo(a.duration));

  final parentChildMap = <ActualTimeSlot, List<ActualTimeSlot>>{};
  final assignedChildren = <ActualTimeSlot>{};

  // For each slot, find children (slots contained within this one).
  // Since sorted is by duration descending, children must appear after parent.
  for (var i = 0; i < sorted.length; i++) {
    final slot = sorted[i];
    if (assignedChildren.contains(slot)) continue;

    // Initialize this slot as a potential parent
    parentChildMap[slot] = [];

    // Find children: only need to check slots after this one (shorter duration)
    for (var j = i + 1; j < sorted.length; j++) {
      final other = sorted[j];
      if (assignedChildren.contains(other)) continue;

      if (_slotContains(slot, other)) {
        parentChildMap[slot]!.add(other);
        assignedChildren.add(other);
      }
    }
  }

  return parentChildMap;
}

/// Assigns time slots to lanes to prevent visual overlap.
///
/// Uses a greedy algorithm with a min-heap for O(N log K) complexity,
/// where N is the number of slots and K is the number of lanes.
///
/// Same-category entries that are fully contained within another entry
/// (parent-child relationship) are nested visually instead of getting
/// separate lanes.
List<_LaneAssignment> _assignLanes(List<ActualTimeSlot> slots) {
  if (slots.isEmpty) return [];

  // First, group slots by parent-child relationships
  final nestedGroups = _groupNestedSlots(slots);

  // Get only the parent slots for lane assignment (children will nest inside)
  final parentSlots = nestedGroups.keys.toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  // Min-heap ordered by lane end time (earliest first)
  final laneHeap = PriorityQueue<_LaneEndTime>(
    (a, b) => a.endTime.compareTo(b.endTime),
  );

  final assignments = <_LaneAssignment>[];
  var nextLaneIndex = 0;

  for (final parentSlot in parentSlots) {
    int assignedLane;

    if (laneHeap.isNotEmpty &&
        !parentSlot.startTime.isBefore(laneHeap.first.endTime)) {
      // Reuse the earliest-ending lane (no overlap)
      final reusedLane = laneHeap.removeFirst();
      assignedLane = reusedLane.laneIndex;
    } else {
      // Create a new lane
      assignedLane = nextLaneIndex++;
    }

    // Add/update lane in heap with new end time
    laneHeap.add(
      _LaneEndTime(laneIndex: assignedLane, endTime: parentSlot.endTime),
    );

    // Create assignment with nested children
    final children = nestedGroups[parentSlot] ?? [];
    assignments.add(
      _LaneAssignment(
        slot: parentSlot,
        laneIndex: assignedLane,
        children: children,
      ),
    );
  }

  return assignments;
}

/// Returns the number of lanes needed for the given assignments.
int _getLaneCount(List<_LaneAssignment> assignments) {
  if (assignments.isEmpty) return 1;
  return assignments.map((a) => a.laneIndex).reduce(math.max) + 1;
}

/// Timeline showing plan vs actual time blocks.
class DailyTimeline extends ConsumerWidget {
  const DailyTimeline({super.key});

  static const double _hourHeight = 40;
  static const double _timeAxisWidth = 50;
  static const double _laneWidth = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final unifiedDataAsync = ref.watch(
      unifiedDailyOsDataControllerProvider(date: selectedDate),
    );

    return unifiedDataAsync.when(
      data: (unifiedData) {
        final data = unifiedData.timelineData;
        if (data.plannedSlots.isEmpty && data.actualSlots.isEmpty) {
          return const TimelineEmptyState();
        }

        return _TimelineContent(data: data);
      },
      loading: () => const _LoadingState(),
      error: (error, stack) => _ErrorState(error: error),
    );
  }
}

/// Main timeline content with scrollable time axis and smart folding.
class _TimelineContent extends ConsumerWidget {
  const _TimelineContent({required this.data});

  final DailyTimelineData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedRegions = ref.watch(expandedFoldRegionsProvider);

    // Calculate folding state based on entries
    final foldingState = calculateFoldingState(
      plannedSlots: data.plannedSlots,
      actualSlots: data.actualSlots,
    );

    // Calculate total height accounting for folding
    final totalHeight = calculateFoldedTimelineHeight(
      foldingState: foldingState,
      expandedRegions: expandedRegions,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        _TimelineHeader(),

        // Timeline grid with folding
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            child: _FoldedTimelineGrid(
              data: data,
              foldingState: foldingState,
              expandedRegions: expandedRegions,
              totalHeight: totalHeight,
            ),
          ),
        ),
      ],
    );
  }
}

/// Timeline header with title and legend.
class _TimelineHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLarge,
        vertical: AppTheme.spacingMedium,
      ),
      child: Row(
        children: [
          Icon(
            MdiIcons.timelineClockOutline,
            size: 20,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Text(
            context.messages.dailyOsTimeline,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Lane labels
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: context.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  context.messages.dailyOsPlan,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  context.messages.dailyOsActual,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The timeline grid with folded and visible sections.
class _FoldedTimelineGrid extends ConsumerWidget {
  const _FoldedTimelineGrid({
    required this.data,
    required this.foldingState,
    required this.expandedRegions,
    required this.totalHeight,
  });

  final DailyTimelineData data;
  final TimelineFoldingState foldingState;
  final Set<int> expandedRegions;
  final double totalHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build the list of timeline sections in order
    final sections = _buildOrderedSections();

    return SizedBox(
      height: totalHeight + 20,
      child: Column(
        children: sections.map((section) {
          return _buildSection(context, ref, section);
        }).toList(),
      ),
    );
  }

  /// Builds an ordered list of sections (visible clusters and compressed regions).
  List<_TimelineSection> _buildOrderedSections() {
    final sections = <_TimelineSection>[];

    // Combine all regions and sort by start hour
    final allRegions = <({int startHour, int endHour, bool isCompressed})>[];

    for (final cluster in foldingState.visibleClusters) {
      allRegions.add((
        startHour: cluster.startHour,
        endHour: cluster.endHour,
        isCompressed: false,
      ));
    }

    for (final region in foldingState.compressedRegions) {
      allRegions.add((
        startHour: region.startHour,
        endHour: region.endHour,
        isCompressed: true,
      ));
    }

    allRegions.sort((a, b) => a.startHour.compareTo(b.startHour));

    for (final region in allRegions) {
      final isExpanded = expandedRegions.contains(region.startHour);

      if (region.isCompressed && !isExpanded) {
        // Compressed region
        sections.add(
          _TimelineSection.compressed(
            CompressedRegion(
              startHour: region.startHour,
              endHour: region.endHour,
            ),
          ),
        );
      } else {
        // Expanded compressed region - can be collapsed
        sections.add(
          _TimelineSection.visible(
            startHour: region.startHour,
            endHour: region.endHour,
            canCollapse: true,
          ),
        );
      }
    }

    return sections;
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    _TimelineSection section,
  ) {
    return switch (section) {
      _VisibleSection(:final startHour, :final endHour, :final canCollapse) =>
        _VisibleTimelineSection(
          data: data,
          startHour: startHour,
          endHour: endHour,
          isToday: _isToday(data.date),
          canCollapse: canCollapse,
          onCollapse: canCollapse
              ? () {
                  ref
                      .read(dailyOsControllerProvider.notifier)
                      .toggleFoldRegion(startHour);
                }
              : null,
        ),
      _CompressedSection(:final region) => CompressedTimelineRegion(
          region: region,
          timeAxisWidth: DailyTimeline._timeAxisWidth,
          onTap: () {
            ref
                .read(dailyOsControllerProvider.notifier)
                .toggleFoldRegion(region.startHour);
          },
        ),
    };
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

/// Represents a section of the timeline.
sealed class _TimelineSection {
  const _TimelineSection();

  factory _TimelineSection.visible({
    required int startHour,
    required int endHour,
    bool canCollapse,
  }) = _VisibleSection;

  factory _TimelineSection.compressed(CompressedRegion region) =
      _CompressedSection;
}

class _VisibleSection extends _TimelineSection {
  const _VisibleSection({
    required this.startHour,
    required this.endHour,
    this.canCollapse = false,
  });

  final int startHour;
  final int endHour;

  /// If true, this section was expanded from a compressed region and can be
  /// collapsed back.
  final bool canCollapse;
}

class _CompressedSection extends _TimelineSection {
  const _CompressedSection(this.region);

  final CompressedRegion region;
}

/// A visible (unfolded) section of the timeline.
class _VisibleTimelineSection extends ConsumerWidget {
  const _VisibleTimelineSection({
    required this.data,
    required this.startHour,
    required this.endHour,
    required this.isToday,
    this.canCollapse = false,
    this.onCollapse,
  });

  final DailyTimelineData data;
  final int startHour;
  final int endHour;
  final bool isToday;

  /// Whether this section can be collapsed (was expanded from a compressed
  /// region).
  final bool canCollapse;

  /// Callback to collapse this section back to compressed state.
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalHours = endHour - startHour;
    final sectionHeight = totalHours * DailyTimeline._hourHeight;

    // Filter slots to only those in this section
    final sectionPlannedSlots = data.plannedSlots.where((slot) {
      return slot.startTime.hour >= startHour && slot.startTime.hour < endHour;
    }).toList();

    final sectionActualSlots = data.actualSlots.where((slot) {
      return slot.startTime.hour >= startHour && slot.startTime.hour < endHour;
    }).toList();

    return SizedBox(
      height: sectionHeight,
      child: Stack(
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
                      color: context.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
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
                        'Fold',
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
              children: sectionPlannedSlots.map((slot) {
                return _PlannedBlockWidget(
                  slot: slot,
                  startHour: startHour,
                  date: data.date,
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
                final assignments = _assignLanes(sectionActualSlots);
                final laneCount = _getLaneCount(assignments);
                final laneWidth = constraints.maxWidth / laneCount;

                return Stack(
                  children: assignments.map((assignment) {
                    return _ActualBlockWidget(
                      slot: assignment.slot,
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

          // Current time indicator (only if in this section)
          if (isToday && _isCurrentTimeInSection())
            _CurrentTimeIndicator(startHour: startHour),
        ],
      ),
    );
  }

  bool _isCurrentTimeInSection() {
    final now = DateTime.now();
    return now.hour >= startHour && now.hour < endHour;
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

/// Widget for a planned time block.
class _PlannedBlockWidget extends ConsumerWidget {
  const _PlannedBlockWidget({
    required this.slot,
    required this.startHour,
    required this.date,
  });

  final PlannedTimeSlot slot;
  final int startHour;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startMinutes =
        (slot.startTime.hour - startHour) * 60 + slot.startTime.minute;
    final durationMinutes = slot.duration.inMinutes;
    final top = startMinutes * DailyTimeline._hourHeight / 60;
    final height = durationMinutes * DailyTimeline._hourHeight / 60;

    final category = slot.category;
    final categoryId = category?.id;
    final categoryColor = category != null
        ? colorFromCssHex(category.color)
        : context.colorScheme.primary;

    final highlightedId = ref.watch(highlightedCategoryIdProvider);
    final isHighlighted = categoryId != null && highlightedId == categoryId;

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: GestureDetector(
        onTap: () {
          if (categoryId != null) {
            ref
                .read(dailyOsControllerProvider.notifier)
                .highlightCategory(categoryId);
          }
        },
        onLongPress: () {
          PlannedBlockEditModal.show(context, slot.block, date);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: isHighlighted ? 0.4 : 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: categoryColor.withValues(alpha: isHighlighted ? 0.9 : 0.4),
              width: isHighlighted ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Text(
            category?.name ?? context.messages.dailyOsPlanned,
            style: context.textTheme.labelSmall?.copyWith(
              color: categoryColor.withValues(alpha: 0.9),
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Visual inset in pixels for each nesting level.
const double _nestedInset = 4;

/// Widget for an actual time entry, with optional nested children.
class _ActualBlockWidget extends ConsumerWidget {
  const _ActualBlockWidget({
    required this.slot,
    required this.startHour,
    required this.laneIndex,
    required this.laneCount,
    required this.laneWidth,
    this.nestedChildren = const [],
  });

  final ActualTimeSlot slot;
  final int startHour;
  final int laneIndex;
  final int laneCount;
  final double laneWidth;

  /// Nested child entries that render inside this block (same category).
  final List<ActualTimeSlot> nestedChildren;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startMinutes =
        (slot.startTime.hour - startHour) * 60 + slot.startTime.minute;
    final durationMinutes = slot.duration.inMinutes;
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
    required this.categoryColor,
    required this.isHighlighted,
    required this.nestedChildren,
    required this.parentStartTime,
    required this.parentWidth,
    required this.startHour,
    this.nestingDepth = 0,
  });

  final ActualTimeSlot slot;
  final Color categoryColor;
  final bool isHighlighted;
  final List<ActualTimeSlot> nestedChildren;
  final DateTime parentStartTime;
  final double parentWidth;
  final int startHour;
  final int nestingDepth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedFrom = slot.linkedFrom;
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
        if (linkedFrom != null) {
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
            ref
                .read(
                  journalFocusControllerProvider(id: linkedFrom.meta.id)
                      .notifier,
                )
                .publishJournalFocus(
                  entryId: entryId,
                  alignment: kDefaultScrollAlignment,
                );
            beamToNamed('/journal/${linkedFrom.meta.id}');
          }
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
                        alpha: isHighlighted ? 0.5 : 0.3),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Assigns lanes to nested children and builds their widgets.
///
/// This handles the case where nested children overlap with each other
/// (e.g., two calls within a morning block that overlap in time).
List<Widget> _buildNestedChildWidgets({
  required List<ActualTimeSlot> nestedChildren,
  required ActualTimeSlot parent,
  required double parentWidth,
  required int nestingDepth,
  required int startHour,
}) {
  if (nestedChildren.isEmpty) return [];

  // Apply lane assignment to handle overlapping siblings
  final assignments = _assignLanesToSlots(nestedChildren);
  final laneCount = assignments.isEmpty
      ? 1
      : assignments.map((a) => a.laneIndex).reduce(math.max) + 1;

  return assignments.map((assignment) {
    return _NestedChildBlock(
      child: assignment.slot,
      parent: parent,
      parentWidth: parentWidth,
      nestingDepth: nestingDepth,
      startHour: startHour,
      laneIndex: assignment.laneIndex,
      laneCount: laneCount,
    );
  }).toList();
}

/// Simple lane assignment for a list of slots (used for nested children).
List<({ActualTimeSlot slot, int laneIndex})> _assignLanesToSlots(
  List<ActualTimeSlot> slots,
) {
  if (slots.isEmpty) return [];

  final sorted = [...slots]..sort((a, b) => a.startTime.compareTo(b.startTime));

  final laneHeap = PriorityQueue<_LaneEndTime>(
    (a, b) => a.endTime.compareTo(b.endTime),
  );

  final assignments = <({ActualTimeSlot slot, int laneIndex})>[];
  var nextLaneIndex = 0;

  for (final slot in sorted) {
    int assignedLane;

    if (laneHeap.isNotEmpty &&
        !slot.startTime.isBefore(laneHeap.first.endTime)) {
      final reusedLane = laneHeap.removeFirst();
      assignedLane = reusedLane.laneIndex;
    } else {
      assignedLane = nextLaneIndex++;
    }

    laneHeap.add(_LaneEndTime(laneIndex: assignedLane, endTime: slot.endTime));
    assignments.add((slot: slot, laneIndex: assignedLane));
  }

  return assignments;
}

/// A nested child block rendered inside its parent.
class _NestedChildBlock extends ConsumerWidget {
  const _NestedChildBlock({
    required this.child,
    required this.parent,
    required this.parentWidth,
    required this.nestingDepth,
    required this.startHour,
    required this.laneIndex,
    required this.laneCount,
  });

  final ActualTimeSlot child;
  final ActualTimeSlot parent;
  final double parentWidth;
  final int nestingDepth;
  final int startHour;
  final int laneIndex;
  final int laneCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calculate position relative to parent
    final parentStartMinutes =
        (parent.startTime.hour - startHour) * 60 + parent.startTime.minute;
    final childStartMinutes =
        (child.startTime.hour - startHour) * 60 + child.startTime.minute;

    // Offset from parent's top edge
    final relativeTopMinutes = childStartMinutes - parentStartMinutes;
    final relativeTop = relativeTopMinutes * DailyTimeline._hourHeight / 60;

    final childDurationMinutes = child.duration.inMinutes;
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
class _CurrentTimeIndicator extends StatelessWidget {
  const _CurrentTimeIndicator({required this.startHour});

  final int startHour;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMinutes = (now.hour - startHour) * 60 + now.minute;
    final top = currentMinutes * DailyTimeline._hourHeight / 60;

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
