import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
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
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Card(
        color: getIt<ThemeService>().colors.headerBgColor,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: ListTile(
            contentPadding:
                const EdgeInsets.only(left: 24, top: 4, bottom: 12, right: 24),
            title: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 9,
                    child: Text(
                      item.displayName,
                      style: definitionCardTitleStyle,
                      softWrap: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Visibility(
                    visible: item.unitName.isNotEmpty,
                    child: Text(
                      '[${item.unitName}]',
                      style: definitionCardTitleStyle.copyWith(
                        fontWeight: FontWeight.w100,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Visibility(
                        visible: fromNullableBool(item.private),
                        child: Icon(
                          MdiIcons.security,
                          color: getIt<ThemeService>().colors.error,
                          size: settingsIconSize,
                        ),
                      ),
                      Visibility(
                        visible: fromNullableBool(item.favorite),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            MdiIcons.star,
                            color: getIt<ThemeService>().colors.starredGold,
                            size: settingsIconSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    item.description,
                    style: definitionCardSubtitleStyle,
                    softWrap: true,
                  ),
                ),
                Text(
                  aggregationLabel(item.aggregationType),
                  style: definitionCardSubtitleStyle,
                ),
              ],
            ),
            onTap: () {
              getIt<AppRouter>().push(
                EditMeasurableRoute(measurableId: item.id),
              );
            },
          ),
        ),
      ),
    );
  }
}
