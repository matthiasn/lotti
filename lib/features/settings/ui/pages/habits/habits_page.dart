import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/features/settings/ui/widgets/habits/habits_type_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_stream.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({this.initialSearchTerm, super.key});

  final String? initialSearchTerm;

  @override
  Widget build(BuildContext context) {
    return DefinitionsListPage<HabitDefinition>(
      stream: notificationDrivenStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {habitsNotification, privateToggleNotification},
        fetcher: getIt<JournalDb>().getAllHabitDefinitions,
      ),
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
