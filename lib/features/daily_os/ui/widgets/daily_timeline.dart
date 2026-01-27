import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/calendar/ui/pages/day_view_page.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/daily_os_empty_states.dart';
import 'package:lotti/features/daily_os/ui/widgets/planned_block_edit_modal.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Timeline showing plan vs actual time blocks.
class DailyTimeline extends ConsumerWidget {
  const DailyTimeline({super.key});

  static const double _hourHeight = 40;
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
          return const TimelineEmptyState();
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
    // Ensure totalHours is at least 1 to prevent RangeError in List.generate
    final totalHours = (endHour - startHour).clamp(1, 24);

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
                        date: data.date,
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

    final title = _getEntryTitle(
      slot.entry,
      category?.name ?? context.messages.dailyOsEntry,
    );

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height.clamp(20.0, double.infinity),
      child: GestureDetector(
        onTap: () {
          // Single tap navigates to the entry (like calendar view)
          final entryId = slot.entry.meta.id;
          final linkedFrom = slot.linkedFrom;

          if (linkedFrom != null) {
            if (linkedFrom is Task) {
              // Publish task focus intent before navigation
              ref
                  .read(
                    taskFocusControllerProvider(id: linkedFrom.meta.id)
                        .notifier,
                  )
                  .publishTaskFocus(
                    entryId: entryId,
                    alignment: kDefaultScrollAlignment,
                  );
              beamToNamed('/tasks/${linkedFrom.meta.id}');
            } else {
              // Publish journal focus intent before navigation
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
            // No linked parent, navigate directly to entry
            beamToNamed('/journal/$entryId');
          }
        },
        onLongPress: () {
          // Long press highlights the category
          if (categoryId != null) {
            ref
                .read(dailyOsControllerProvider.notifier)
                .highlightCategory(categoryId);
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

  String _getEntryTitle(JournalEntity entry, String fallback) {
    return switch (entry) {
      Task(:final data) => data.title,
      _ => fallback,
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
