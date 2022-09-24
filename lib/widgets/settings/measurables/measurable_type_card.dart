import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/settings/dashboards/dashboard_definition_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class MeasurableTypeCard extends StatelessWidget {
  const MeasurableTypeCard({
    super.key,
    required this.item,
    required this.index,
  });

  final MeasurableDataType item;
  final int index;

  @override
  Widget build(BuildContext context) {
    return DefinitionCard(
      beamTo: '/settings/measurables/${item.id}',
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 9,
            child: Text(
              item.displayName,
              style: definitionCardTitleStyle(),
              softWrap: true,
            ),
          ),
          const SizedBox(width: 8),
          const Spacer(),
          Row(
            children: [
              Visibility(
                visible: fromNullableBool(item.private),
                child: Icon(
                  MdiIcons.security,
                  color: colorConfig().alarm,
                  size: settingsIconSize,
                ),
              ),
              Visibility(
                visible: fromNullableBool(item.favorite),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    MdiIcons.star,
                    color: colorConfig().starredGold,
                    size: settingsIconSize,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
