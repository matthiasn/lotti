import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_stream.dart';

/// All measurable data types for the settings list. Co-located with its
/// only consumer.
final StreamProvider<List<MeasurableDataType>>
measurableDataTypesStreamProvider =
    StreamProvider.autoDispose<List<MeasurableDataType>>(
      (ref) => notificationDrivenStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {measurablesNotification, privateToggleNotification},
        fetcher: getIt<JournalDb>().getAllMeasurableDataTypes,
      ),
    );

/// Embeddable body alias for the Settings V2 detail pane (plan
/// step 8). See `CategoriesListBody` for the polish note about the
/// duplicate header.
class MeasurablesBody extends StatelessWidget {
  const MeasurablesBody({super.key});

  @override
  Widget build(BuildContext context) => const MeasurablesPage();
}

/// Settings list of all measurable data types.
///
/// Watches [measurableDataTypesStreamProvider] and renders it through the
/// shared [DefinitionsListPage] shell; rows beam to the per-type editor and
/// the create button to `/settings/measurables/create`.
class MeasurablesPage extends ConsumerWidget {
  const MeasurablesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    return DefinitionsListPage<MeasurableDataType>(
      itemsAsync: ref.watch(measurableDataTypesStreamProvider),
      title: messages.settingsMeasurablesTitle,
      searchHint: messages.settingsMeasurablesSearchHint,
      displayName: (dataType) => dataType.displayName,
      emptyIcon: Icons.trending_up_rounded,
      emptyTitle: messages.settingsMeasurablesEmptyState,
      emptyHint: messages.settingsMeasurablesEmptyStateHint,
      noMatchMessage: messages.settingsMeasurablesNoMatchQuery,
      errorTitle: messages.settingsMeasurablesErrorLoading,
      createLabel: messages.settingsMeasurablesCreateTitle,
      onCreate: () => beamToNamed('/settings/measurables/create'),
      itemBuilder: (context, dataType, {required bool showDivider}) =>
          _MeasurableListItem(item: dataType, showDivider: showDivider),
    );
  }
}

class _MeasurableListItem extends StatelessWidget {
  const _MeasurableListItem({
    required this.item,
    required this.showDivider,
  });

  final MeasurableDataType item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isPrivate = item.private ?? false;
    final isFavorite = item.favorite ?? false;
    final description = item.description.trim();

    return DesignSystemListItem(
      title: item.displayName,
      // Description or nothing: a bare unit ("ml") is an orphan and a
      // lowercase echo of the name reads like a bug. Units live in the
      // editor.
      subtitle: description.isNotEmpty ? description : null,
      // Neutral first-letter chip: rows become distinguishable instead of
      // decorated with one repeated glyph.
      leading: DefinitionIconChip(
        background: tokens.colors.background.level03,
        foreground: tokens.colors.text.mediumEmphasis,
        name: item.displayName,
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
                  Icons.star_rounded,
                  size: 18,
                  color: tokens.colors.text.mediumEmphasis,
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
          tokens.spacing.step5 +
          DefinitionIconChip.defaultSize +
          tokens.spacing.step3,
      onTap: () => beamToNamed('/settings/measurables/${item.id}'),
    );
  }
}
