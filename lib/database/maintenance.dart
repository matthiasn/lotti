import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/tags_service.dart';

class Maintenance {
  final JournalDb _db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  Future<void> recreateTaggedLinks() async {
    await createDbBackup();

    final count = await _db.getJournalCount();
    const pageSize = 100;
    final pages = (count / pageSize).ceil();

    for (var page = 0; page <= pages; page++) {
      final dbEntities =
          await _db.orderedJournal(pageSize, page * pageSize).get();

      final entries = entityStreamMapper(dbEntities);
      for (final entry in entries) {
        await _db.addTagged(entry);
      }
    }
  }

  Future<void> recreateStoryAssignment() async {
    await createDbBackup();

    final count = await _db.getJournalCount();
    const pageSize = 100;
    final pages = (count / pageSize).ceil();

    for (var page = 0; page <= pages; page++) {
      final dbEntities =
          await _db.orderedJournal(pageSize, page * pageSize).get();

      final entries = entityStreamMapper(dbEntities);
      for (final entry in entries) {
        final linkedTagIds = entry.meta.tagIds;

        final storyTags = tagsService.getFilteredStoryTagIds(linkedTagIds);

        final linkedEntities = await _db.getLinkedEntities(entry.meta.id);

        for (final linked in linkedEntities) {
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

  Future<void> deleteLoggingDb() async {
    final file = await getLoggingDbFile();
    file.deleteSync();
  }
}
