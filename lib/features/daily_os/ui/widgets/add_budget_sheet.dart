import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uuid/uuid.dart';

/// Bottom sheet for adding a new planned block.
class AddBlockSheet extends ConsumerStatefulWidget {
  const AddBlockSheet({required this.date, super.key});

  final DateTime date;

  static Future<void> show(BuildContext context, DateTime date) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddBlockSheet(date: date),
    );
  }

  @override
  ConsumerState<AddBlockSheet> createState() => _AddBlockSheetState();
}

class _AddBlockSheetState extends ConsumerState<AddBlockSheet> {
  CategoryDefinition? _selectedCategory;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  void _showCategorySelector() {
    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.dailyOsSelectCategory,
      builder: (BuildContext _) {
        return CategorySelectionModalContent(
          onCategorySelected: (category) {
            setState(() {
              _selectedCategory = category;
            });
            Navigator.pop(context);
          },
          initialCategoryId: _selectedCategory?.id,
        );
      },
    );
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Auto-adjust end time if start is after end
        if (_timeToMinutes(_startTime) >= _timeToMinutes(_endTime)) {
          // Cap at 23:00 to avoid midnight wrap creating invalid range
          final newEndHour = (_startTime.hour + 1).clamp(0, 23);
          _endTime = TimeOfDay(
            hour: newEndHour,
            minute: _startTime.minute,
          );
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      if (_timeToMinutes(picked) > _timeToMinutes(_startTime)) {
        setState(() {
          _endTime = picked;
        });
      } else {
        // Show feedback when end time is not after start time
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.messages.dailyOsInvalidTimeRange),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  Duration get _duration {
    final startMinutes = _timeToMinutes(_startTime);
    final endMinutes = _timeToMinutes(_endTime);
    return Duration(minutes: endMinutes - startMinutes);
  }

  bool get _isValidTimeRange =>
      _timeToMinutes(_endTime) > _timeToMinutes(_startTime);

  Future<void> _handleAdd() async {
    final category = _selectedCategory;
    if (category == null) return;

    // Validate time range before saving
    if (!_isValidTimeRange) return;

    final dayPlanEntity = await ref.read(
      dayPlanControllerProvider(date: widget.date).future,
    );

    if (dayPlanEntity is! DayPlanEntry) {
      return;
    }

    final planDate = widget.date.dayAtMidnight;
    final startTime = planDate.add(
      Duration(hours: _startTime.hour, minutes: _startTime.minute),
    );
    final endTime = planDate.add(
      Duration(hours: _endTime.hour, minutes: _endTime.minute),
    );

    final block = PlannedBlock(
      id: const Uuid().v1(),
      categoryId: category.id,
      startTime: startTime,
      endTime: endTime,
    );

    await ref
        .read(dayPlanControllerProvider(date: widget.date).notifier)
        .addPlannedBlock(block);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = _selectedCategory;
    final categoryColor = category != null
        ? colorFromCssHex(category.color)
        : context.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),

            // Title
            Text(
              context.messages.dailyOsAddBlock,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),

            // Category selector
            Text(
              context.messages.dailyOsSelectCategory,
              style: context.textTheme.labelLarge,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            GestureDetector(
              onTap: _showCategorySelector,
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                decoration: BoxDecoration(
                  color: category != null
                      ? categoryColor.withValues(alpha: 0.1)
                      : null,
                  border: Border.all(
                    color: category != null
                        ? categoryColor.withValues(alpha: 0.3)
                        : context.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (category != null) ...[
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: categoryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSmall),
                      Expanded(
                        child: Text(
                          category.name,
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        MdiIcons.chevronRight,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ] else ...[
                      Icon(
                        MdiIcons.folderOutline,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppTheme.spacingSmall),
                      Expanded(
                        child: Text(
                          context.messages.dailyOsChooseCategory,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(
                        MdiIcons.chevronRight,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingLarge),

            // Time selectors
            Text(
              context.messages.dailyOsTimeRange,
              style: context.textTheme.labelLarge,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Row(
              children: [
                Expanded(
                  child: _TimeSelector(
                    label: context.messages.dailyOsStartTime,
                    time: _startTime,
                    onTap: _selectStartTime,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSmall),
                  child: Icon(
                    MdiIcons.arrowRight,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _TimeSelector(
                    label: context.messages.dailyOsEndTime,
                    time: _endTime,
                    onTap: _selectEndTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingMedium),

            // Duration display
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _formatDuration(_duration),
                  style: context.textTheme.labelLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.messages.dailyOsCancel),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedCategory != null && _isValidTimeRange
                        ? _handleAdd
                        : null,
                    child: Text(context.messages.dailyOsAddBlock),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingMedium),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      if (mins == 0) return '${hours}h';
      return '${hours}h ${mins}m';
    }
    return '${duration.inMinutes}m';
  }
}

/// Time selection widget.
class _TimeSelector extends StatelessWidget {
  const _TimeSelector({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
