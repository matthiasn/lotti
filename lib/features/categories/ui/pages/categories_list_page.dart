import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_display.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/search/index.dart';

/// Categories list page using Riverpod for state management
///
/// This page displays all categories and allows navigation to individual
/// category details pages. It follows the same UI patterns as the AI Settings
/// pages for consistency.
class CategoriesListPage extends ConsumerStatefulWidget {
  const CategoriesListPage({super.key});

  @override
  ConsumerState<CategoriesListPage> createState() => _CategoriesListPageState();
}

class _CategoriesListPageState extends ConsumerState<CategoriesListPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      body: categoriesAsync.when(
        data: (categories) {
          final sortedCategories = categories.where((category) {
            if (_searchQuery.isEmpty) return true;
            return category.name.toLowerCase().contains(_searchQuery);
          }).toList()
            ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return CustomScrollView(
            slivers: [
              SettingsPageHeader(
                title: context.messages.settingsCategoriesTitle,
                showBackButton: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LottiSearchBar(
                    controller: _searchController,
                    hintText: 'Search categories...',
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                    },
                    onClear: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                ),
              ),
              if (categories.isEmpty)
                SliverFillRemaining(child: _buildEmptyState(context))
              else if (sortedCategories.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64, color: Theme.of(context).disabledColor),
                          const SizedBox(height: 16),
                          Text('No categories found',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: Theme.of(context).disabledColor)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final category = sortedCategories[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _CategoryListTile(
                            category: category,
                            onTap: () =>
                                _navigateToCategoryDetails(context, category),
                          ),
                        );
                      },
                      childCount: sortedCategories.length,
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => CustomScrollView(
          slivers: [
            SettingsPageHeader(
              title: context.messages.settingsCategoriesTitle,
              showBackButton: true,
            ),
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (error, stack) => CustomScrollView(
          slivers: [
            SettingsPageHeader(
              title: context.messages.settingsCategoriesTitle,
              showBackButton: true,
            ),
            SliverFillRemaining(
              child: _buildErrorState(context, error),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => beamToNamed('/settings/categories/create'),
        tooltip: context.messages.settingsCategoriesAddTooltip,
        child: const Icon(Icons.add),
      ),
    );
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

/// Individual category list tile widget
class _CategoryListTile extends StatelessWidget {
  const _CategoryListTile({
    required this.category,
    required this.onTap,
  });

  final CategoryDefinition category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ModernBaseCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CategoryIconDisplay(
          category: category,
        ),
        title: Text(
          category.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: _buildSubtitle(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (category.private)
              Icon(
                Icons.lock_outline,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            if (!category.active)
              Icon(
                Icons.visibility_off_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final features = <String>[];

    if (category.defaultLanguageCode != null) {
      features.add(context.messages.settingsCategoriesHasDefaultLanguage);
    }

    if (category.allowedPromptIds?.isNotEmpty ?? false) {
      features.add(context.messages.settingsCategoriesHasAiSettings);
    }

    if (category.automaticPrompts?.isNotEmpty ?? false) {
      features.add(context.messages.settingsCategoriesHasAutomaticPrompts);
    }

    if (features.isEmpty) {
      return null;
    }

    return Text(
      features.join(' • '),
      style: Theme.of(context).textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
