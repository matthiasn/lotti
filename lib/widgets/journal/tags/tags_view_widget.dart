import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';

class TagsViewWidget extends StatelessWidget {
  TagsViewWidget({
    required this.item,
    super.key,
  });

  final TagsService tagsService = getIt<TagsService>();
  final JournalEntity item;

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
        final tagIds = item.meta.tagIds ?? [];
        final tagsFromTagIds = <TagEntity>[];

        for (final tagId in tagIds) {
          final tagEntity = tagsService.getTagById(tagId);
          if (tagEntity != null) {
            tagsFromTagIds.add(tagEntity);
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                // ignore: unnecessary_lambdas
                children: tagsFromTagIds.map((tag) => TagChip(tag)).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip(
    this.tagEntity, {
    super.key,
  });

  final TagEntity tagEntity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(chipBorderRadius),
        child: Container(
          padding: chipPadding,
          color: getTagColor(tagEntity),
          child: Text(
            tagEntity.tag,
            style: const TextStyle(fontSize: fontSizeSmall),
          ),
        ),
      ),
    );
  }
}
