import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/utils.dart';

class TagsViewWidget extends StatefulWidget {
  const TagsViewWidget({
    required this.item,
    super.key,
  });

  final JournalEntity item;

  @override
  State<TagsViewWidget> createState() => _TagsViewWidgetState();
}

class _TagsViewWidgetState extends State<TagsViewWidget> {
  final TagsService tagsService = getIt<TagsService>();

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
        final tagIds = widget.item.meta.tagIds ?? [];
        final tagsFromTagIds = <TagEntity>[];

        for (final tagId in tagIds) {
          final tagEntity = tagsService.getTagById(tagId);
          if (tagEntity != null) {
            tagsFromTagIds.add(tagEntity);
          }
        }

        if (tagsFromTagIds.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            // ignore: unnecessary_lambdas
            children: tagsFromTagIds.map((tag) => TagChip(tag)).toList(),
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
    return Chip(
      labelPadding: EdgeInsets.zero,
      label: Text(
        tagEntity.tag,
        style: const TextStyle(
          fontSize: fontSizeSmall,
          color: Colors.black,
        ),
      ),
      backgroundColor: getTagColor(tagEntity),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
