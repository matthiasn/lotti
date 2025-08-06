import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CategoryTypeCard extends StatelessWidget {
  const CategoryTypeCard(
    this.categoryDefinition, {
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final CategoryDefinition categoryDefinition;
  final void Function() onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SettingsCard(
        onTap: onTap,
        title: categoryDefinition.name,
        leading: CategoryIconCompact(
          categoryDefinition.id, 
          size: CategoryIconConstants.iconSizeMedium,
        ),
        backgroundColor: selected
            ? context.colorScheme.outline.withAlpha(55)
            : Colors.transparent,
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
