import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/categories/state/category_task_count_provider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/cards/index.dart';

/// Categories list page with redesigned tile layout.
///
/// Each category tile shows an icon badge, the category name, a task count
/// subtitle, an optional favorite star, and a chevron. The header has a
/// "< Back" button and a "+ Add category" action on the top row, with a
/// large "Categories" title below.
class CategoriesListPage extends ConsumerWidget {
  const CategoriesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.chevron_left),
                          label: Text(context.messages.promptGoBackButton),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              beamToNamed('/settings/categories/create'),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            context.messages.settingsCategoriesAddTooltip,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 0, 16),
                      child: Text(
                        context.messages.settingsCategoriesTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ...categoriesAsync.when(
            data: (categories) => _buildContentSlivers(context, categories),
            loading: () => [
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, stack) => [
              SliverFillRemaining(
                child: _buildErrorState(context, error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context,
    List<CategoryDefinition> categories,
  ) {
    final sortedCategories = categories.toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    return [
      if (categories.isEmpty)
        SliverFillRemaining(child: _buildEmptyState(context))
      else
        SliverPadding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final category = sortedCategories[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _CategoryListTile(
                    category: category,
                    onTap: () => _navigateToCategoryDetails(context, category),
                  ),
                );
              },
              childCount: sortedCategories.length,
            ),
          ),
        ),
    ];
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            context.messages.settingsCategoriesEmptyState,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.messages.settingsCategoriesEmptyStateHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).disabledColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              context.messages.settingsCategoriesErrorLoading,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCategoryDetails(
    BuildContext context,
    CategoryDefinition category,
  ) {
    beamToNamed('/settings/categories/${category.id}');
  }
}

/// Redesigned category list tile with icon badge, name, task count,
/// optional favorite star, status indicators, and chevron.
class _CategoryListTile extends ConsumerWidget {
  const _CategoryListTile({
    required this.category,
    required this.onTap,
  });

  final CategoryDefinition category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskCountAsync = ref.watch(
      categoryTaskCountProvider(category.id),
    );
    final categoryColor = colorFromCssHex(
      category.color,
      substitute: Theme.of(context).colorScheme.primary,
    );
    final isFavorite = category.favorite ?? false;

    return ModernBaseCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: _CategoryIconBadge(
          category: category,
          color: categoryColor,
        ),
        title: Text(
          category.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: taskCountAsync.when(
          data: (count) => Text(
            context.messages.settingsCategoriesTaskCount(count),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          loading: () => Text(
            '\u2014',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          error: (_, _) => null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (category.private)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (!category.active)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.visibility_off_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (isFavorite)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.star, color: Colors.amber, size: 20),
              ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded-square badge showing the category icon on a colored background.
///
/// Falls back to the first letter of the category name when no icon is set.
/// Automatically picks white or black foreground based on background brightness.
class _CategoryIconBadge extends StatelessWidget {
  const _CategoryIconBadge({
    required this.category,
    required this.color,
  });

  final CategoryDefinition category;
  final Color color;

  static const double _size = 48;
  static const double _borderRadius = 12;

  @override
  Widget build(BuildContext context) {
    final isDark =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final foreground = isDark ? Colors.white : Colors.black;

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      child: Center(
        child: category.icon != null
            ? Icon(
                category.icon!.iconData,
                color: foreground,
                size: _size * 0.5,
              )
            : Text(
                category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                  fontSize: _size * 0.4,
                ),
              ),
      ),
    );
  }
}
