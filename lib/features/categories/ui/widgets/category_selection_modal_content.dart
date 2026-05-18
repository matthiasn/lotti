import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_create_modal.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';
import 'package:lotti/features/categories/ui/widgets/category_type_card.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class CategorySelectionModalContent extends ConsumerStatefulWidget {
  const CategorySelectionModalContent({
    required this.onCategorySelected,
    this.initialCategoryId,
    this.multiSelect = false,
    this.initiallySelectedCategoryIds,
    this.onMultiSelectionChanged,
    this.showDoneButton = true,
    super.key,
  });

  final CategoryCallback onCategorySelected;
  final String? initialCategoryId;
  final bool multiSelect;
  final Set<String>? initiallySelectedCategoryIds;

  /// Called after each toggle in multi-select mode with the current selection.
  final void Function(Set<String> selectedIds)? onMultiSelectionChanged;

  /// Whether to show the "Done" button in multi-select mode.
  final bool showDoneButton;

  @override
  ConsumerState<CategorySelectionModalContent> createState() =>
      CategorySelectionModalContentState();
}

class CategorySelectionModalContentState
    extends ConsumerState<CategorySelectionModalContent> {
  final searchController = TextEditingController();
  String searchQuery = '';
  late Set<String> selectedIds;

  @override
  void initState() {
    super.initState();
    selectedIds = {...?widget.initiallySelectedCategoryIds};
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// Replaces the current selection with [ids] and rebuilds.
  ///
  /// Does NOT fire [CategorySelectionModalContent.onMultiSelectionChanged]
  /// because it is intended for programmatic updates from a parent widget
  /// that already knows the new selection.
  void setSelectedIds(Set<String> ids) {
    setState(() {
      selectedIds = {...ids};
    });
  }

  void _onCategoryTap(CategoryDefinition category) {
    if (widget.multiSelect) {
      setState(() {
        if (selectedIds.contains(category.id)) {
          selectedIds.remove(category.id);
        } else {
          selectedIds.add(category.id);
        }
      });
      widget.onMultiSelectionChanged?.call({...selectedIds});
    } else {
      widget.onCategorySelected(category);
    }
  }

  Future<void> _showColorPicker(String categoryName) async {
    if (!mounted) return;

    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.createCategoryTitle,
      builder: (BuildContext context) {
        return CategoryCreateModal(
          initialName: categoryName,
          onCategoryCreated: (category) {
            widget.onCategorySelected(category);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = getIt<EntitiesCacheService>().sortedCategories;
    final filteredCategories = categories
        .where(
          (category) =>
              category.name.toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();

    final filteredWithoutSelected = filteredCategories
        .where((category) => category.id != widget.initialCategoryId)
        .toList();

    final favoriteCategories = filteredWithoutSelected
        .where((category) => category.favorite ?? false)
        .toList();

    final otherCategories = filteredWithoutSelected
        .where((category) => !(category.favorite ?? false))
        .toList();

    final initialCategory = filteredCategories
        .where((category) => category.id == widget.initialCategoryId)
        .firstOrNull;

    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = math.min(screenHeight * 0.9, 640).toDouble();

    final showsClearOption =
        !widget.multiSelect && widget.initialCategoryId != null;
    final showsDoneButton = widget.multiSelect && widget.showDoneButton;
    final showsBottomBar = showsClearOption || showsDoneButton;

    final showsEmptyAddState =
        filteredCategories.isEmpty && searchQuery.isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: DesignSystemSearch(
              controller: searchController,
              hintText: context.messages.categorySearchPlaceholder,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              onSubmitted: (value) {
                if (filteredCategories.isEmpty && value.isNotEmpty) {
                  _showColorPicker(value);
                }
              },
              onClear: () {
                setState(() {
                  searchQuery = '';
                });
              },
            ),
          ),
          if (!widget.multiSelect && initialCategory != null)
            CategoryTypeCard(
              initialCategory,
              onTap: () => Navigator.pop(context),
              selected: true,
            ),
          if (showsEmptyAddState)
            SettingsCard(
              onTap: () => _showColorPicker(searchQuery),
              title: searchQuery,
              titleColor: context.colorScheme.outline,
              leading: Icon(
                Icons.add_circle_outline,
                color: context.colorScheme.outline,
              ),
            )
          else
            Expanded(
              child: _CategoryListWithOptionalFooter(
                showsBottomBar: showsBottomBar,
                footer: showsBottomBar
                    ? _buildBottomBar(
                        context: context,
                        showsDoneButton: showsDoneButton,
                      )
                    : null,
                children: [
                  for (final category in favoriteCategories)
                    CategoryTypeCard(
                      category,
                      selected:
                          widget.multiSelect &&
                          selectedIds.contains(category.id),
                      onTap: () => _onCategoryTap(category),
                    ),
                  for (final category in otherCategories)
                    CategoryTypeCard(
                      category,
                      selected:
                          widget.multiSelect &&
                          selectedIds.contains(category.id),
                      onTap: () => _onCategoryTap(category),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar({
    required BuildContext context,
    required bool showsDoneButton,
  }) {
    if (showsDoneButton) {
      return FilledButton(
        onPressed: () {
          final cache = getIt<EntitiesCacheService>();
          final categories = selectedIds
              .map(cache.getCategoryById)
              .whereType<CategoryDefinition>()
              .toList();
          Navigator.of(context).pop(categories);
        },
        child: Text(context.messages.doneButton),
      );
    }
    return TextButton.icon(
      onPressed: () => widget.onCategorySelected(null),
      icon: const Icon(Icons.clear),
      label: Text(context.messages.clearButton),
    );
  }
}

/// Renders the category list and, when [footer] is non-null, overlays a
/// [DesignSystemGlassActionFooter] at the bottom with matching list inset
/// so the last row stays tappable as it scrolls behind the glass.
///
/// Skipping the Stack entirely when there is no footer keeps the widget
/// tree flat for the common single-select case.
class _CategoryListWithOptionalFooter extends StatelessWidget {
  const _CategoryListWithOptionalFooter({
    required this.showsBottomBar,
    required this.footer,
    required this.children,
  });

  final bool showsBottomBar;
  final Widget? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: EdgeInsets.only(
        bottom: showsBottomBar
            ? DesignSystemGlassActionFooter.reservedHeight
            : 0,
      ),
      children: children,
    );
    if (footer == null) {
      return list;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        list,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DesignSystemGlassActionFooter(child: footer!),
        ),
      ],
    );
  }
}
