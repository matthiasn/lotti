import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';

/// Categories list page using Riverpod for state management
///
/// This page displays all categories and allows navigation to individual
/// category details pages. It follows the same UI patterns as the AI Settings
/// pages for consistency.
class CategoriesListPage extends ConsumerWidget {
  const CategoriesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.messages.settingsCategoriesTitle),
        elevation: 0,
      ),
      body: categoriesAsync.when(
        data: (categories) => _buildCategoriesList(context, categories),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => beamToNamed('/settings/categories/create'),
        tooltip: context.messages.settingsCategoriesAddTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoriesList(
    BuildContext context,
    List<CategoryDefinition> categories,
  ) {
    if (categories.isEmpty) {
      return _buildEmptyState(context);
    }

    // Sort categories by name
    final sortedCategories = List<CategoryDefinition>.from(categories)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _CategoryListTile(
            category: category,
            onTap: () => _navigateToCategoryDetails(context, category),
          ),
        );
      },
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
    return Card(
      elevation: 1,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colorFromCssHex(
            category.color,
            substitute: Theme.of(context).colorScheme.primary,
          ),
          child: Text(
            category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(category.name),
        subtitle: _buildSubtitle(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (category.private)
              Icon(
                Icons.lock_outline,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
            if (!category.active)
              Icon(
                Icons.visibility_off_outlined,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
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
