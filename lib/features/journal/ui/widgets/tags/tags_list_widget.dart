import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tag_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:quiver/collection.dart';

class TagsListWidget extends ConsumerWidget {
  TagsListWidget({
    required this.entryId,
    this.parentTags,
    super.key,
  });

  final String entryId;
  final TagsService tagsService = getIt<TagsService>();
  final Set<String>? parentTags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    return StreamBuilder<List<TagEntity>>(
      stream: tagsService.watchTags(),
      builder: (
        BuildContext context,
        // This stream is not used, the StreamBuilder is only here
        // to trigger updates when any tag changes. In that case,
        // data in the tags service will already have been updated.
        AsyncSnapshot<List<TagEntity>> _,
      ) {
        final item = entryState?.entry;

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

        if (tagIds.isEmpty || setsEqual(tagIds.toSet(), parentTags)) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(
            top: 10,
            left: 5,
            right: 14,
            bottom: 5,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: max(MediaQuery.of(context).size.width - 24, 200),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: tagsFromTagIds
                  .map(
                    (TagEntity tagEntity) => TagWidget(
                      tagEntity: tagEntity,
                      onTapRemove: () {
                        notifier.removeTagId(tagEntity.id);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}
