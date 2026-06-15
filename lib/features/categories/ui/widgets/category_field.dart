import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';

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

    Future<void> onTap() async {
      final result = await showCategoryPicker(
        context: context,
        title: context.messages.habitCategoryLabel,
        currentCategoryId: categoryId,
      );
      // null = dismissed (no change); otherwise apply the pick or the clear
      // (categoryOrNull is null for an explicit "clear" row).
      if (result == null) return;
      onSave(result.categoryOrNull);
    }

    final categoryUndefined = category == null;
    final style = context.textTheme.titleMedium;

    return TextField(
      onTap: onTap,
      readOnly: true,
      focusNode: FocusNode(),
      controller: controller,
      decoration:
          inputDecoration(
            labelText: categoryUndefined
                ? ''
                : context.messages.habitCategoryLabel,
            semanticsLabel: 'Select category',
            themeData: Theme.of(context),
          ).copyWith(
            icon: CategoryIconCompact(
              categoryId,
              size: CategoryIconConstants.iconSizeMedium,
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
