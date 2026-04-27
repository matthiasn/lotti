import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_stream.dart';

/// Embeddable body alias for the Settings V2 detail pane (plan
/// step 8). See `CategoriesListBody` for the polish note about the
/// duplicate header.
class MeasurablesBody extends StatelessWidget {
  const MeasurablesBody({super.key});

  @override
  Widget build(BuildContext context) => const MeasurablesPage();
}

class MeasurablesPage extends StatelessWidget {
  const MeasurablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefinitionsListPage<MeasurableDataType>(
      stream: notificationDrivenStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {measurablesNotification, privateToggleNotification},
        fetcher: getIt<JournalDb>().getAllMeasurableDataTypes,
      ),
      floatingActionButton: FloatingAddIcon(
        createFn: () => beamToNamed('/settings/measurables/create'),
        semanticLabel: 'Add Measurable',
      ),
      title: context.messages.settingsMeasurablesTitle,
      getName: (dataType) => dataType.displayName,
      definitionCard:
          (
            int index,
            MeasurableDataType item, {
            required bool isLast,
          }) {
            return _MeasurableListItem(
              item: item,
              showDivider: !isLast,
            );
          },
    );
  }
}

class _MeasurableListItem extends StatelessWidget {
  const _MeasurableListItem({
    required this.item,
    required this.showDivider,
  });

  static const double _leadingIconSize = 24;

  final MeasurableDataType item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isPrivate = item.private ?? false;
    final isFavorite = item.favorite ?? false;
    final description = item.description;

    return DesignSystemListItem(
      title: item.displayName,
      subtitle: description.isNotEmpty ? description : item.unitName,
      leading: Icon(
        Icons.trending_up_rounded,
        size: _leadingIconSize,
        color: tokens.colors.text.mediumEmphasis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrivate)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Semantics(
                label: context.messages.privateLabel,
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          if (isFavorite)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Semantics(
                label: context.messages.favoriteLabel,
                child: Icon(
                  Icons.star,
                  color: tokens.colors.alert.warning.defaultColor,
                  size: 20,
                ),
              ),
            ),
          Icon(
            Icons.chevron_right_rounded,
            size: tokens.spacing.step6,
            color: tokens.colors.text.lowEmphasis,
          ),
        ],
      ),
      showDivider: showDivider,
      dividerIndent:
          tokens.spacing.step5 + _leadingIconSize + tokens.spacing.step3,
      onTap: () => beamToNamed('/settings/measurables/${item.id}'),
    );
  }
}
