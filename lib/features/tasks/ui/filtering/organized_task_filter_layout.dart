import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/clean_task_list_toggle.dart';
import 'package:lotti/features/tasks/ui/filtering/clean_task_status_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/expandable_task_category_filter.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/clean_filter_chip.dart';

class OrganizedTaskFilterLayout extends StatelessWidget {
  const OrganizedTaskFilterLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task View Toggle with subtle background
          Container(
            color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: const CleanTaskListToggle(),
          ),
          
          const SizedBox(height: 24),
          
          // Quick Filters in a card-like container
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const QuickFiltersSection(),
          ),
          
          const SizedBox(height: 24),
          
          // Task Status Filter
          const CleanTaskStatusFilter(),
          
          const SizedBox(height: 8),
          
          // Categories Filter
          const ExpandableTaskCategoryFilter(),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Quick filters section with better organization
class QuickFiltersSection extends StatelessWidget {
  const QuickFiltersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Filters',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: QuickFilterButton(
                    icon: Icons.star,
                    label: 'Starred',
                    isSelected: snapshot.filters.contains(DisplayFilter.starredEntriesOnly),
                    selectedColor: starredGold,
                    onTap: () {
                      final filters = Set<DisplayFilter>.from(snapshot.filters);
                      if (filters.contains(DisplayFilter.starredEntriesOnly)) {
                        filters.remove(DisplayFilter.starredEntriesOnly);
                      } else {
                        filters.add(DisplayFilter.starredEntriesOnly);
                      }
                      cubit.setFilters(filters);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickFilterButton(
                    icon: Icons.flag,
                    label: 'Flagged',
                    isSelected: snapshot.filters.contains(DisplayFilter.flaggedEntriesOnly),
                    selectedColor: const Color(0xFFBA68C8),
                    onTap: () {
                      final filters = Set<DisplayFilter>.from(snapshot.filters);
                      if (filters.contains(DisplayFilter.flaggedEntriesOnly)) {
                        filters.remove(DisplayFilter.flaggedEntriesOnly);
                      } else {
                        filters.add(DisplayFilter.flaggedEntriesOnly);
                      }
                      cubit.setFilters(filters);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickFilterButton(
                    icon: Icons.lock,
                    label: 'Private',
                    isSelected: snapshot.filters.contains(DisplayFilter.privateEntriesOnly),
                    selectedColor: const Color(0xFFE57373),
                    onTap: () {
                      final filters = Set<DisplayFilter>.from(snapshot.filters);
                      if (filters.contains(DisplayFilter.privateEntriesOnly)) {
                        filters.remove(DisplayFilter.privateEntriesOnly);
                      } else {
                        filters.add(DisplayFilter.privateEntriesOnly);
                      }
                      cubit.setFilters(filters);
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A compact quick filter button
class QuickFilterButton extends StatelessWidget {
  const QuickFilterButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final backgroundColor = isSelected 
        ? selectedColor.withValues(alpha: isDark ? 0.3 : 0.2)
        : Colors.transparent;
    
    final borderColor = isSelected
        ? selectedColor
        : colorScheme.outline.withValues(alpha: 0.2);
    
    final contentColor = isSelected
        ? selectedColor
        : colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: contentColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: context.textTheme.labelSmall?.copyWith(
                  color: contentColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
