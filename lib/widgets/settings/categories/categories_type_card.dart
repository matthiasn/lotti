import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CategoriesTypeCard extends StatelessWidget {
  const CategoriesTypeCard(
    this.categoryDefinition, {
    required this.index,
    super.key,
  });

  final CategoryDefinition categoryDefinition;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SettingsNavCard(
      path: '/settings/categories/${categoryDefinition.id}',
      title: categoryDefinition.name,
      leading: ColorIcon(colorFromCssHex(categoryDefinition.color)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: fromNullableBool(categoryDefinition.private),
            child: Icon(
              MdiIcons.security,
              color: context.colorScheme.error,
              size: settingsIconSize,
            ),
          ),
          Visibility(
            visible: fromNullableBool(
              categoryDefinition.favorite ?? false,
            ),
            child: Icon(
              MdiIcons.star,
              color: starredGold,
              size: settingsIconSize,
            ),
          ),
        ],
      ),
    );
  }
}

class ColorIcon extends StatelessWidget {
  const ColorIcon(
    this.color, {
    this.size = 24.0,
    super.key,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Container(
        height: size,
        width: size,
        color: color,
      ),
    );
  }
}

class CategoryColorIcon extends StatelessWidget {
  const CategoryColorIcon(
    this.categoryId, {
    this.size = 24.0,
    super.key,
  });

  final String? categoryId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final category = getIt<EntitiesCacheService>().getCategoryById(categoryId);

    return ColorIcon(
      category != null
          ? colorFromCssHex(category.color)
          : context.colorScheme.outline.withAlpha(51),
      size: size,
    );
  }
}

class HabitCompletionColorIcon extends StatelessWidget {
  const HabitCompletionColorIcon(
    this.habitId, {
    this.size = 50.0,
    super.key,
  });

  final String? habitId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(habitId);

    return CategoryColorIcon(
      habitDefinition?.categoryId,
      size: size,
    );
  }
}
