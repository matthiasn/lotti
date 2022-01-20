import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:provider/src/provider.dart';

class TagsWidget extends StatelessWidget {
  final JournalEntity item;
  final JournalDb db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();
  late final Stream<JournalEntity?> stream = db.watchEntityById(item.meta.id);

  TagsWidget({
    required this.item,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JournalEntity?>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<JournalEntity?> snapshot,
        ) {
          JournalEntity? liveEntity = snapshot.data;
          if (liveEntity == null) {
            return const SizedBox.shrink();
          }

          List<String> tagIds = liveEntity.meta.tagIds ?? [];
          List<TagDefinition> tagsFromTagIds = [];

          for (String tagId in tagIds) {
            TagDefinition? tagDefinition = tagsService.getTagById(tagId);
            if (tagDefinition != null) {
              tagsFromTagIds.add(tagDefinition);
            }
          }

          void addTagId(String tagId) {
            List<String> existingTagIds = liveEntity.meta.tagIds ?? [];
            if (!existingTagIds.contains(tagId)) {
              Metadata newMeta = liveEntity.meta.copyWith(
                tagIds: [...existingTagIds, tagId],
              );
              context
                  .read<PersistenceCubit>()
                  .updateJournalEntity(liveEntity, newMeta);
            }
          }

          TextEditingController controller = TextEditingController();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: TypeAheadField(
                  textFieldConfiguration: TextFieldConfiguration(
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    controller: controller,
                    onSubmitted: (String tag) async {
                      tag = tag.trim();
                      String tagId = await context
                          .read<PersistenceCubit>()
                          .addTagDefinition(tag);
                      addTagId(tagId);
                      controller.clear();
                    },
                    autofocus: true,
                    style: DefaultTextStyle.of(context).style.copyWith(
                          color: AppColors.entryTextColor,
                          fontFamily: 'Oswald',
                          fontSize: 20.0,
                        ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  suggestionsCallback: (String pattern) async {
                    return db.getMatchingTags(pattern.trim());
                  },
                  suggestionsBoxDecoration: SuggestionsBoxDecoration(
                    color: AppColors.headerBgColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  itemBuilder: (context, TagDefinition tagDefinition) {
                    return ListTile(
                      title: Text(
                        tagDefinition.tag,
                        style: TextStyle(
                          fontFamily: 'Oswald',
                          height: 1.2,
                          color: AppColors.entryTextColor,
                          fontWeight: FontWeight.normal,
                          fontSize: 20.0,
                        ),
                      ),
                    );
                  },
                  onSuggestionSelected: (TagDefinition tagSuggestion) {
                    addTagId(tagSuggestion.id);
                    controller.clear();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tagsFromTagIds
                        .map((TagDefinition tagDefinition) => ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  right: 8,
                                  bottom: 2,
                                ),
                                color: AppColors.entryBgColor,
                                child: Text(
                                  tagDefinition.tag,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Oswald',
                                  ),
                                ),
                              ),
                            ))
                        .toList()),
              ),
            ],
          );
        });
  }
}
