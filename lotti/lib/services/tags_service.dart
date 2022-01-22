import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';

class TagsService {
  late final JournalDb _db;
  late final Stream<List<TagDefinition>> _stream;
  List<String> _clipboard = [];

  Map<String, TagDefinition> tagsById = {};

  TagsService() {
    _db = getIt<JournalDb>();
    _stream = _db.watchTags();

    _stream.listen((List<TagDefinition> tagDefinitions) {
      tagsById.clear();
      for (TagDefinition tagDefinition in tagDefinitions) {
        tagsById[tagDefinition.id] = tagDefinition;
      }
    });
  }

  TagDefinition? getTagById(String id) {
    return tagsById[id];
  }

  List<String> getClipboard() {
    return _clipboard;
  }

  void setClipboard(List<String> tagIds) {
    _clipboard = tagIds;
  }
}
