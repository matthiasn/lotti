import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/compressed_timeline_region.dart';
import 'package:lotti/features/daily_os/ui/widgets/daily_os_empty_states.dart';
import 'package:lotti/features/daily_os/ui/widgets/draggable_planned_block.dart';
import 'package:lotti/features/daily_os/ui/widgets/timeline_lane_layout.dart';
import 'package:lotti/features/daily_os/util/drag_position_utils.dart';
import 'package:lotti/features/daily_os/util/timeline_folding_utils.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/consts.dart';

part 'daily_timeline_blocks.dart';

part 'daily_timeline_layout.dart';

/// Timeline showing plan vs actual time blocks.
class DailyTimeline extends ConsumerWidget {
  const DailyTimeline({
    super.key,
    this.onDragActiveChanged,
  });

  /// Callback when a drag operation starts or ends.
  /// Used by parent to lock scroll during drag.
  final DragActiveChangedCallback? onDragActiveChanged;

  static const double _hourHeight = 40;
  static const double _timeAxisWidth = 50;
  static const double _laneWidth = 120;

  /// Bottom padding to prevent content from being clipped at the edge.
  static const double _bottomPadding = 20;

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

        return _TimelineContent(
          data: data,
          onDragActiveChanged: onDragActiveChanged,
        );
      },
      loading: () => const _LoadingState(),
      error: (error, stack) => _ErrorState(error: error),
    );
  }
}

/// Main timeline content with scrollable time axis and smart folding.
class _TimelineContent extends ConsumerWidget {
  const _TimelineContent({
    required this.data,
    this.onDragActiveChanged,
  });

  final DailyTimelineData data;
  final DragActiveChangedCallback? onDragActiveChanged;

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
              onDragActiveChanged: onDragActiveChanged,
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
    this.onDragActiveChanged,
  });

  final DailyTimelineData data;
  final TimelineFoldingState foldingState;
  final Set<int> expandedRegions;
  final double totalHeight;
  final DragActiveChangedCallback? onDragActiveChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build the list of timeline sections in order
    final sections = _buildOrderedSections();
    final isToday = _isToday(data.date);

    // Use AnimatedContainer to smoothly transition the height when
    // expanding/collapsing regions. The combination of ClipRect + OverflowBox
    // allows the Column to size itself naturally while clipping any overflow
    // during animation transitions.
    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: AppTheme.animationDuration),
        curve: Curves.easeInOut,
        height: totalHeight + DailyTimeline._bottomPadding,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: Stack(
            children: [
              // Timeline sections
              Column(
                mainAxisSize: MainAxisSize.min,
                children: sections.map((section) {
                  return _buildSection(context, ref, section);
                }).toList(),
              ),

              // Current time indicator (single instance, positioned using folding)
              if (isToday)
                _CurrentTimeIndicator(
                  foldingState: foldingState,
                  expandedRegions: expandedRegions,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds an ordered list of sections (visible clusters and compressed regions).
  List<_TimelineSection> _buildOrderedSections() {
    final sections = <_TimelineSection>[];

    // Combine all regions and sort by start hour
    final allRegions =
        <
          ({
            int startHour,
            int endHour,
            bool isOriginallyCompressed,
          })
        >[];

    for (final cluster in foldingState.visibleClusters) {
      allRegions.add((
        startHour: cluster.startHour,
        endHour: cluster.endHour,
        isOriginallyCompressed: false,
      ));
    }

    for (final region in foldingState.compressedRegions) {
      allRegions.add((
        startHour: region.startHour,
        endHour: region.endHour,
        isOriginallyCompressed: true,
      ));
    }

    allRegions.sort((a, b) => a.startHour.compareTo(b.startHour));

    for (final region in allRegions) {
      final isExpanded = expandedRegions.contains(region.startHour);

      if (region.isOriginallyCompressed) {
        // Originally compressed region - use animatable section
        sections.add(
          _TimelineSection.animatable(
            CompressedRegion(
              startHour: region.startHour,
              endHour: region.endHour,
            ),
            isExpanded: isExpanded,
          ),
        );
      } else {
        // Visible cluster - always visible, cannot collapse
        sections.add(
          _TimelineSection.visible(
            startHour: region.startHour,
            endHour: region.endHour,
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
      // Visible clusters cannot collapse - they are always visible
      _VisibleSection(:final startHour, :final endHour) =>
        _VisibleTimelineSection(
          data: data,
          startHour: startHour,
          endHour: endHour,
          foldingState: foldingState,
          expandedRegions: expandedRegions,
          onDragActiveChanged: onDragActiveChanged,
        ),
      _AnimatableSection(:final region, :final isExpanded) =>
        AnimatedTimelineRegion(
          key: ValueKey('animated-region-${region.startHour}'),
          region: region,
          isExpanded: isExpanded,
          normalHourHeight: DailyTimeline._hourHeight,
          child: isExpanded
              ? _VisibleTimelineSection(
                  data: data,
                  startHour: region.startHour,
                  endHour: region.endHour,
                  foldingState: foldingState,
                  expandedRegions: expandedRegions,
                  onDragActiveChanged: onDragActiveChanged,
                  canCollapse: true,
                  onCollapse: () {
                    ref
                        .read(dailyOsControllerProvider.notifier)
                        .toggleFoldRegion(region.startHour);
                  },
                )
              : CompressedTimelineRegion(
                  region: region,
                  timeAxisWidth: DailyTimeline._timeAxisWidth,
                  onTap: () {
                    ref
                        .read(dailyOsControllerProvider.notifier)
                        .toggleFoldRegion(region.startHour);
                  },
                ),
        ),
    };
  }

  bool _isToday(DateTime date) {
    final now = clock.now();
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
  }) = _VisibleSection;

  factory _TimelineSection.animatable(
    CompressedRegion region, {
    required bool isExpanded,
  }) = _AnimatableSection;
}

class _VisibleSection extends _TimelineSection {
  const _VisibleSection({
    required this.startHour,
    required this.endHour,
  });

  final int startHour;
  final int endHour;
}

/// A section that can animate between compressed and expanded states.
class _AnimatableSection extends _TimelineSection {
  const _AnimatableSection(this.region, {required this.isExpanded});

  final CompressedRegion region;
  final bool isExpanded;
}
