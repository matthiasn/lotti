import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:provider/src/provider.dart';

class TagsWidget extends StatelessWidget {
  final JournalEntity item;
  final JournalDb db = getIt<JournalDb>();
  late final Stream<JournalEntity?> stream = db.watchEntityById(item.meta.id);

  TagsWidget({
    required this.item,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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

          List<String> tags = liveEntity.meta.tags ?? [];

          void addTag(String tag) {
            List<String> existingTags = liveEntity.meta.tags ?? [];
            if (!existingTags.contains(tag)) {
              Metadata newMeta = liveEntity.meta.copyWith(
                tags: [...existingTags, tag],
              );
              context
                  .read<PersistenceCubit>()
                  .updateJournalEntity(liveEntity, newMeta);
            }
          }

          TextEditingController controller = TextEditingController();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: TypeAheadField(
                  textFieldConfiguration: TextFieldConfiguration(
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    controller: controller,
                    onSubmitted: (String tag) {
                      tag = tag.trim();
                      context.read<PersistenceCubit>().addTagDefinition(tag);
                      addTag(tag);
                      controller.clear();
                    },
                    autofocus: true,
                    style: DefaultTextStyle.of(context)
                        .style
                        .copyWith(color: AppColors.entryTextColor),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  suggestionsCallback: (String pattern) async {
                    return db.getMatchingTags(pattern);
                  },
                  itemBuilder: (context, TagDefinition tagDefinition) {
                    return ListTile(
                      title: Text(tagDefinition.tag),
                    );
                  },
                  onSuggestionSelected: (TagDefinition tagSuggestion) {
                    addTag(tagSuggestion.tag);
                    controller.clear();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags
                        .map((String tag) => ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  right: 8,
                                  bottom: 2,
                                ),
                                color: AppColors.entryBgColor,
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Oswald',
                                  ),
                                ),
                              ),
                            ))
                        .toList()),
              ),
            ],
          );
        });
  }
}
