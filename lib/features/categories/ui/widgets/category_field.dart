import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/widgets/categories_type_card.dart';
import 'package:lotti/features/categories/ui/widgets/color_picker_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

typedef CategoryCallback = void Function(CategoryDefinition?);

class CategoryField extends StatelessWidget {
  const CategoryField({
    required this.categoryId,
    required this.onSave,
    super.key,
  });

  final String? categoryId;
  final CategoryCallback onSave;

  @override
  Widget build(BuildContext context) {
    final category = getIt<EntitiesCacheService>().getCategoryById(categoryId);
    final controller = TextEditingController()..text = category?.name ?? '';

    void onTap() {
      ModalUtils.showSinglePageModal(
        context: context,
        title: context.messages.habitCategoryLabel,
        builder: (BuildContext _) {
          return _CategorySelectionContent(
            onCategorySelected: (category) {
              onSave(category);
              Navigator.pop(context);
            },
          );
        },
      );
    }

    final categoryUndefined = category == null;
    final style = context.textTheme.titleMedium;

    return TextField(
      onTap: onTap,
      readOnly: true,
      focusNode: FocusNode(),
      controller: controller,
      decoration: inputDecoration(
        labelText: categoryUndefined ? '' : context.messages.habitCategoryLabel,
        semanticsLabel: 'Select category',
        themeData: Theme.of(context),
      ).copyWith(
        icon: ColorIcon(
          category != null
              ? colorFromCssHex(category.color)
              : context.colorScheme.outline.withAlpha(51),
        ),
        suffixIcon: categoryUndefined
            ? null
            : GestureDetector(
                child: Icon(
                  Icons.close_rounded,
                  color: style?.color,
                ),
                onTap: () {
                  controller.clear();
                  onSave(null);
                },
              ),
        hintText: context.messages.habitCategoryHint,
        hintStyle: style?.copyWith(
          color: context.colorScheme.outline.withAlpha(127),
        ),
        border: InputBorder.none,
      ),
      style: style,
    );
  }
}

class _CategorySelectionContent extends ConsumerStatefulWidget {
  const _CategorySelectionContent({
    required this.onCategorySelected,
  });

  final CategoryCallback onCategorySelected;

  @override
  ConsumerState<_CategorySelectionContent> createState() =>
      _CategorySelectionContentState();
}

class _CategorySelectionContentState
    extends ConsumerState<_CategorySelectionContent> {
  final searchController = TextEditingController();
  String searchQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _showColorPicker(String categoryName) async {
    if (!mounted) return;

    await ModalUtils.showSinglePageModal(
      context: context,
      title: context.messages.createCategoryTitle,
      builder: (BuildContext context) {
        return ColorPickerModal(
          onColorSelected: (color) async {
            final repository = ref.read(categoriesRepositoryProvider);
            final category = await repository.createCategory(
              name: categoryName,
              color: color,
            );
            widget.onCategorySelected(category);
            if (context.mounted) {
              Navigator.pop(context);
            }
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

    return Column(
      mainAxisSize: MainAxisSize.min,
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
          ),
        ),
        if (filteredCategories.isEmpty && searchQuery.isNotEmpty)
          SettingsCard(
            onTap: () => _showColorPicker(searchQuery),
            title: searchQuery,
            leading: Icon(
              Icons.add_circle_outline,
              color: context.colorScheme.primary,
            ),
          )
        else
          ...filteredCategories.map(
            (category) => SettingsCard(
              onTap: () => widget.onCategorySelected(category),
              title: category.name,
              leading: ColorIcon(
                colorFromCssHex(category.color),
              ),
            ),
          ),
      ],
    );
  }
}
