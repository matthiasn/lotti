import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Modal for editing a planned time block.
class PlannedBlockEditModal extends ConsumerStatefulWidget {
  const PlannedBlockEditModal({
    required this.block,
    super.key,
  });

  final PlannedBlock block;

  static Future<void> show(BuildContext context, PlannedBlock block) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => PlannedBlockEditModal(block: block),
    );
  }

  @override
  ConsumerState<PlannedBlockEditModal> createState() =>
      _PlannedBlockEditModalState();
}

class _PlannedBlockEditModalState extends ConsumerState<PlannedBlockEditModal> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String? _categoryId;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _startTime = TimeOfDay.fromDateTime(widget.block.startTime);
    _endTime = TimeOfDay.fromDateTime(widget.block.endTime);
    _categoryId = widget.block.categoryId;
    _noteController = TextEditingController(text: widget.block.note);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryId = _categoryId;
    final category = categoryId != null
        ? getIt<EntitiesCacheService>().getCategoryById(categoryId)
        : null;
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
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: Text(
                    context.messages.dailyOsEditPlannedBlock,
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    MdiIcons.delete,
                    color: context.colorScheme.error,
                  ),
                  onPressed: _handleDelete,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLarge),

            // Time selection
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
                    onChanged: (time) => setState(() => _startTime = time),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMedium),
                  child: Icon(
                    MdiIcons.arrowRight,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _TimeSelector(
                    label: context.messages.dailyOsEndTime,
                    time: _endTime,
                    onChanged: (time) => setState(() => _endTime = time),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              _formatDuration(),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppTheme.spacingLarge),

            // Category display
            Text(
              context.messages.dailyOsCategory,
              style: context.textTheme.labelLarge,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: categoryColor.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSmall),
                  Text(
                    category?.name ?? context.messages.dailyOsUncategorized,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingLarge),

            // Note field
            Text(
              context.messages.dailyOsNote,
              style: context.textTheme.labelLarge,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: context.messages.dailyOsAddNote,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
              ),
              maxLines: 2,
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
                    onPressed: _handleSave,
                    child: Text(context.messages.dailyOsSave),
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

  String _formatDuration() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    if (durationMinutes <= 0) {
      return 'Invalid time range';
    }

    if (durationMinutes >= 60) {
      final hours = durationMinutes ~/ 60;
      final mins = durationMinutes % 60;
      if (mins == 0) return '$hours hour${hours == 1 ? '' : 's'}';
      return '${hours}h ${mins}m';
    }
    return '$durationMinutes minutes';
  }

  Future<void> _handleSave() async {
    final selectedDate = ref.read(dailyOsSelectedDateProvider);
    final baseDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final updatedBlock = widget.block.copyWith(
      startTime: baseDate.add(
        Duration(hours: _startTime.hour, minutes: _startTime.minute),
      ),
      endTime: baseDate.add(
        Duration(hours: _endTime.hour, minutes: _endTime.minute),
      ),
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
    );

    await ref
        .read(dayPlanControllerProvider(date: selectedDate).notifier)
        .updatePlannedBlock(updatedBlock);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.messages.dailyOsDeletePlannedBlock),
        content: Text(context.messages.dailyOsDeletePlannedBlockConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.messages.dailyOsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.error,
            ),
            child: Text(context.messages.dailyOsDelete),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && mounted) {
      final selectedDate = ref.read(dailyOsSelectedDateProvider);
      await ref
          .read(dayPlanControllerProvider(date: selectedDate).notifier)
          .removePlannedBlock(widget.block.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

/// Time selection button.
class _TimeSelector extends StatelessWidget {
  const _TimeSelector({
    required this.label,
    required this.time,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMedium,
          vertical: AppTheme.spacingSmall,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: context.colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(time),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
