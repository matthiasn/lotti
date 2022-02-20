import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagsWidget extends StatelessWidget {
  final JournalEntity item;
  final JournalDb db = getIt<JournalDb>();

  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  final TagsService tagsService = getIt<TagsService>();
  late final Stream<JournalEntity?> stream = db.watchEntityById(item.meta.id);

  TagsWidget({
    required this.item,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TagEntity>>(
      stream: db.watchTags(),
      builder: (
        BuildContext context,
        // This stream is not used, the StreamBuilder is only here
        // to trigger updates when any tag changes. In that case,
        // data in the tags service will already have been updated.
        AsyncSnapshot<List<TagEntity>> _,
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
            List<TagEntity> tagsFromTagIds = [];

            for (String tagId in tagIds) {
              TagEntity? tagEntity = tagsService.getTagById(tagId);
              if (tagEntity != null) {
                tagsFromTagIds.add(tagEntity);
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
                persistenceLogic.updateJournalEntity(liveEntity, newMeta);
              }
            }

            void removeTagId(String tagId) {
              List<String> existingTagIds = liveEntity.meta.tagIds ?? [];
              persistenceLogic.updateJournalEntity(
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                              String tagId =
                                  await persistenceLogic.addTagDefinition(tag);
                              addTagIds([tagId]);
                              controller.clear();
                            },
                            autofocus: false,
                            style: DefaultTextStyle.of(context).style.copyWith(
                                  color: AppColors.entryTextColor,
                                  fontFamily: 'Oswald',
                                  fontSize: 16.0,
                                ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0)),
                            ),
                          ),
                          suggestionsCallback: (String pattern) async {
                            return db.getMatchingTags(
                              pattern.trim(),
                              limit: isMobile ? 5 : 12,
                            );
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
                                  height: 1,
                                  color: getTagColor(tagEntity),
                                  fontWeight: FontWeight.normal,
                                  fontSize: 16.0,
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
                              tagsService.setClipboard(liveEntity.meta.tagIds!);
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
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 24),
                  child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: tagsFromTagIds
                          .map((TagEntity tagEntity) => TagWidget(
                                tagEntity: tagEntity,
                                onTap: () {
                                  removeTagId(tagEntity.id);
                                },
                              ))
                          .toList()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class TagWidget extends StatelessWidget {
  const TagWidget({
    Key? key,
    required this.tagEntity,
    required this.onTap,
  }) : super(key: key);

  final TagEntity tagEntity;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.only(
          left: 8,
          right: 2,
          bottom: 2,
        ),
        color: getTagColor(tagEntity),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tagEntity.tag,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Oswald',
                color: AppColors.tagTextColor,
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                child: Icon(
                  MdiIcons.close,
                  size: 16,
                  color: AppColors.tagTextColor,
                ),
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
