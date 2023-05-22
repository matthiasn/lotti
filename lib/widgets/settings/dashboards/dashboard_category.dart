import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

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
    final localizations = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    return StreamBuilder<List<CategoryDefinition>>(
      stream: getIt<JournalDb>().watchCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? <CategoryDefinition>[];
        final categoriesById = <String, CategoryDefinition>{};

        for (final category in categories) {
          categoriesById[category.id] = category;
        }

        final category = categoriesById[categoryId];

        controller.text = category?.name ?? '';

        void onTap() {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (BuildContext _) {
              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                            setCategory(category.id);
                            Navigator.pop(context);
                          },
                          title: category.name,
                          leading: ColorIcon(
                            colorFromCssHex(category.color),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        }

        final categoryUndefined = categoryId == null;
        final style =
            categoryUndefined ? searchFieldHintStyle() : searchFieldStyle();

        return TextField(
          key: const Key('select_dashboard_category'),
          onTap: onTap,
          readOnly: true,
          focusNode: FocusNode(),
          controller: controller,
          decoration: inputDecoration(
            labelText:
                categoryUndefined ? '' : localizations.habitCategoryLabel,
            semanticsLabel: 'Select category',
          ).copyWith(
            icon: ColorIcon(
              category != null
                  ? colorFromCssHex(category.color)
                  : styleConfig().secondaryTextColor.withOpacity(0.2),
            ),
            suffixIcon: categoryUndefined
                ? null
                : GestureDetector(
                    child: Icon(
                      Icons.close_rounded,
                      color: style.color,
                    ),
                    onTap: () {
                      controller.clear();
                      setCategory(null);
                    },
                  ),
            hintText: localizations.habitCategoryHint,
            hintStyle: style,
            border: InputBorder.none,
          ),
          style: style,
          //onChanged: widget.onChanged,
        );
      },
    );
  }
}
