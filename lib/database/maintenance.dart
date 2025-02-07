import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/tags/repository/tags_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart';

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

  Future<void> reSyncInterval({
    required DateTime start,
    required DateTime end,
  }) async {
    final outboxService = getIt<OutboxService>();
    final count = await _db.countJournalEntries().getSingle();
    const pageSize = 100;
    final pages = (count / pageSize).ceil();

    for (var page = 0; page <= pages; page++) {
      final dbEntities = await _db
          .orderedJournalInterval(start, end, pageSize, page * pageSize)
          .get();
      if (dbEntities.isEmpty) {
        return;
      }

      final entries = entityStreamMapper(dbEntities);
      for (final entry in entries) {
        await outboxService.enqueueMessage(
          SyncMessage.journalEntity(
            journalEntity: entry,
            status: SyncEntryStatus.update,
          ),
        );

        final entryLinks = await _db.linksForEntryIds({entry.meta.id});
        for (final entryLink in entryLinks) {
          await outboxService.enqueueMessage(
            SyncMessage.entryLink(
              status: SyncEntryStatus.update,
              entryLink: entryLink,
            ),
          );
        }
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
          await TagsRepository.addTags(
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
    final habits = await _db.watchHabitDefinitions().first;

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
    for (final habit in habits) {
      await outboxService.enqueueMessage(
        SyncMessage.entityDefinition(
          entityDefinition: habit,
          status: SyncEntryStatus.update,
        ),
      );
    }
  }

  Future<void> syncCategories() async {
    final outboxService = getIt<OutboxService>();
    final categories = await _db.watchCategories().first;

    for (final category in categories) {
      await outboxService.enqueueMessage(
        SyncMessage.entityDefinition(
          entityDefinition: category,
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

  Future<void> purgeAudioModels() async {
    File(join(getDocumentsDirectory().path, 'huggingface'))
        .deleteSync(recursive: true);
  }

  Future<void> deleteLoggingDb() async {
    final file = await getDatabaseFile(loggingDbFileName);
    file.deleteSync();
  }

  Future<void> deleteSyncDb() async {
    final file = await getDatabaseFile(syncDbFileName);
    file.deleteSync();
  }

  Future<void> deleteFts5Db() async {
    final file = await getDatabaseFile(fts5DbFileName);
    file.deleteSync();

    getIt<LoggingService>().captureEvent(
      'FTS5 database DELETED',
      domain: 'MAINTENANCE',
      subDomain: 'recreateFts5',
    );
  }

  Future<void> recreateFts5() async {
    try {
      await deleteFts5Db();
    } catch (e, stackTrace) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'MAINTENANCE',
        subDomain: 'deleteFts5Db',
        stackTrace: stackTrace,
      );
    }

    await getIt<Fts5Db>().close();

    getIt
      ..unregister<Fts5Db>()
      ..registerSingleton<Fts5Db>(Fts5Db());

    final fts5Db = getIt<Fts5Db>();

    final entryCount = await _db.getJournalCount();
    const pageSize = 500;
    final pages = (entryCount / pageSize).ceil();
    var completed = 0;

    for (var page = 0; page <= pages; page++) {
      final dbEntities =
          await _db.orderedJournal(pageSize, page * pageSize).get();

      final entries = entityStreamMapper(dbEntities);
      completed = completed + entries.length;

      for (final entry in entries) {
        await fts5Db.insertText(entry);
      }

      final progress = entryCount > 0 ? completed / entryCount : 0;

      getIt<LoggingService>().captureEvent(
        'Progress: ${(progress * 100).floor()}%, $completed/$entryCount',
        domain: 'MAINTENANCE',
        subDomain: 'recreateFts5',
      );
    }
  }

  Future<void> transcribeAudioWithoutTranscript() async {
    await createDbBackup(journalDbFileName);

    final count = await _db.getJournalCount();
    const pageSize = 100;
    final pages = (count / pageSize).ceil();

    for (var page = 0; page <= pages; page++) {
      final dbEntities =
          await _db.orderedAudioEntries(pageSize, page * pageSize).get();
      final entries = entityStreamMapper(dbEntities);
      for (final entry in entries) {
        if (entry is JournalAudio) {
          if (entry.data.transcripts?.isEmpty ?? true) {
            await getIt<AsrService>().enqueue(entry: entry);
          }
        }
      }
    }
  }

  Future<void> persistTaskCategories() async {
    await createDbBackup(journalDbFileName);

    final count = await _db.getJournalCount();
    const pageSize = 100;
    final pages = (count / pageSize).ceil();

    for (var page = 0; page <= pages; page++) {
      final entries = await _db.getTasks(
        taskStatuses: [
          'OPEN',
          'GROOMED',
          'IN PROGRESS',
          'BLOCKED',
          'ON HOLD',
          'DONE',
          'REJECTED',
        ],
        starredStatuses: [true, false],
        categoryIds: [''],
        limit: 100000,
      );

      for (final entry in entries) {
        if (entry is Task) {
          if (entry.meta.categoryId != null) {
            await _db.updateJournalEntity(
              entry,
              overrideComparison: true,
            );
          }
        }
      }
    }
  }

  Future<void> addCategoriesToChecklists() async {
    await createDbBackup(journalDbFileName);

    var taskCount = 0;
    var tasksWithCategoriesCount = 0;
    var updatedChecklistsCount = 0;
    var updatedChecklistItemsCount = 0;

    final allCategoryIds = getIt<EntitiesCacheService>()
        .sortedCategories
        .map((e) => e.id)
        .toList();

    final tasks = await _db.getTasks(
      taskStatuses: [
        'OPEN',
        'GROOMED',
        'IN PROGRESS',
        'BLOCKED',
        'ON HOLD',
        'DONE',
        'REJECTED',
      ],
      starredStatuses: [true, false],
      categoryIds: allCategoryIds,
      limit: 100000,
    );

    for (final task in tasks) {
      taskCount++;
      if (task is Task) {
        final categoryId = task.categoryId;

        if (categoryId != null) {
          tasksWithCategoriesCount++;

          final checklistIds = task.data.checklistIds ?? [];

          for (final checklistId in checklistIds) {
            final checklist = await _db.journalEntityById(checklistId);
            if (checklist != null && checklist is Checklist) {
              if (checklist.categoryId == null) {
                await persistenceLogic.updateJournalEntity(
                  checklist,
                  checklist.meta.copyWith(categoryId: categoryId),
                );
                updatedChecklistsCount++;
              }

              final checklistItemIds = checklist.data.linkedChecklistItems;

              for (final checklistItemId in checklistItemIds) {
                final checklistItem =
                    await _db.journalEntityById(checklistItemId);
                if (checklistItem != null &&
                    checklistItem is ChecklistItem &&
                    checklistItem.categoryId == null) {
                  await persistenceLogic.updateJournalEntity(
                    checklistItem,
                    checklistItem.meta.copyWith(categoryId: categoryId),
                  );
                  updatedChecklistItemsCount++;
                }
              }
            }
          }
        }
      }
    }

    getIt<LoggingService>().captureEvent(
      'Tasks: $taskCount, tasks with categories: $tasksWithCategoriesCount, \n'
      'Updated checklists: $updatedChecklistsCount, \n'
      'Updated checklist items: $updatedChecklistItemsCount.',
      domain: 'MAINTENANCE',
      subDomain: 'addCategoriesToChecklists',
    );
  }

  Future<void> addCategoriesToLinkedFromTasks() async {
    await createDbBackup(journalDbFileName);

    var taskCount = 0;
    var tasksWithCategoriesCount = 0;
    var updatedEntriesCount = 0;

    final allCategoryIds = getIt<EntitiesCacheService>()
        .sortedCategories
        .map((e) => e.id)
        .toList();

    final tasks = await _db.getTasks(
      taskStatuses: [
        'OPEN',
        'GROOMED',
        'IN PROGRESS',
        'BLOCKED',
        'ON HOLD',
        'DONE',
        'REJECTED',
      ],
      starredStatuses: [true, false],
      categoryIds: allCategoryIds,
      limit: 100000,
    );

    for (final task in tasks) {
      taskCount++;
      if (task is Task) {
        final categoryId = task.categoryId;
        if (categoryId != null) {
          tasksWithCategoriesCount++;

          for (final linked in await _db.getLinkedEntities(task.id)) {
            if (linked.meta.categoryId == null) {
              await persistenceLogic.updateJournalEntity(
                linked,
                linked.meta.copyWith(categoryId: categoryId),
              );
              updatedEntriesCount++;
            }
          }
        }
      }
    }

    getIt<LoggingService>().captureEvent(
      'Tasks: $taskCount, tasks with categories: $tasksWithCategoriesCount, \n'
      'Updated entries: $updatedEntriesCount, \n',
      domain: 'MAINTENANCE',
      subDomain: 'addCategoriesToLinkedFromTasks',
    );
  }

  Future<void> addCategoriesToLinked() async {
    await createDbBackup(journalDbFileName);

    final count = await _db.getJournalCount();
    const pageSize = 100;
    final pages = (count / pageSize).ceil();

    for (var page = 0; page <= pages; page++) {
      final dbEntities =
          await _db.orderedJournal(pageSize, page * pageSize).get();

      final entries = entityStreamMapper(dbEntities);
      for (final entry in entries) {
        final categoryId = entry.categoryId;

        if (categoryId != null) {
          final linkedEntities = await _db.getLinkedEntities(entry.meta.id);

          for (final linked in linkedEntities) {
            if (linked.categoryId == null) {
              await persistenceLogic.updateJournalEntity(
                linked,
                linked.meta.copyWith(categoryId: categoryId),
              );
            }
          }
        }
      }
    }
  }
}
