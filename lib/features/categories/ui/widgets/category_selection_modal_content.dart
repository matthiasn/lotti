import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_create_modal.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';
import 'package:lotti/features/categories/ui/widgets/category_type_card.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/search/lotti_search_bar.dart';

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

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: LottiSearchBar(
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
          if (filteredCategories.isEmpty && searchQuery.isNotEmpty)
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
              child: ListView(
                padding: EdgeInsets.zero,
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
          if (!widget.multiSelect && widget.initialCategoryId != null)
            SettingsCard(
              onTap: () => widget.onCategorySelected(null),
              title: 'clear',
              titleColor: context.colorScheme.outline,
              leading: Icon(
                Icons.clear,
                color: context.colorScheme.outline,
              ),
            ),
          if (widget.multiSelect && widget.showDoneButton)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final cache = getIt<EntitiesCacheService>();
                        final categories = selectedIds
                            .map(cache.getCategoryById)
                            .whereType<CategoryDefinition>()
                            .toList();
                        Navigator.of(context).pop(categories);
                      },
                      child: Text(context.messages.doneButton),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
