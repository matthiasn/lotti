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
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uuid/uuid.dart';

/// Bottom sheet for adding a new time budget.
class AddBudgetSheet extends ConsumerStatefulWidget {
  const AddBudgetSheet({required this.date, super.key});

  final DateTime date;

  static Future<void> show(BuildContext context, DateTime date) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddBudgetSheet(date: date),
    );
  }

  @override
  ConsumerState<AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<AddBudgetSheet> {
  CategoryDefinition? _selectedCategory;
  int _plannedMinutes = 60;

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

  Future<void> _handleAdd() async {
    final category = _selectedCategory;
    if (category == null) return;

    // Always await the future to ensure we have the data
    final dayPlanEntity = await ref.read(
      dayPlanControllerProvider(date: widget.date).future,
    );

    if (dayPlanEntity is! DayPlanEntry) {
      // Cannot determine existing budgets, don't allow add
      return;
    }

    final currentBudgets = dayPlanEntity.data.budgets;

    // Check for duplicate category
    final hasDuplicate = currentBudgets.any((b) => b.categoryId == category.id);
    if (hasDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.messages.dailyOsDuplicateBudget(category.name),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final budget = TimeBudget(
      id: const Uuid().v1(),
      categoryId: category.id,
      plannedMinutes: _plannedMinutes,
      sortOrder: currentBudgets.length,
    );

    await ref
        .read(dayPlanControllerProvider(date: widget.date).notifier)
        .addBudget(budget);

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
              context.messages.dailyOsAddBudget,
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
                  label: context.messages.dailyOsDuration30m,
                  isSelected: _plannedMinutes == 30,
                  onTap: () => setState(() => _plannedMinutes = 30),
                ),
                _DurationChip(
                  label: context.messages.dailyOsDuration1h,
                  isSelected: _plannedMinutes == 60,
                  onTap: () => setState(() => _plannedMinutes = 60),
                ),
                _DurationChip(
                  label: context.messages.dailyOsDuration2h,
                  isSelected: _plannedMinutes == 120,
                  onTap: () => setState(() => _plannedMinutes = 120),
                ),
                _DurationChip(
                  label: context.messages.dailyOsDuration3h,
                  isSelected: _plannedMinutes == 180,
                  onTap: () => setState(() => _plannedMinutes = 180),
                ),
                _DurationChip(
                  label: context.messages.dailyOsDuration4h,
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
                    onPressed: _selectedCategory != null ? _handleAdd : null,
                    child: Text(context.messages.dailyOsAddBudget),
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
