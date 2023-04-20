import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/settings/measurables/measurable_type_card.dart';

class MeasurablesPage extends StatelessWidget {
  const MeasurablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DefinitionsListPage<MeasurableDataType>(
      stream: getIt<JournalDb>().watchMeasurableDataTypes(),
      floatingActionButton: FloatingAddIcon(
        createFn: () => beamToNamed('/settings/measurables/create'),
        semanticLabel: 'Add Measurable',
      ),
      title: localizations.settingsMeasurablesTitle,
      getName: (dataType) => dataType.displayName,
      definitionCard: (int index, MeasurableDataType dataType) {
        return MeasurableTypeCard(index: index, item: dataType);
      },
    );
  }
}
