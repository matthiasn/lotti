import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/settings/measurables/measurable_type_card.dart';

class MeasurablesPage extends StatelessWidget {
  const MeasurablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefinitionsListPage<MeasurableDataType>(
      stream: getIt<JournalDb>().watchMeasurableDataTypes(),
      floatingActionButton: FloatingAddIcon(
        showcaseKey: GlobalKey(),
        createFn: () => beamToNamed('/settings/measurables/create'),
        semanticLabel: 'Add Measurable',
      ),
      title: context.messages.settingsMeasurablesTitle,
      getName: (dataType) => dataType.displayName,
      definitionCard: (int index, MeasurableDataType dataType) {
        return MeasurableTypeCard(index: index, item: dataType);
      },
    );
  }
}
