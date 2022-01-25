import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagsSearchWidget extends StatelessWidget {
  final JournalDb db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();
  final void Function(TagEntity addedTag) addTag;

  TagsSearchWidget({
    Key? key,
    required this.addTag,
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
        TextEditingController controller = TextEditingController();

        return Expanded(
          child: TypeAheadField(
            textFieldConfiguration: TextFieldConfiguration(
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              controller: controller,
              onSubmitted: (String tag) async {},
              autofocus: false,
              style: DefaultTextStyle.of(context).style.copyWith(
                    color: AppColors.entryTextColor,
                    fontFamily: 'Oswald',
                    fontSize: 14.0,
                  ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            suggestionsCallback: (String pattern) async {
              return db.getMatchingTags(pattern.trim(), inactive: true);
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
              addTag(tagSuggestion);
              controller.clear();
            },
          ),
        );
      },
    );
  }
}

class SelectedTagsWidget extends StatelessWidget {
  final List<TagEntity> tags;
  final void Function(TagEntity) removeTag;
  SelectedTagsWidget({
    required this.tags,
    required this.removeTag,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: tags
              .map((TagEntity tagEntity) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 2,
                        bottom: 2,
                      ),
                      color: tagEntity.private
                          ? AppColors.private
                          : AppColors.tagColor,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tagEntity.tag,
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
                                removeTag(tagEntity);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList()),
    );
  }
}
