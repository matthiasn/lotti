import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

class TagsService {
  TagsService() {
    _db = getIt<JournalDb>();
    stream = _db.watchTags();

    stream.listen((List<TagEntity> tagEntities) {
      tagsById.clear();
      for (final tagEntity in tagEntities) {
        tagsById[tagEntity.id] = tagEntity;
      }
    });
  }

  late final JournalDb _db;
  late final Stream<List<TagEntity>> stream;
  String? _clipboardCopiedId;
  String? match;
  Map<String, TagEntity> tagsById = {};

  TagEntity? getTagById(String id) {
    return tagsById[id];
  }

  List<String> getFilteredStoryTagIds(List<String>? tagIds) {
    final storyTagIds = <String>[];

    for (final tagId in tagIds ?? <String>[]) {
      final tag = getTagById(tagId);
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
    final tags = <String>[];

    if (_clipboardCopiedId != null) {
      final copiedFrom = await _db.journalEntityById(_clipboardCopiedId!);

      if (copiedFrom != null) {
        copiedFrom.meta.tagIds?.forEach(tags.add);
      }
    }

    return tags;
  }

  Future<List<TagEntity>> getMatchingTags(
    String match, {
    int limit = 1000,
    bool inactive = false,
  }) async {
    return _db.getMatchingTags(match, limit: limit, inactive: inactive);
  }

  Stream<List<TagEntity>> watchTags() {
    return _db.watchTags();
  }

  // ignore: use_setters_to_change_properties
  void setClipboard(String copiedEntryId) {
    _clipboardCopiedId = copiedEntryId;
  }
}
