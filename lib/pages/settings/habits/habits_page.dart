import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/settings/habits/habits_type_card.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DefinitionsListPage<HabitDefinition>(
      stream: getIt<JournalDb>().watchHabitDefinitions(),
      floatingActionButton: FloatingAddIcon(
        createFn: () => beamToNamed('/settings/habits/create'),
      ),
      title: localizations.settingsHabitsTitle,
      getName: (habitDefinition) => habitDefinition.name,
      definitionCard: (int index, HabitDefinition item) {
        return HabitsTypeCard(item: item, index: index);
      },
    );
  }
}
