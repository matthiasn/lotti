import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class SelectDashboardCategoryWidget extends StatelessWidget {
  const SelectDashboardCategoryWidget({
    required this.setCategory,
    required this.categoryId,
    super.key,
  });

  final void Function(String?) setCategory;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();

    return StreamBuilder<List<CategoryDefinition>>(
      stream: getIt<JournalDb>().watchCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? <CategoryDefinition>[]
          ..sortBy((category) => category.name);
        final categoriesById = <String, CategoryDefinition>{};

        for (final category in categories) {
          categoriesById[category.id] = category;
        }

        final category = categoriesById[categoryId];

        controller.text = category?.name ?? '';

        void onTap() {
          ModalUtils.showSinglePageModal<void>(
            context: context,
            title: context.messages.dashboardCategoryLabel,
            builder: (BuildContext _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...categories.map(
                    (category) => SettingsCard(
                      onTap: () {
                        setCategory(category.id);
                        Navigator.pop(context);
                      },
                      title: category.name,
                      leading: CategoryIconCompact(
                        category.id,
                        size: CategoryIconConstants.iconSizeMedium,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }

        final categoryUndefined = categoryId == null;
        final style = context.textTheme.titleMedium;

        return TextField(
          key: const Key('select_dashboard_category'),
          onTap: onTap,
          readOnly: true,
          focusNode: FocusNode(),
          controller: controller,
          decoration: inputDecoration(
            labelText: categoryUndefined
                ? ''
                : context.messages.dashboardCategoryLabel,
            semanticsLabel: 'Select category',
            themeData: Theme.of(context),
          ).copyWith(
            icon: category != null
                ? CategoryIconCompact(
                    category.id,
                  )
                : Container(
                    width: CategoryIconConstants.iconSizeSmall,
                    height: CategoryIconConstants.iconSizeSmall,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colorScheme.outline.withAlpha(
                        CategoryIconConstants.fallbackIconAlpha.toInt(),
                      ),
                    ),
                    child: Icon(
                      Icons.category_outlined,
                      size: CategoryIconConstants.iconSizeSmall *
                          CategoryIconConstants.fallbackIconSizeMultiplier,
                      color: context.colorScheme.outline,
                    ),
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
                      setCategory(null);
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
      },
    );
  }
}
