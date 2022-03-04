import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

class TagsService {
  late final JournalDb _db;
  late final Stream<List<TagEntity>> _stream;
  List<String> _clipboard = [];

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

  List<String> getClipboard() {
    return _clipboard;
  }

  void setClipboard(List<String> tagIds) {
    _clipboard = tagIds;
  }
}
