import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HabitsTypeCard extends StatelessWidget {
  const HabitsTypeCard({
    required this.item,
    required this.index,
    required this.color,
    super.key,
  });

  final HabitDefinition item;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: item.active ? 1 : 0.4,
      child: SettingsNavCard(
        path: '/settings/habits/by_id/${item.id}',
        title: item.name,
        leading: CategoryColorIcon(item.categoryId),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Visibility(
              visible: fromNullableBool(item.priority),
              child: const Icon(
                Icons.star,
                color: starredGold,
                size: settingsIconSize,
              ),
            ),
            Visibility(
              visible: fromNullableBool(item.private),
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(
                  MdiIcons.security,
                  color: context.colorScheme.error,
                  size: settingsIconSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
