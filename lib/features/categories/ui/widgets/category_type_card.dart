import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CategoryTypeCard extends StatelessWidget {
  const CategoryTypeCard(
    this.categoryDefinition, {
    required this.onTap,
    super.key,
  });

  final CategoryDefinition categoryDefinition;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      onTap: onTap,
      title: categoryDefinition.name,
      leading: CategoryColorIcon(categoryDefinition.id),
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

class CategoryTypeNavCard extends StatelessWidget {
  const CategoryTypeNavCard(
    this.categoryDefinition, {
    required this.index,
    super.key,
  });

  final CategoryDefinition categoryDefinition;
  final int index;

  @override
  Widget build(BuildContext context) {
    return CategoryTypeCard(
      categoryDefinition,
      onTap: () => beamToNamed('/settings/categories/${categoryDefinition.id}'),
    );
  }
}
