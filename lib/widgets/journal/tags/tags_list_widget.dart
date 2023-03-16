import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/widgets/journal/tags/tag_widget.dart';
import 'package:quiver/collection.dart';

class TagsListWidget extends StatelessWidget {
  TagsListWidget({this.parentTags, super.key});

  final TagsService tagsService = getIt<TagsService>();
  final Set<String>? parentTags;

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
        return BlocBuilder<EntryCubit, EntryState>(
          builder: (
            context,
            EntryState state,
          ) {
            final cubit = context.read<EntryCubit>();
            final item = cubit.entry;

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
                left: 14,
                right: 14,
                bottom: 5,
              ),
              child: ConstrainedBox(
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
                            cubit.removeTagId(tagEntity.id);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
