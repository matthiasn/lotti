import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/planned_block_edit_modal.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Timeline showing plan vs actual time blocks.
class DailyTimeline extends ConsumerWidget {
  const DailyTimeline({super.key});

  static const double _hourHeight = 60;
  static const double _timeAxisWidth = 50;
  static const double _laneWidth = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final timelineDataAsync = ref.watch(
      timelineDataControllerProvider(date: selectedDate),
    );

    return timelineDataAsync.when(
      data: (data) {
        if (data.plannedSlots.isEmpty && data.actualSlots.isEmpty) {
          return const _EmptyTimelineState();
        }

        return _TimelineContent(data: data);
      },
      loading: () => const _LoadingState(),
      error: (error, stack) => _ErrorState(error: error),
    );
  }
}

/// Main timeline content with scrollable time axis.
class _TimelineContent extends StatelessWidget {
  const _TimelineContent({required this.data});

  final DailyTimelineData data;

  @override
  Widget build(BuildContext context) {
    final startHour = data.dayStartHour;
    final endHour = data.dayEndHour;
    final totalHours = endHour - startHour;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
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
                'Timeline',
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
                        color:
                            context.colorScheme.primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: context.colorScheme.primary
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Plan',
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
                      'Actual',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Timeline grid
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
          height: totalHours * DailyTimeline._hourHeight + 20,
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
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
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Planned blocks lane
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: DailyTimeline._timeAxisWidth,
                  width: DailyTimeline._laneWidth,
                  child: Stack(
                    children: data.plannedSlots.map((slot) {
                      return _PlannedBlockWidget(
                        slot: slot,
                        startHour: startHour,
                      );
                    }).toList(),
                  ),
                ),

                // Actual blocks lane
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: DailyTimeline._timeAxisWidth +
                      DailyTimeline._laneWidth +
                      8,
                  right: 8,
                  child: Stack(
                    children: data.actualSlots.map((slot) {
                      return _ActualBlockWidget(
                        slot: slot,
                        startHour: startHour,
                      );
                    }).toList(),
                  ),
                ),

                // Current time indicator
                if (_isToday(data.date))
                  _CurrentTimeIndicator(startHour: startHour),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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
  });

  final PlannedTimeSlot slot;
  final int startHour;

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
      height: height.clamp(20.0, double.infinity),
      child: GestureDetector(
        onTap: () {
          if (categoryId != null) {
            ref
                .read(dailyOsControllerProvider.notifier)
                .highlightCategory(categoryId);
          }
        },
        onLongPress: () {
          PlannedBlockEditModal.show(context, slot.block);
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
            category?.name ?? 'Planned',
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

/// Widget for an actual time entry.
class _ActualBlockWidget extends ConsumerWidget {
  const _ActualBlockWidget({
    required this.slot,
    required this.startHour,
  });

  final ActualTimeSlot slot;
  final int startHour;

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

    final title = _getEntryTitle(slot.entry);

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height.clamp(20.0, double.infinity),
      child: GestureDetector(
        onTap: () {
          // Single tap highlights the category
          if (categoryId != null) {
            ref
                .read(dailyOsControllerProvider.notifier)
                .highlightCategory(categoryId);
          }
        },
        onLongPress: () {
          // Long press navigates to the entry
          final entryId = slot.entry.meta.id;
          if (slot.entry is Task) {
            beamToNamed('/tasks/$entryId');
          } else {
            beamToNamed('/journal/$entryId');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
            border: isHighlighted
                ? Border.all(
                    color: context.colorScheme.onSurface,
                    width: 2,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color:
                    categoryColor.withValues(alpha: isHighlighted ? 0.5 : 0.3),
                blurRadius: isHighlighted ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Text(
            title,
            style: context.textTheme.labelSmall?.copyWith(
              color: _getTextColor(categoryColor),
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _getEntryTitle(JournalEntity entry) {
    return switch (entry) {
      Task(:final data) => data.title,
      JournalEntry() => 'Journal',
      _ => 'Entry',
    };
  }

  Color _getTextColor(Color backgroundColor) {
    // Simple luminance check for text contrast
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
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

/// Empty state when no timeline data.
class _EmptyTimelineState extends StatelessWidget {
  const _EmptyTimelineState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingLarge),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            MdiIcons.calendarBlankOutline,
            size: 48,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            'No timeline entries',
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            'Start a timer or add planned blocks to see your day.',
            style: context.textTheme.bodyMedium?.copyWith(
              color:
                  context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
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
              'Failed to load timeline',
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
