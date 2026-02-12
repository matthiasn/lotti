import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/features/settings/ui/widgets/measurables/measurable_type_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_stream.dart';

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
      definitionCard: (int index, MeasurableDataType dataType) {
        return MeasurableTypeCard(item: dataType);
      },
    );
  }
}
