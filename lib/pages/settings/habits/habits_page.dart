import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/habits/habits_type_card.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({this.initialSearchTerm, super.key});

  final String? initialSearchTerm;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoryDefinition>>(
      stream: getIt<JournalDb>().watchCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? <CategoryDefinition>[];
        final categoriesById = <String, CategoryDefinition>{};

        for (final category in categories) {
          categoriesById[category.id] = category;
        }

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
            final category = categoriesById[item.categoryId];

            return HabitsTypeCard(
              item: item,
              index: index,
              color: category != null
                  ? colorFromCssHex(category.color)
                  : context.colorScheme.onSecondary.withAlpha(51),
            );
          },
        );
      },
    );
  }
}
