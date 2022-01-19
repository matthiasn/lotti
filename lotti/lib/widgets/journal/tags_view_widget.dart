import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';

class TagsViewWidget extends StatelessWidget {
  final TagsService tagsService = getIt<TagsService>();

  TagsViewWidget({
    Key? key,
    required this.item,
  }) : super(key: key);

  final JournalEntity item;

  @override
  Widget build(BuildContext context) {
    List<String> tags = item.meta.tags ?? [];
    List<String> tagIds = item.meta.tagIds ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        children: [
          Wrap(
              spacing: 3,
              runSpacing: 2,
              children: tags
                  .map(
                    (String tag) => Padding(
                      padding: const EdgeInsets.only(bottom: 1.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 1,
                            horizontal: 4,
                          ),
                          color: Colors.white,
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'Oswald',
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList()),
          Wrap(
              spacing: 3,
              runSpacing: 2,
              children: tags
                  .map(
                    (String tag) => Padding(
                      padding: const EdgeInsets.only(bottom: 1.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 1,
                            horizontal: 4,
                          ),
                          color: AppColors.error,
                          child: Text(
                            tagsService.getTagByName(tag)?.tag ?? '---',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'Oswald',
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList()),
          Wrap(
              spacing: 3,
              runSpacing: 2,
              children: tags
                  .map(
                    (String tag) => Padding(
                      padding: const EdgeInsets.only(bottom: 1.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 1,
                            horizontal: 4,
                          ),
                          color: AppColors.entryBgColor,
                          child: Text(
                            tagsService.getTagByName(tag)?.tag ?? '---',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'Oswald',
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList()),
        ],
      ),
    );
  }
}
