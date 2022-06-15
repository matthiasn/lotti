import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/tags_widget.dart';

class TagsSearchWidget extends StatelessWidget {
  TagsSearchWidget({
    super.key,
    required this.addTag,
  });

  final JournalDb _db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();
  final void Function(String addedTag) addTag;

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
        final controller = TextEditingController();

        return Expanded(
          child: TypeAheadField(
            textFieldConfiguration: TextFieldConfiguration(
              autocorrect: false,
              controller: controller,
              onSubmitted: (String tag) async {},
              style: DefaultTextStyle.of(context).style.copyWith(
                    color: Colors.white,
                    fontFamily: 'Oswald',
                    fontSize: 14,
                  ),
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              borderRadius: BorderRadius.circular(8),
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
                    fontSize: 20,
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
  SelectedTagsWidget({
    required this.tagIds,
    required this.removeTag,
    super.key,
  });

  final JournalDb _db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();

  final List<String> tagIds;
  final void Function(String) removeTag;

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
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: tagIds.map((String tagId) {
              final tagEntity = tagsService.getTagById(tagId);
              if (tagEntity == null) {
                return const SizedBox.shrink();
              }
              return TagWidget(
                tagEntity: tagEntity,
                onTapRemove: () {
                  removeTag(tagEntity.id);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
