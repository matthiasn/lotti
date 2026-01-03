import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Filter tabs with underline indicator for selected state.
class ChecklistFilterTabs extends StatelessWidget {
  const ChecklistFilterTabs({
    required this.filter,
    required this.onFilterChanged,
    super.key,
  });

  final ChecklistFilter filter;
  final ValueChanged<ChecklistFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChecklistFilterTab(
          label: context.messages.taskStatusOpen,
          isSelected: filter == ChecklistFilter.openOnly,
          onTap: () => onFilterChanged(ChecklistFilter.openOnly),
        ),
        const SizedBox(width: 16),
        ChecklistFilterTab(
          label: context.messages.taskStatusAll,
          isSelected: filter == ChecklistFilter.all,
          onTap: () => onFilterChanged(ChecklistFilter.all),
        ),
      ],
    );
  }
}

/// A single filter tab with text and underline when selected.
class ChecklistFilterTab extends StatelessWidget {
  const ChecklistFilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? context.colorScheme.onSurface
        : context.colorScheme.outline;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Only horizontal padding - vertical alignment handled by parent row
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            // Underline - sits directly on divider (no extra spacing)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isSelected ? 1.0 : 0.0,
              child: Container(
                width: 44,
                height: 2,
                decoration: BoxDecoration(
                  color: context.colorScheme.onSurface,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
