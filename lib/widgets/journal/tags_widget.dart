import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagAddIconWidget extends StatelessWidget {
  TagAddIconWidget({
    required this.itemId,
    super.key,
  });

  final String itemId;
  final JournalDb db = getIt<JournalDb>();

  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  final TagsService tagsService = getIt<TagsService>();
  late final Stream<JournalEntity?> stream = db.watchEntityById(itemId);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

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
            final item = snapshot.data;
            if (item == null) {
              return const SizedBox.shrink();
            }

            void addTagIds(List<String> addedTagIds) {
              persistenceLogic.addTags(
                journalEntityId: itemId,
                addedTagIds: addedTagIds,
              );
            }

            void copyTags() {
              if (item.meta.tagIds != null) {
                HapticFeedback.heavyImpact();
                tagsService.setClipboard(item.meta.id);
              }
            }

            Future<void> pasteTags() async {
              final tagsFromClipboard = await tagsService.getClipboard();
              addTagIds(tagsFromClipboard);
              await HapticFeedback.heavyImpact();
            }

            final controller = TextEditingController();

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
                  return ColoredBox(
                    color: AppColors.entryCardColor,
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
                          TagsListWidget(itemId),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  localizations.journalTagsLabel,
                                  style: formLabelStyle,
                                ),
                              ),
                              Expanded(
                                child: TypeAheadField(
                                  textFieldConfiguration:
                                      TextFieldConfiguration(
                                    autocorrect: false,
                                    controller: controller,
                                    onSubmitted: (String tag) async {
                                      tag = tag.trim();
                                      final tagId = await persistenceLogic
                                          .addTagDefinition(tag);
                                      addTagIds([tagId]);
                                      controller.clear();
                                    },
                                    style: DefaultTextStyle.of(context)
                                        .style
                                        .copyWith(
                                          color: AppColors.entryTextColor,
                                          fontFamily: 'Oswald',
                                          fontSize: 16,
                                        ),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
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
                                    color: AppColors.entryCardColor,
                                    borderRadius: BorderRadius.circular(8),
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
                                          fontSize: 16,
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
                                  left: 24,
                                  top: 16,
                                  bottom: 16,
                                ),
                                icon: const Icon(
                                  MdiIcons.contentCopy,
                                  color: AppColors.entryTextColor,
                                ),
                                tooltip: localizations.journalTagsCopyHint,
                              ),
                              IconButton(
                                onPressed: pasteTags,
                                padding: const EdgeInsets.only(
                                  left: 24,
                                  top: 16,
                                  bottom: 16,
                                ),
                                icon: const Icon(
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

            return IconButton(
              onPressed: onTapAdd,
              icon: const Icon(
                MdiIcons.tagPlusOutline,
                size: 24,
                color: AppColors.entryTextColor,
              ),
              tooltip: localizations.journalTagPlusHint,
            );
          },
        );
      },
    );
  }
}

class TagsListWidget extends StatelessWidget {
  TagsListWidget(this.itemId, {super.key});

  final String itemId;
  final JournalDb db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final TagsService tagsService = getIt<TagsService>();
  late final Stream<JournalEntity?> stream = db.watchEntityById(itemId);

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
            final item = snapshot.data;
            if (item == null) {
              return const SizedBox.shrink();
            }

            final tagIds = item.meta.tagIds ?? [];
            final tagsFromTagIds = <TagEntity>[];

            for (final tagId in tagIds) {
              final tagEntity = tagsService.getTagById(tagId);
              if (tagEntity != null) {
                tagsFromTagIds.add(tagEntity);
              }
            }

            void removeTagId(String tagId) {
              persistenceLogic.removeTag(
                journalEntityId: itemId,
                tagId: tagId,
              );
            }

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 24,
              ),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: tagsFromTagIds
                    .map(
                      (TagEntity tagEntity) => TagWidget(
                        tagEntity: tagEntity,
                        onTapRemove: () {
                          removeTagId(tagEntity.id);
                        },
                      ),
                    )
                    .toList(),
              ),
            );
          },
        );
      },
    );
  }
}

class TagWidget extends StatelessWidget {
  const TagWidget({
    super.key,
    required this.tagEntity,
    required this.onTapRemove,
  });

  final TagEntity tagEntity;
  final void Function()? onTapRemove;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return GestureDetector(
      onDoubleTap: () {
        pushNamedRoute('/settings/tags/${tagEntity.id}');
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(chipBorderRadius),
        child: Container(
          padding: chipPaddingClosable,
          color: getTagColor(tagEntity),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  tagEntity.tag,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Oswald',
                    color: AppColors.tagTextColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: onTapRemove,
                padding: const EdgeInsets.only(left: 4),
                constraints: const BoxConstraints(maxHeight: 16, maxWidth: 20),
                icon: const Icon(
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
