import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';
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
    final categories = getIt<EntitiesCacheService>().sortedCategories;

    final controller = TextEditingController()..text = category?.name ?? '';

    void onTap() {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext _) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...categories.map(
                    (category) => SettingsCard(
                      onTap: () {
                        onSave(category);
                        Navigator.pop(context);
                      },
                      title: category.name,
                      leading: ColorIcon(
                        colorFromCssHex(category.color),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final categoryUndefined = category == null;
    final style = Theme.of(context).textTheme.titleMedium;

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
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          size: 24,
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
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
        border: InputBorder.none,
      ),
      style: style,
    );
  }
}
