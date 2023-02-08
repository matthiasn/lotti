import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/definitions_list_page.dart';
import 'package:lotti/themes/utils.dart';
import 'package:lotti/widgets/create/add_tag_actions.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

class TagCard extends StatelessWidget {
  TagCard({
    required this.tagEntity,
    required this.index,
    super.key,
  });

  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final TagEntity tagEntity;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SettingsNavCard(
      path: '/settings/tags/${tagEntity.id}',
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(color: getTagColor(tagEntity), width: 20, height: 20),
      ),
      title: tagEntity.tag,
    );
  }
}

class TagsPage extends StatelessWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return DefinitionsListPage<TagEntity>(
      stream: getIt<JournalDb>().watchTags(),
      floatingActionButton: const RadialAddTagButtons(),
      title: localizations.settingsTagsTitle,
      getName: (tag) => tag.tag,
      definitionCard: (int index, TagEntity item) =>
          TagCard(tagEntity: item, index: index),
    );
  }
}
