import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/tags_service.dart';

import 'conversions.dart';

class Maintenance {
  final JournalDb _db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  Future<void> recreateTaggedLinks() async {
    await createDbBackup();

    int count = await _db.getJournalCount();
    int pageSize = 100;
    int pages = (count / pageSize).ceil();

    for (int page = 0; page <= pages; page++) {
      List<JournalDbEntity> dbEntities =
          await _db.orderedJournal(pageSize, page * pageSize).get();

      List<JournalEntity> entries = entityStreamMapper(dbEntities);
      for (JournalEntity entry in entries) {
        await _db.addTagged(entry);
      }
    }
  }

  Future<void> recreateStoryAssignment() async {
    await createDbBackup();

    final int count = await _db.getJournalCount();
    const int pageSize = 100;
    final int pages = (count / pageSize).ceil();

    for (int page = 0; page <= pages; page++) {
      List<JournalDbEntity> dbEntities =
          await _db.orderedJournal(pageSize, page * pageSize).get();

      List<JournalEntity> entries = entityStreamMapper(dbEntities);
      for (JournalEntity entry in entries) {
        List<String>? linkedTagIds = entry.meta.tagIds;

        List<String> storyTags =
            tagsService.getFilteredStoryTagIds(linkedTagIds);

        List<JournalEntity> linkedEntities =
            await _db.getLinkedEntities(entry.meta.id);

        for (JournalEntity linked in linkedEntities) {
          await persistenceLogic.addTags(
            journalEntityId: linked.meta.id,
            addedTagIds: storyTags,
          );
        }
      }
    }
  }

  Future<void> deleteTaggedLinks() async {
    await createDbBackup();
    await _db.deleteTagged();
  }

  Future<void> deleteEditorDb() async {
    final file = await getEditorDbFile();
    file.deleteSync();
  }
}
