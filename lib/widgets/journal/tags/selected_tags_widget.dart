import 'package:flutter/material.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/widgets/journal/tags/tag_widget.dart';

class SelectedTagsWidget extends StatelessWidget {
  SelectedTagsWidget({
    required this.tagIds,
    required this.removeTag,
    super.key,
  });

  final TagsService tagsService = getIt<TagsService>();

  final List<String> tagIds;
  final void Function(String) removeTag;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TagEntity>>(
      stream: tagsService.watchTags(),
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
