import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/categories/state/category_task_count_provider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';

/// Embeddable body alias for the Settings V2 detail pane (plan
/// step 8). The V1 page's internal `SettingsPageHeader` overlaps the
/// leaf-panel title for now; a headerless embedded mode comes in
/// step 10 polish. Until then the page renders with a minor visual
/// duplicate header that is functionally fine.
class CategoriesListBody extends StatelessWidget {
  const CategoriesListBody({super.key});

  @override
  Widget build(BuildContext context) => const CategoriesListPage();
}

/// Categories list on the shared [DefinitionsListPage] shell.
///
/// Each category row shows an icon badge, category name, task count
/// subtitle, optional status icons (lock, visibility_off, star), and a
/// chevron. The create FAB beams to the create page — the same
/// list → full-page flow as every other definition type (the V2 desktop
/// pane dispatches `/settings/categories/create` inline).
class CategoriesListPage extends ConsumerWidget {
  const CategoriesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    return DefinitionsListPage<CategoryDefinition>(
      itemsAsync: ref.watch(categoriesStreamProvider),
      title: messages.settingsCategoriesTitle,
      searchHint: messages.settingsCategoriesSearchHint,
      displayName: (category) => category.name,
      emptyIcon: Icons.category_outlined,
      emptyTitle: messages.settingsCategoriesEmptyState,
      emptyHint: messages.settingsCategoriesEmptyStateHint,
      noMatchMessage: messages.settingsCategoriesNoMatchQuery,
      errorTitle: messages.settingsCategoriesErrorLoading,
      createSemanticLabel: messages.settingsCategoriesCreateTitle,
      onCreate: () => beamToNamed('/settings/categories/create'),
      itemBuilder: (context, category, {required bool showDivider}) =>
          _CategoryListItem(
            category: category,
            showDivider: showDivider,
            onTap: () => beamToNamed('/settings/categories/${category.id}'),
          ),
    );
  }
}

/// A single category row using [DesignSystemListItem].
class _CategoryListItem extends ConsumerWidget {
  const _CategoryListItem({
    required this.category,
    required this.showDivider,
    required this.onTap,
  });

  final CategoryDefinition category;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskCountAsync = ref.watch(
      categoryTaskCountProvider(category.id),
    );
    final tokens = context.designTokens;
    final isFavorite = category.favorite ?? false;

    return DesignSystemListItem(
      title: category.name,
      subtitle: taskCountAsync.when(
        data: (count) => context.messages.settingsCategoriesTaskCount(count),
        loading: () => '—',
        error: (_, _) => '',
      ),
      leading: CategoryIconBadge(
        category: category,
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
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          if (!category.active)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.visibility_off_outlined,
                size: 18,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          if (isFavorite)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.star, color: Colors.amber, size: 20),
            ),
          Icon(
            Icons.chevron_right_rounded,
            size: tokens.spacing.step6,
            color: tokens.colors.text.lowEmphasis,
          ),
        ],
      ),
      showDivider: showDivider,
      dividerIndent:
          tokens.spacing.step5 +
          CategoryIconBadge.defaultSize +
          tokens.spacing.step3,
      onTap: onTap,
    );
  }
}

/// Rounded-square badge showing the category icon on a colored background.
///
/// Falls back to the first letter of the category name when no icon is set.
/// Automatically picks white or black foreground based on background brightness.
class CategoryIconBadge extends StatelessWidget {
  const CategoryIconBadge({
    required this.category,
    this.size = defaultSize,
    super.key,
  });

  final CategoryDefinition category;
  final double size;

  static const double defaultSize = 36;
  static const double _borderRadius = 10;

  @override
  Widget build(BuildContext context) {
    final color = colorFromCssHex(
      category.color,
      substitute: Theme.of(context).colorScheme.primary,
    );
    final isDark =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final foreground = isDark ? Colors.white : Colors.black;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      child: Center(
        child: category.icon != null
            ? Icon(
                category.icon!.iconData,
                color: foreground,
                size: size * 0.5,
              )
            : Text(
                category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.4,
                ),
              ),
      ),
    );
  }
}
