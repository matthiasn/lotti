import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/modal/clean_filter_section.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:quiver/collection.dart';

class ExpandableTaskCategoryFilter extends StatefulWidget {
  const ExpandableTaskCategoryFilter({super.key});

  @override
  State<ExpandableTaskCategoryFilter> createState() =>
      _ExpandableTaskCategoryFilterState();
}

class _ExpandableTaskCategoryFilterState
    extends State<ExpandableTaskCategoryFilter> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final allCategories =
            getIt<EntitiesCacheService>().categoriesById.values.toList();
        final favoriteCategories =
            allCategories.where((c) => c.favorite ?? false).toList();
        final otherCategories =
            allCategories.where((c) => !(c.favorite ?? false)).toList();

        final categoriesToShow = _isExpanded
            ? [...favoriteCategories, ...otherCategories]
            : favoriteCategories;

        return CleanFilterSection(
          title: 'Categories',
          subtitle: 'Filter by task category',
          useGrid: true,
          crossAxisCount: 3,
          children: [
            // All chip
            ColoredCategoryChip(
              label: 'All',
              icon: Icons.select_all,
              isSelected: _isAllSelected(snapshot, allCategories),
              onTap: () => _toggleAll(context, snapshot, allCategories),
              color: context.colorScheme.primary,
            ),

            // Unassigned chip
            ColoredCategoryChip(
              label: 'Unassigned',
              icon: MdiIcons.labelOffOutline,
              isSelected: snapshot.selectedCategoryIds.contains('unassigned'),
              onTap: () => context
                  .read<JournalPageCubit>()
                  .toggleSelectedCategoryIds('unassigned'),
              color: context.colorScheme.outline,
            ),

            // Category chips
            ...categoriesToShow.map(
              (category) => ColoredCategoryChip(
                label: category.name,
                icon: Icons.label_outline,
                isSelected: snapshot.selectedCategoryIds.contains(category.id),
                onTap: () => context
                    .read<JournalPageCubit>()
                    .toggleSelectedCategoryIds(category.id),
                onLongPress: () {
                  final cubit = context.read<JournalPageCubit>();
                  cubit
                    ..selectedAllCategories()
                    ..toggleSelectedCategoryIds(category.id);
                },
                color: colorFromCssHex(category.color),
              ),
            ),

            // Show more/less button if there are non-favorite categories
            if (otherCategories.isNotEmpty)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: context.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isExpanded
                              ? 'Show less'
                              : 'Show ${otherCategories.length} more',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _isAllSelected(JournalPageState snapshot, List<dynamic> categories) {
    final selectedIds = snapshot.selectedCategoryIds;
    final allCategoryIds = categories.map((c) => c.id as String).toSet();
    return setsEqual(selectedIds, allCategoryIds);
  }

  void _toggleAll(BuildContext context, JournalPageState snapshot,
      List<dynamic> categories) {
    final cubit = context.read<JournalPageCubit>();
    final allCategoryIds = categories.map((c) => c.id as String).toSet();

    if (_isAllSelected(snapshot, categories)) {
      cubit.selectedAllCategories();
    } else {
      for (final categoryId in allCategoryIds) {
        if (!snapshot.selectedCategoryIds.contains(categoryId)) {
          cubit.toggleSelectedCategoryIds(categoryId as String);
        }
      }
    }
  }
}

/// A category chip with subtle color accents
class ColoredCategoryChip extends StatelessWidget {
  const ColoredCategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
    this.icon,
    this.onLongPress,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use color as accent, not as full background
    final backgroundColor = isSelected
        ? color.withValues(alpha: isDark ? 0.3 : 0.2)
        : colorScheme.surface;

    final borderColor = isSelected ? color : color.withValues(alpha: 0.3);

    final textColor = isSelected
        ? (isDark ? Colors.white : color.darken(0.2))
        : colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        onLongPress: onLongPress != null
            ? () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              }
            : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
              ] else ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension ColorUtils on Color {
  Color darken(double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
