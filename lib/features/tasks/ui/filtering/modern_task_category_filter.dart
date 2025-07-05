import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/modal/modern_filter_chip.dart';
import 'package:lotti/widgets/modal/modern_filter_section.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:quiver/collection.dart';

class ModernTaskCategoryFilter extends StatelessWidget {
  const ModernTaskCategoryFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final categories = getIt<EntitiesCacheService>().categoriesById.values;
        return ModernFilterSection(
          title: 'Categories',
          subtitle: 'Filter by task category',
          children: [
            ...categories.map(
              (category) => ModernTaskCategoryChip(
                categoryName: category.name,
                categoryId: category.id,
                color: colorFromCssHex(category.color),
              ),
            ),
            const ModernTaskCategoryAllChip(),
            const ModernTaskCategoryUnassignedChip(),
          ],
        );
      },
    );
  }
}

class ModernTaskCategoryChip extends StatelessWidget {
  const ModernTaskCategoryChip({
    required this.categoryName,
    required this.categoryId,
    required this.color,
    super.key,
  });

  final String categoryName;
  final String categoryId;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final isSelected = snapshot.selectedCategoryIds.contains(categoryId);

        return ModernFilterChip(
          label: categoryName,
          icon: Icons.label_rounded,
          isSelected: isSelected,
          onTap: () => cubit.toggleSelectedCategoryIds(categoryId),
          onLongPress: () {
            cubit
              ..selectedAllCategories()
              ..toggleSelectedCategoryIds(categoryId);
          },
          selectedColor: color,
        );
      },
    );
  }
}

class ModernTaskCategoryAllChip extends StatelessWidget {
  const ModernTaskCategoryAllChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final selectedIds = snapshot.selectedCategoryIds;
        final categories = getIt<EntitiesCacheService>().categoriesById.values;
        final allCategoryIds = categories.map((c) => c.id).toSet();
        final isSelected = setsEqual(selectedIds, allCategoryIds);

        return ModernFilterChip(
          label: 'All',
          icon: Icons.select_all_rounded,
          isSelected: isSelected,
          onTap: () {
            if (isSelected) {
              cubit.selectedAllCategories();
            } else {
              for (final categoryId in allCategoryIds) {
                if (!selectedIds.contains(categoryId)) {
                  cubit.toggleSelectedCategoryIds(categoryId);
                }
              }
            }
          },
          selectedColor: context.colorScheme.primary,
        );
      },
    );
  }
}

class ModernTaskCategoryUnassignedChip extends StatelessWidget {
  const ModernTaskCategoryUnassignedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final isSelected = snapshot.selectedCategoryIds.contains('unassigned');

        return ModernFilterChip(
          label: 'Unassigned',
          icon: MdiIcons.labelOffOutline,
          isSelected: isSelected,
          onTap: () => cubit.toggleSelectedCategoryIds('unassigned'),
          onLongPress: () {
            cubit
              ..selectedAllCategories()
              ..toggleSelectedCategoryIds('unassigned');
          },
          selectedColor: context.colorScheme.outline,
        );
      },
    );
  }
}
