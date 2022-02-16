import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/tags_widget.dart';

class TagsSearchWidget extends StatelessWidget {
  final JournalDb _db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();
  final void Function(String addedTag) addTag;

  TagsSearchWidget({
    Key? key,
    required this.addTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TagEntity>>(
      stream: _db.watchTags(),
      builder: (
        BuildContext context,
        // This stream is not used, the StreamBuilder is only here
        // to trigger updates when any tag changes. In that case,
        // data in the tags service will already have been updated.
        AsyncSnapshot<List<TagEntity>> _,
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
                    color: Colors.white,
                    fontFamily: 'Oswald',
                    fontSize: 14.0,
                  ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            suggestionsCallback: (String pattern) async {
              return _db.getMatchingTags(
                pattern.trim(),
                inactive: true,
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
                    height: 1.2,
                    color: getTagColor(tagEntity),
                    fontWeight: FontWeight.normal,
                    fontSize: 20.0,
                  ),
                ),
              );
            },
            onSuggestionSelected: (TagEntity tagSuggestion) {
              addTag(tagSuggestion.id);
              controller.clear();
            },
          ),
        );
      },
    );
  }
}

class SelectedTagsWidget extends StatelessWidget {
  final JournalDb _db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();

  final List<String> tagIds;
  final void Function(String) removeTag;

  SelectedTagsWidget({
    required this.tagIds,
    required this.removeTag,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TagEntity>>(
      stream: _db.watchTags(),
      builder: (
        BuildContext context,
        // This stream is not used, the StreamBuilder is only here
        // to trigger updates when any tag changes. In that case,
        // data in the tags service will already have been updated.
        AsyncSnapshot<List<TagEntity>> _,
      ) {
        return Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: tagIds.map((String tagId) {
                TagEntity? tagEntity = tagsService.getTagById(tagId);
                if (tagEntity == null) {
                  return const SizedBox.shrink();
                }
                return TagWidget(
                  tagEntity: tagEntity,
                  onTap: () {
                    removeTag(tagEntity.id);
                  },
                );
              }).toList()),
        );
      },
    );
  }
}
