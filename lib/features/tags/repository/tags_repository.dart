import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/lotti_logger.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/utils/file_utils.dart';

class TagsRepository {
  static JournalDb get _journalDb => getIt<JournalDb>();
  static TagsService get _tagsService => getIt<TagsService>();
  static PersistenceLogic get _persistenceLogic => getIt<PersistenceLogic>();
  static OutboxService get outboxService => getIt<OutboxService>();

  static Future<bool?> addTags({
    required String journalEntityId,
    required List<String> addedTagIds,
  }) async {
    try {
      final journalEntity = await _journalDb.journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      return await _persistenceLogic.updateDbEntity(
        journalEntity.copyWith(
          meta: await _persistenceLogic.updateMetadata(
            addTagsToMeta(journalEntity.meta, addedTagIds),
          ),
        ),
      );
    } catch (exception, stackTrace) {
      getIt<LottiLogger>().exception(
        exception,
        domain: 'persistence_logic',
        subDomain: 'addTags',
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  static Future<bool?> addTagsWithLinked({
    required String journalEntityId,
    required List<String> addedTagIds,
  }) async {
    try {
      await addTags(
        journalEntityId: journalEntityId,
        addedTagIds: addedTagIds,
      );

      final storyTags = _tagsService.getFilteredStoryTagIds(addedTagIds);

      final linkedEntities = await getIt<JournalDb>().getLinkedEntities(
        journalEntityId,
      );

      for (final linked in linkedEntities) {
        await addTags(
          journalEntityId: linked.meta.id,
          addedTagIds: storyTags,
        );
      }
    } catch (exception, stackTrace) {
      getIt<LottiLogger>().exception(
        exception,
        domain: 'persistence_logic',
        subDomain: 'addTagsWithLinked',
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  static Future<bool?> removeTag({
    required String journalEntityId,
    required String tagId,
  }) async {
    try {
      final journalEntity =
          await getIt<JournalDb>().journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      return await _persistenceLogic.updateDbEntity(
        journalEntity.copyWith(
          meta: await _persistenceLogic.updateMetadata(
            removeTagFromMeta(journalEntity.meta, tagId),
          ),
        ),
      );
    } catch (exception, stackTrace) {
      getIt<LottiLogger>().exception(
        exception,
        domain: 'persistence_logic',
        subDomain: 'removeTag',
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  static Future<String> addTagDefinition(String tagString) async {
    final now = DateTime.now();
    final id = uuid.v1();
    await upsertTagEntity(
      TagEntity.genericTag(
        id: id,
        tag: tagString.trim(),
        private: false,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ),
    );
    return id;
  }

  static Future<int> upsertTagEntity(TagEntity tagEntity) async {
    final linesAffected = await _journalDb.upsertTagEntity(tagEntity);
    await outboxService.enqueueMessage(
      SyncMessage.tagEntity(
        tagEntity: tagEntity,
        status: SyncEntryStatus.update,
      ),
    );
    return linesAffected;
  }
}

Metadata addTagsToMeta(Metadata meta, List<String> addedTagIds) {
  final existingTagIds = meta.tagIds ?? [];
  final tagIds = [...existingTagIds];

  for (final tagId in addedTagIds) {
    if (!tagIds.contains(tagId)) {
      tagIds.add(tagId);
    }
  }

  return meta.copyWith(
    tagIds: tagIds,
  );
}

Metadata removeTagFromMeta(Metadata meta, String tagId) {
  return meta.copyWith(
    tagIds: meta.tagIds?.where((String id) => id != tagId).toList(),
  );
}
