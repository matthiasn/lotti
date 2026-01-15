import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Modal for editing an existing time budget.
class TimeBudgetEditModal extends ConsumerStatefulWidget {
  const TimeBudgetEditModal({
    required this.budget,
    required this.category,
    super.key,
  });

  final TimeBudget budget;
  final CategoryDefinition? category;

  static Future<void> show(
    BuildContext context,
    TimeBudget budget,
    CategoryDefinition? category,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TimeBudgetEditModal(
        budget: budget,
        category: category,
      ),
    );
  }

  @override
  ConsumerState<TimeBudgetEditModal> createState() =>
      _TimeBudgetEditModalState();
}

class _TimeBudgetEditModalState extends ConsumerState<TimeBudgetEditModal> {
  late int _plannedMinutes;

  @override
  void initState() {
    super.initState();
    _plannedMinutes = widget.budget.plannedMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
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

            // Title row with delete button
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
                    context.messages.dailyOsEditBudget,
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

            // Category display (read-only)
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

            // Duration selector
            Text(
              context.messages.dailyOsPlannedDuration,
              style: context.textTheme.labelLarge,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DurationChip(
                  label: '30m',
                  isSelected: _plannedMinutes == 30,
                  onTap: () => setState(() => _plannedMinutes = 30),
                ),
                _DurationChip(
                  label: '1h',
                  isSelected: _plannedMinutes == 60,
                  onTap: () => setState(() => _plannedMinutes = 60),
                ),
                _DurationChip(
                  label: '2h',
                  isSelected: _plannedMinutes == 120,
                  onTap: () => setState(() => _plannedMinutes = 120),
                ),
                _DurationChip(
                  label: '3h',
                  isSelected: _plannedMinutes == 180,
                  onTap: () => setState(() => _plannedMinutes = 180),
                ),
                _DurationChip(
                  label: '4h',
                  isSelected: _plannedMinutes == 240,
                  onTap: () => setState(() => _plannedMinutes = 240),
                ),
              ],
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

  Future<void> _handleSave() async {
    final updatedBudget = widget.budget.copyWith(
      plannedMinutes: _plannedMinutes,
    );

    final selectedDate = ref.read(dailyOsSelectedDateProvider);
    await ref
        .read(dayPlanControllerProvider(date: selectedDate).notifier)
        .updateBudget(updatedBudget);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.messages.dailyOsDeleteBudget),
        content: Text(context.messages.dailyOsDeleteBudgetConfirm),
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
          .removeBudget(widget.budget.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

/// Duration selection chip.
class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primaryContainer
              : context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? context.colorScheme.primary
                : context.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: context.textTheme.labelLarge?.copyWith(
            color: isSelected
                ? context.colorScheme.onPrimaryContainer
                : context.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
