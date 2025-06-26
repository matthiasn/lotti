import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/settings/habits/habits_type_card.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({this.initialSearchTerm, super.key});

  final String? initialSearchTerm;

  @override
  Widget build(BuildContext context) {
    return DefinitionsListPage<HabitDefinition>(
      stream: getIt<JournalDb>().watchHabitDefinitions(),
      floatingActionButton: FloatingAddIcon(
        createFn: () => beamToNamed('/settings/habits/create'),
        semanticLabel: 'Add Habit',
      ),
      title: context.messages.settingsHabitsTitle,
      getName: (habitDefinition) => habitDefinition.name,
      initialSearchTerm: initialSearchTerm,
      definitionCard: (int index, HabitDefinition item) {
        return HabitsTypeCard(item: item);
      },
    );
  }
}
