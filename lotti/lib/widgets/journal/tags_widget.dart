import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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
    return StreamBuilder<List<TagDefinition>>(
      stream: db.watchTags(),
      builder: (
        BuildContext context,
        // This stream is not used, the StreamBuilder is only here
        // to trigger updates when any tag changes. In that case,
        // data in the tags service will already have been updated.
        AsyncSnapshot<List<TagDefinition>> _,
      ) {
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

              void addTagIds(List<String> addedTagIds) {
                List<String> existingTagIds = liveEntity.meta.tagIds ?? [];
                List<String> tagIds = [...existingTagIds];
                for (String tagId in addedTagIds) {
                  if (!tagIds.contains(tagId)) {
                    tagIds.add(tagId);
                  }
                }

                if (existingTagIds != tagIds) {
                  Metadata newMeta = liveEntity.meta.copyWith(
                    tagIds: tagIds,
                  );
                  context
                      .read<PersistenceCubit>()
                      .updateJournalEntity(liveEntity, newMeta);
                }
              }

              void removeTagId(String tagId) {
                List<String> existingTagIds = liveEntity.meta.tagIds ?? [];
                context.read<PersistenceCubit>().updateJournalEntity(
                      liveEntity,
                      liveEntity.meta.copyWith(
                        tagIds: existingTagIds
                            .where((String id) => (id != tagId))
                            .toList(),
                      ),
                    );
              }

              TextEditingController controller = TextEditingController();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 8,
                      top: 4,
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            'Tags:',
                            style: formLabelStyle,
                          ),
                        ),
                        Expanded(
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
                                addTagIds([tagId]);
                                controller.clear();
                              },
                              autofocus: false,
                              style:
                                  DefaultTextStyle.of(context).style.copyWith(
                                        color: AppColors.entryTextColor,
                                        fontFamily: 'Oswald',
                                        fontSize: 20.0,
                                      ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0)),
                              ),
                            ),
                            suggestionsCallback: (String pattern) async {
                              return db.getMatchingTags(pattern.trim());
                            },
                            suggestionsBoxDecoration: SuggestionsBoxDecoration(
                              color: AppColors.headerBgColor,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            itemBuilder: (context, TagEntity tagEntity) {
                              return ListTile(
                                title: Text(
                                  tagEntity.tag,
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
                            onSuggestionSelected: (TagEntity tagSuggestion) {
                              addTagIds([tagSuggestion.id]);
                              controller.clear();
                            },
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 24.0,
                                top: 16.0,
                                bottom: 16.0,
                              ),
                              child: Icon(
                                MdiIcons.contentCopy,
                                color: AppColors.entryTextColor,
                              ),
                            ),
                            onTap: () {
                              if (liveEntity.meta.tagIds != null) {
                                HapticFeedback.heavyImpact();
                                tagsService
                                    .setClipboard(liveEntity.meta.tagIds!);
                              }
                            },
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 16.0,
                                top: 16.0,
                                bottom: 16.0,
                              ),
                              child: Icon(
                                MdiIcons.contentPaste,
                                color: AppColors.entryTextColor,
                              ),
                            ),
                            onTap: () {
                              addTagIds(tagsService.getClipboard());
                              HapticFeedback.heavyImpact();
                            },
                          ),
                        ),
                      ],
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
                                      right: 2,
                                      bottom: 2,
                                    ),
                                    color: tagDefinition.private
                                        ? AppColors.private
                                        : AppColors.tagColor,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tagDefinition.tag,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontFamily: 'Oswald',
                                          ),
                                        ),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            child: const Icon(
                                              MdiIcons.close,
                                              size: 20,
                                            ),
                                            onTap: () {
                                              removeTagId(tagDefinition.id);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList()),
                  ),
                ],
              );
            });
      },
    );
  }
}
