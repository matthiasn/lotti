import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    AppLocalizations localizations = AppLocalizations.of(context)!;

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

            void addTagIds(List<String> addedTagIds) {
              persistenceLogic.addTags(
                journalEntityId: item.meta.id,
                addedTagIds: addedTagIds,
              );
            }

            void copyTags() {
              if (liveEntity.meta.tagIds != null) {
                HapticFeedback.heavyImpact();
                tagsService.setClipboard(liveEntity.meta.id);
              }
            }

            void pasteTags() async {
              List<String> tagsFromClipboard = await tagsService.getClipboard();
              addTagIds(tagsFromClipboard);
              HapticFeedback.heavyImpact();
            }

            TextEditingController controller = TextEditingController();

            void onTapAdd() {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                builder: (BuildContext context) {
                  return Container(
                    color: AppColors.headerBgColor,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 160,
                        top: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TagsListWidget(item: item),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  localizations.journalTagsLabel,
                                  style: formLabelStyle,
                                ),
                              ),
                              Expanded(
                                child: TypeAheadField(
                                  textFieldConfiguration:
                                      TextFieldConfiguration(
                                    textCapitalization: TextCapitalization.none,
                                    autocorrect: false,
                                    controller: controller,
                                    onSubmitted: (String tag) async {
                                      tag = tag.trim();
                                      String tagId = await persistenceLogic
                                          .addTagDefinition(tag);
                                      addTagIds([tagId]);
                                      controller.clear();
                                    },
                                    autofocus: false,
                                    style: DefaultTextStyle.of(context)
                                        .style
                                        .copyWith(
                                          color: AppColors.entryTextColor,
                                          fontFamily: 'Oswald',
                                          fontSize: 16.0,
                                        ),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0)),
                                    ),
                                  ),
                                  suggestionsCallback: (String pattern) async {
                                    return db.getMatchingTags(
                                      pattern.trim(),
                                      limit: isMobile ? 5 : 12,
                                    );
                                  },
                                  suggestionsBoxDecoration:
                                      SuggestionsBoxDecoration(
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
                                  onSuggestionSelected:
                                      (TagEntity tagSuggestion) {
                                    addTagIds([tagSuggestion.id]);
                                    controller.clear();
                                  },
                                ),
                              ),
                              IconButton(
                                onPressed: copyTags,
                                padding: const EdgeInsets.only(
                                  left: 24.0,
                                  top: 16.0,
                                  bottom: 16.0,
                                ),
                                icon: Icon(
                                  MdiIcons.contentCopy,
                                  color: AppColors.entryTextColor,
                                ),
                                tooltip: localizations.journalTagsCopyHint,
                              ),
                              IconButton(
                                onPressed: pasteTags,
                                padding: const EdgeInsets.only(
                                  left: 24.0,
                                  top: 16.0,
                                  bottom: 16.0,
                                ),
                                icon: Icon(
                                  MdiIcons.contentPaste,
                                  color: AppColors.entryTextColor,
                                ),
                                tooltip: localizations.journalTagsPasteHint,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TagsListWidget(item: item),
                IconButton(
                  onPressed: onTapAdd,
                  padding: const EdgeInsets.only(left: 24.0, right: 4),
                  icon: Icon(
                    MdiIcons.tagPlusOutline,
                    size: 32,
                    color: AppColors.entryTextColor,
                  ),
                  tooltip: localizations.journalTagPlusHint,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class TagsListWidget extends StatelessWidget {
  final JournalEntity item;
  final JournalDb db = getIt<JournalDb>();

  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  final TagsService tagsService = getIt<TagsService>();
  late final Stream<JournalEntity?> stream = db.watchEntityById(item.meta.id);

  TagsListWidget({
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

            void removeTagId(String tagId) {
              persistenceLogic.removeTag(
                journalEntityId: item.meta.id,
                tagId: tagId,
              );
            }

            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 24,
                maxWidth: MediaQuery.of(context).size.width - 80,
              ),
              child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: tagsFromTagIds
                      .map((TagEntity tagEntity) => TagWidget(
                            tagEntity: tagEntity,
                            onTapRemove: () {
                              removeTagId(tagEntity.id);
                            },
                          ))
                      .toList()),
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
    required this.onTapRemove,
  }) : super(key: key);

  final TagEntity tagEntity;
  final void Function()? onTapRemove;

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return GestureDetector(
      onDoubleTap: () {
        context.router.pushNamed('/settings/tags/${tagEntity.id}');
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(chipBorderRadius),
        child: Container(
          padding: chipPaddingClosable,
          color: getTagColor(tagEntity),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                tagEntity.tag,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Oswald',
                  color: AppColors.tagTextColor,
                ),
              ),
              IconButton(
                onPressed: onTapRemove,
                padding: const EdgeInsets.only(left: 4.0),
                constraints: const BoxConstraints(maxHeight: 16, maxWidth: 20),
                icon: Icon(
                  MdiIcons.close,
                  size: 16,
                  color: AppColors.tagTextColor,
                ),
                tooltip: localizations.journalTagsRemoveHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
