import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/settings/categories/categories_type_card.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefinitionsListPage<CategoryDefinition>(
      stream: getIt<JournalDb>().watchCategories(),
      floatingActionButton: FloatingAddIcon(
        createFn: () => beamToNamed('/settings/categories/create'),
        semanticLabel: 'Add Category',
      ),
      title: context.messages.settingsCategoriesTitle,
      getName: (category) => category.name.toLowerCase(),
      definitionCard: (int index, CategoryDefinition categoryDefinition) =>
          CategoriesTypeCard(categoryDefinition, index: index),
    );
  }
}
