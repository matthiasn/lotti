import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/categories/state/category_task_count_provider.dart';
import 'package:lotti/features/categories/ui/widgets/category_create_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

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

/// Categories list page using [DesignSystemListItem] in a grouped container.
///
/// Each category row shows an icon badge, category name, task count subtitle,
/// optional status icons (lock, visibility_off, star), and a chevron.
/// Above the list sits a [DesignSystemSearch] field that filters rows by
/// name (case-insensitive substring); the trailing FAB opens
/// [CategoryCreateModal] in a single-page modal so the create flow stays
/// inside the active tab instead of beaming through `SettingsLocation`
/// (which has no `projects`-style panel for the create route on desktop).
class CategoriesListPage extends ConsumerStatefulWidget {
  const CategoriesListPage({super.key});

  @override
  ConsumerState<CategoriesListPage> createState() => _CategoriesListPageState();
}

class _CategoriesListPageState extends ConsumerState<CategoriesListPage> {
  /// Trimmed search query — empty when the field is clear. The
  /// filter compares lower-cased on each rebuild; the trimmed form
  /// also drives the no-match empty-state message.
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SettingsPageHeader(
            title: context.messages.settingsCategoriesTitle,
            showBackButton: !isDesktopLayout(context),
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
      floatingActionButton: DesignSystemBottomNavigationFabPadding(
        child: DesignSystemFloatingActionButton(
          semanticLabel: context.messages.settingsCategoriesCreateTitle,
          onPressed: () => _showCreateCategoryModal(context),
        ),
      ),
    );
  }

  Future<void> _showCreateCategoryModal(BuildContext context) {
    return ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.createCategoryTitle,
      builder: (modalContext) => CategoryCreateModal(
        initialName: '',
        onCategoryCreated: (_) {
          // Stream provider refreshes the list automatically once the
          // category is persisted; the modal pops itself on success.
        },
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context,
    List<CategoryDefinition> categories,
  ) {
    final queryLower = _query.toLowerCase();
    final filtered =
        categories.where((category) {
          if (queryLower.isEmpty) return true;
          return category.name.toLowerCase().contains(queryLower);
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DesignSystemSearch(
            hintText: context.messages.settingsCategoriesSearchHint,
            // DS search fires `onChanged('')` when the user taps the
            // clear button, so the same setState path covers both the
            // typing and clearing transitions — no separate `onClear`
            // is needed.
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
      ),
      if (filtered.isEmpty)
        _buildEmptySliver(context, categories.isEmpty)
      else
        SliverToBoxAdapter(
          child: DesignSystemGroupedList(
            children: [
              for (final (index, category) in filtered.indexed)
                _CategoryListItem(
                  category: category,
                  showDivider: index < filtered.length - 1,
                  onTap: () => beamToNamed(
                    '/settings/categories/${category.id}',
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  /// Empty state. Two flavours: "no categories at all" (default) and
  /// "search returned nothing" (a query is active and no row matches).
  /// The search-empty flavour shows the active query so the user knows
  /// what they typed — same affordance as the labels page.
  Widget _buildEmptySliver(BuildContext context, bool noCategoriesAtAll) {
    if (!noCategoriesAtAll && _query.isNotEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: Theme.of(context).disabledColor,
                ),
                const SizedBox(height: 12),
                Text(
                  context.messages.settingsCategoriesNoMatchQuery(_query),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverFillRemaining(child: _buildEmptyState(context));
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
