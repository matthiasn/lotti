import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class MeasurableTypeCard extends StatelessWidget {
  const MeasurableTypeCard({
    required this.item,
    required this.index,
    super.key,
  });

  final MeasurableDataType item;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SettingsNavCard(
      path: '/settings/measurables/${item.id}',
      title: item.displayName,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: fromNullableBool(item.private),
            child: Icon(
              MdiIcons.security,
              color: context.colorScheme.error,
              size: settingsIconSize,
            ),
          ),
          Visibility(
            visible: fromNullableBool(item.favorite),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                MdiIcons.star,
                color: starredGold,
                size: settingsIconSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
