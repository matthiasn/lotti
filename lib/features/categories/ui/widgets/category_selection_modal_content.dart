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

class CategorySelectionModalContent extends ConsumerStatefulWidget {
  const CategorySelectionModalContent({
    required this.onCategorySelected,
    this.initialCategoryId,
    this.multiSelect = false,
    this.initiallySelectedCategoryIds,
    super.key,
  });

  final CategoryCallback onCategorySelected;
  final String? initialCategoryId;
  final bool multiSelect;
  final Set<String>? initiallySelectedCategoryIds;

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
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: context.messages.categorySearchPlaceholder,
                  prefixIcon: const Icon(Icons.search),
                ),
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
                        selected: widget.multiSelect &&
                            selectedIds.contains(category.id),
                        onTap: () {
                          if (widget.multiSelect) {
                            setState(() {
                              if (selectedIds.contains(category.id)) {
                                selectedIds.remove(category.id);
                              } else {
                                selectedIds.add(category.id);
                              }
                            });
                          } else {
                            widget.onCategorySelected(category);
                          }
                        },
                      ),
                    for (final category in otherCategories)
                      CategoryTypeCard(
                        category,
                        selected: widget.multiSelect &&
                            selectedIds.contains(category.id),
                        onTap: () {
                          if (widget.multiSelect) {
                            setState(() {
                              if (selectedIds.contains(category.id)) {
                                selectedIds.remove(category.id);
                              } else {
                                selectedIds.add(category.id);
                              }
                            });
                          } else {
                            widget.onCategorySelected(category);
                          }
                        },
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
            if (widget.multiSelect)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () {
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
        ));
  }
}
