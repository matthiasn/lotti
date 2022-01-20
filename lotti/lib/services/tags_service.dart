import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';

class TagsService {
  late final JournalDb db;
  late final Stream<List<TagDefinition>> stream;

  Map<String, TagDefinition> tagsById = {};
  Map<String, TagDefinition> tagsByName = {};

  TagsService() {
    db = getIt<JournalDb>();
    stream = db.watchTags();

    stream.listen((List<TagDefinition> tagDefinitions) {
      tagsById.clear();
      tagDefinitions.forEach((tagDefinition) {
        tagsById[tagDefinition.id] = tagDefinition;
        tagsByName[tagDefinition.tag] = tagDefinition;
      });
    });
  }

  TagDefinition? getTagById(String id) {
    return tagsById[id];
  }

  TagDefinition? getTagByName(String name) {
    return tagsByName[name];
  }
}
