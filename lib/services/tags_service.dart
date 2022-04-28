import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

class TagsService {
  late final JournalDb _db;
  late final Stream<List<TagEntity>> _stream;
  String? _clipboardCopiedId;

  Map<String, TagEntity> tagsById = {};

  TagsService() {
    _db = getIt<JournalDb>();
    _stream = _db.watchTags();

    _stream.listen((List<TagEntity> tagEntities) {
      tagsById.clear();
      for (TagEntity tagEntity in tagEntities) {
        tagsById[tagEntity.id] = tagEntity;
      }
    });
  }

  TagEntity? getTagById(String id) {
    return tagsById[id];
  }

  List<StoryTag> getAllStoryTags() {
    List<StoryTag> storyTags = [];

    for (TagEntity tag in tagsById.values) {
      tag.map(
        genericTag: (_) {},
        personTag: (_) {},
        storyTag: (StoryTag storyTag) {
          storyTags.add(storyTag);
        },
      );
    }

    return storyTags;
  }

  List<String> getFilteredStoryTagIds(List<String>? tagIds) {
    List<String> storyTagIds = [];

    for (String tagId in tagIds ?? []) {
      TagEntity? tag = getTagById(tagId);
      tag?.map(
        genericTag: (_) {},
        personTag: (_) {},
        storyTag: (StoryTag storyTag) {
          storyTagIds.add(storyTag.id);
        },
      );
    }

    return storyTagIds;
  }

  Future<List<String>> getClipboard() async {
    List<String> tags = [];

    if (_clipboardCopiedId != null) {
      JournalEntity? copiedFrom =
          await _db.journalEntityById(_clipboardCopiedId!);

      if (copiedFrom != null) {
        copiedFrom.meta.tagIds?.forEach((String tagId) {
          tags.add(tagId);
        });
      }
    }

    return tags;
  }

  void setClipboard(String copiedEntryId) {
    _clipboardCopiedId = copiedEntryId;
  }
}
