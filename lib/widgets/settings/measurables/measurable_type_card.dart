import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

const double iconSize = 24;

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
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Card(
        color: AppColors.headerBgColor,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: ListTile(
            contentPadding:
                const EdgeInsets.only(left: 24, top: 4, bottom: 12, right: 24),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.displayName,
                  style: definitionCardTitleStyle,
                ),
                const SizedBox(width: 8),
                Visibility(
                  visible: item.unitName.isNotEmpty,
                  child: Text(
                    '[${item.unitName}]',
                    style: definitionCardTitleStyle,
                  ),
                ),
                Expanded(child: Container()),
                Visibility(
                  visible: fromNullableBool(item.private),
                  child: Icon(
                    MdiIcons.security,
                    color: AppColors.error,
                    size: iconSize,
                  ),
                ),
                Visibility(
                  visible: fromNullableBool(item.favorite),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      MdiIcons.star,
                      color: AppColors.starredGold,
                      size: iconSize,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              item.description,
              style: TextStyle(
                color: AppColors.entryTextColor,
                fontFamily: 'Oswald',
                fontWeight: FontWeight.w200,
                fontSize: 16,
              ),
            ),
            onTap: () {
              context.router.push(
                EditMeasurableRoute(measurableId: item.id),
              );
            },
          ),
        ),
      ),
    );
  }
}
