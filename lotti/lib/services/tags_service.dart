import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';

class TagsService {
  late final JournalDb db;
  late final Stream<List<TagDefinition>> stream;

  Map<String, TagDefinition> tagsById = {};

  TagsService() {
    db = getIt<JournalDb>();
    stream = db.watchTags();

    stream.listen((List<TagDefinition> tagDefinitions) {
      tagsById.clear();
      for (TagDefinition tagDefinition in tagDefinitions) {
        tagsById[tagDefinition.id] = tagDefinition;
      }
    });
  }

  TagDefinition? getTagById(String id) {
    return tagsById[id];
  }
}
