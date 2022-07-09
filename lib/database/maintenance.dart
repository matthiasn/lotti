import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/sync/outbox_service.dart';

class Maintenance {
  final JournalDb _db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  Future<void> recreateTaggedLinks() async {
    await createDbBackup(journalDbFileName);

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
    await createDbBackup(journalDbFileName);

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

  Future<void> syncDefinitions() async {
    final outboxService = getIt<OutboxService>();
    final tags = await _db.watchTags().first;
    final measurables = await _db.watchMeasurableDataTypes().first;
    final dashboards = await _db.watchDashboards().first;

    for (final tag in tags) {
      await outboxService.enqueueMessage(
        SyncMessage.tagEntity(
          tagEntity: tag,
          status: SyncEntryStatus.update,
        ),
      );
    }
    for (final measurable in measurables) {
      await outboxService.enqueueMessage(
        SyncMessage.entityDefinition(
          entityDefinition: measurable,
          status: SyncEntryStatus.update,
        ),
      );
    }
    for (final dashboard in dashboards) {
      await outboxService.enqueueMessage(
        SyncMessage.entityDefinition(
          entityDefinition: dashboard,
          status: SyncEntryStatus.update,
        ),
      );
    }
  }

  Future<void> deleteTaggedLinks() async {
    await createDbBackup(journalDbFileName);
    await _db.deleteTagged();
  }

  Future<void> deleteEditorDb() async {
    final file = await getDatabaseFile(editorDbFileName);
    file.deleteSync();
  }

  Future<void> deleteLoggingDb() async {
    final file = await getDatabaseFile(loggingDbFileName);
    file.deleteSync();
  }
}
