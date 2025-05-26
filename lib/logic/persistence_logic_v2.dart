import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/repository/journal_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/logic/entry_factory.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/entry_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/location.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:uuid/uuid.dart';

/// Result of a persistence operation
class PersistenceResult<T> {
  PersistenceResult.success(this.data) : error = null;
  PersistenceResult.failure(this.error) : data = null;

  final T? data;
  final Exception? error;

  bool get isSuccess => data != null;
  bool get isFailure => error != null;
}

/// Refactored persistence logic with better dependency injection
class PersistenceLogicV2 {
  PersistenceLogicV2({
    required this.journalDb,
    required this.journalRepository,
    required this.vectorClockService,
    required this.loggingService,
    required this.updateNotifications,
    required this.outboxService,
    required this.notificationService,
    required this.tagsService,
    required this.fts5Db,
  }) {
    _entryFactory = JournalEntryFactory(
      createMetadata: createMetadata,
      notificationService: notificationService,
    );
    _init();
  }

  final JournalDb journalDb;
  final IJournalRepository journalRepository;
  final VectorClockService vectorClockService;
  final LoggingService loggingService;
  final UpdateNotifications updateNotifications;
  final OutboxService outboxService;
  final NotificationService notificationService;
  final TagsService tagsService;
  final Fts5Db fts5Db;

  late final JournalEntryFactory _entryFactory;
  final uuid = const Uuid();
  DeviceLocation? location;

  Future<void> _init() async {
    if (!Platform.isWindows) {
      location = DeviceLocation();
    }
  }

  /// Creates metadata with improved error handling
  Future<Metadata> createMetadata({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? uuidV5Input,
    bool? private,
    List<String>? tagIds,
    String? categoryId,
    bool? starred,
    EntryFlag? flag,
  }) async {
    final now = DateTime.now();
    final vc = await vectorClockService.getNextVectorClock();

    // avoid inserting the same external entity multiple times
    final id = uuidV5Input != null
        ? uuid.v5(Namespace.nil.value, uuidV5Input)
        : uuid.v1();

    return Metadata(
      createdAt: now,
      updatedAt: now,
      dateFrom: dateFrom ?? now,
      dateTo: dateTo ?? now,
      id: id,
      vectorClock: vc,
      private: private,
      tagIds: tagIds,
      categoryId: categoryId,
      starred: starred,
      timezone: await getLocalTimezone(),
      utcOffset: now.timeZoneOffset.inMinutes,
      flag: flag,
    );
  }

  /// Updates metadata with improved error handling
  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? deletedAt,
  }) async =>
      metadata.copyWith(
        updatedAt: DateTime.now(),
        vectorClock: await vectorClockService.getNextVectorClock(
          previous: metadata.vectorClock,
        ),
        dateFrom: dateFrom ?? metadata.dateFrom,
        dateTo: dateTo ?? metadata.dateTo,
        categoryId: clearCategoryId ? null : categoryId ?? metadata.categoryId,
        deletedAt: deletedAt ?? metadata.deletedAt,
      );

  /// Generic method to handle entry creation with error handling
  Future<PersistenceResult<T>> _createEntry<T extends JournalEntity>({
    required Future<T> Function() entryCreator,
    required String domain,
    required String subDomain,
    EntryCreationConfig? config,
  }) async {
    try {
      final entry = await entryCreator();
      final cfg = config ?? EntryCreationConfig();

      await createDbEntity(
        entry,
        shouldAddGeolocation: cfg.shouldAddGeolocation,
        addTags: cfg.addTags,
        linkedId: cfg.linkedId,
      );

      return PersistenceResult.success(entry);
    } catch (exception, stackTrace) {
      loggingService.captureException(
        exception,
        domain: domain,
        subDomain: subDomain,
        stackTrace: stackTrace,
      );
      return PersistenceResult.failure(
        exception is Exception ? exception : Exception(exception.toString()),
      );
    }
  }

  /// Creates a quantitative entry
  Future<PersistenceResult<QuantitativeEntry>> createQuantitativeEntry(
    QuantitativeData data,
  ) async {
    return _createEntry(
      entryCreator: () => _entryFactory.createQuantitativeEntry(
        data,
        config: EntryCreationConfig(
          shouldAddGeolocation: false,
          addTags: false,
        ),
      ),
      domain: 'persistence_logic_v2',
      subDomain: 'createQuantitativeEntry',
    );
  }

  /// Creates a workout entry
  Future<PersistenceResult<WorkoutEntry>> createWorkoutEntry(
    WorkoutData data,
  ) async {
    return _createEntry(
      entryCreator: () => _entryFactory.createWorkoutEntry(
        data,
        config: EntryCreationConfig(
          shouldAddGeolocation: false,
          addTags: false,
        ),
      ),
      domain: 'persistence_logic_v2',
      subDomain: 'createWorkoutEntry',
    );
  }

  /// Creates a survey entry
  Future<PersistenceResult<bool>> createSurveyEntry({
    required SurveyData data,
    String? linkedId,
  }) async {
    final result = await _createEntry(
      entryCreator: () => _entryFactory.createSurveyEntry(data),
      domain: 'persistence_logic_v2',
      subDomain: 'createSurveyEntry',
      config: EntryCreationConfig(linkedId: linkedId),
    );
    return PersistenceResult.success(result.isSuccess);
  }

  /// Creates a measurement entry
  Future<PersistenceResult<MeasurementEntry>> createMeasurementEntry({
    required MeasurementData data,
    required bool private,
    String? linkedId,
    String? comment,
  }) async {
    final shouldAddGeolocation =
        data.dateFrom.difference(DateTime.now()).inMinutes.abs() < 1 &&
            data.dateTo.difference(DateTime.now()).inMinutes.abs() < 1;

    final result = await _createEntry(
      entryCreator: () => _entryFactory.createMeasurementEntry(
        data,
        private: private,
        config: EntryCreationConfig(
          linkedId: linkedId,
          comment: comment,
          shouldAddGeolocation: shouldAddGeolocation,
        ),
      ),
      domain: 'persistence_logic_v2',
      subDomain: 'createMeasurementEntry',
      config: EntryCreationConfig(
        linkedId: linkedId,
        shouldAddGeolocation: shouldAddGeolocation,
      ),
    );

    if (result.isSuccess) {
      updateNotifications.notify({data.dataTypeId});
    }

    return result;
  }

  /// Creates a link between two entries
  Future<bool> createLink({
    required String fromId,
    required String toId,
  }) async {
    final now = DateTime.now();

    final link = EntryLink.basic(
      id: uuid.v1(),
      fromId: fromId,
      toId: toId,
      createdAt: now,
      updatedAt: now,
      hidden: false,
      vectorClock: await vectorClockService.getNextVectorClock(),
    );

    final res = await journalDb.upsertEntryLink(link);
    updateNotifications.notify({link.fromId, link.toId});

    await outboxService.enqueueMessage(
      SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
      ),
    );
    return res != 0;
  }

  /// Creates or updates a database entity with improved error handling
  Future<bool?> createDbEntity(
    JournalEntity journalEntity, {
    bool shouldAddGeolocation = true,
    bool enqueueSync = true,
    bool addTags = true,
    String? linkedId,
  }) async {
    try {
      JournalEntity? linked;

      if (linkedId != null) {
        linked = await journalRepository.getById(linkedId);
      }

      final linkedTagIds = linked?.meta.tagIds;
      final storyTags = tagsService.getFilteredStoryTagIds(linkedTagIds);

      final withTags = journalEntity.copyWith(
        meta: journalEntity.meta.copyWith(
          private: linked?.meta.private,
          categoryId: journalEntity.categoryId ?? linked?.categoryId,
          tagIds: <String>{
            ...?journalEntity.meta.tagIds,
            ...storyTags,
          }.toList(),
        ),
      );

      final res = await journalRepository.upsert(withTags, overwrite: false);
      final saved = res != 0;

      if (addTags) {
        await journalDb.addTagged(withTags);
      }

      if (saved && enqueueSync) {
        await outboxService.enqueueMessage(
          SyncMessage.journalEntity(
            id: journalEntity.id,
            vectorClock: withTags.meta.vectorClock,
            jsonPath: relativeEntityPath(journalEntity),
            status: SyncEntryStatus.initial,
          ),
        );
      }

      if (linked != null) {
        await createLink(
          fromId: linked.meta.id,
          toId: withTags.meta.id,
        );
      }

      final affectedIds = withTags.affectedIds;
      if (linkedId != null) {
        affectedIds.add(linkedId);
      }

      updateNotifications.notify(affectedIds);
      await notificationService.updateBadge();

      if (shouldAddGeolocation) {
        addGeolocation(journalEntity.id);
      }

      return saved;
    } catch (exception, stackTrace) {
      loggingService.captureException(
        exception,
        domain: 'persistence_logic_v2',
        subDomain: 'createDbEntity',
        stackTrace: stackTrace,
      );
      debugPrint('Exception $exception');
    }
    return null;
  }

  /// Updates an existing database entity
  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    String? linkedId,
    bool enqueueSync = true,
  }) async {
    try {
      await journalRepository.updateWithConflictDetection(journalEntity);
      updateNotifications.notify({
        ...journalEntity.affectedIds,
        if (linkedId != null) linkedId,
      });

      await fts5Db.insertText(
        journalEntity,
        removePrevious: true,
      );

      if (enqueueSync) {
        await outboxService.enqueueMessage(
          SyncMessage.journalEntity(
            id: journalEntity.id,
            vectorClock: journalEntity.meta.vectorClock,
            jsonPath: relativeEntityPath(journalEntity),
            status: SyncEntryStatus.update,
          ),
        );
      }

      await notificationService.updateBadge();
      return true;
    } catch (exception, stackTrace) {
      loggingService.captureException(
        exception,
        domain: 'persistence_logic_v2',
        subDomain: 'updateDbEntity',
        stackTrace: stackTrace,
      );
      debugPrint('Exception $exception');
    }
    return null;
  }

  /// Adds geolocation to an entry asynchronously
  void addGeolocation(String journalEntityId) {
    // ignore: unawaited_futures
    _addGeolocationAsync(journalEntityId);
  }

  Future<void> _addGeolocationAsync(String journalEntityId) async {
    try {
      final geolocation = await location?.getCurrentGeoLocation();
      if (geolocation == null) return;

      final journalEntity = await journalRepository.getById(journalEntityId);
      if (journalEntity != null) {
        await updateDbEntity(
          journalEntity.copyWith(
            meta: await updateMetadata(journalEntity.meta),
            geolocation: geolocation,
          ),
        );
      }
    } catch (exception, stackTrace) {
      loggingService.captureException(
        exception,
        domain: 'persistence_logic_v2',
        subDomain: 'addGeolocation',
        stackTrace: stackTrace,
      );
    }
  }

  /// Generic update method for journal entity text
  Future<bool> updateJournalEntityText(
    String journalEntityId,
    EntryText entryText,
    DateTime dateTo,
  ) async {
    try {
      final journalEntity = await journalRepository.getById(journalEntityId);
      if (journalEntity == null) return false;

      final newMeta = await updateMetadata(journalEntity.meta, dateTo: dateTo);

      // Handle different entry types with a visitor pattern
      final updated = _updateEntryWithText(journalEntity, newMeta, entryText);
      if (updated != null) {
        await updateDbEntity(updated);
        return true;
      }
    } catch (exception, stackTrace) {
      loggingService.captureException(
        exception,
        domain: 'persistence_logic_v2',
        subDomain: 'updateJournalEntityText',
        stackTrace: stackTrace,
      );
    }
    return false;
  }

  /// Helper method to update different entry types with text
  JournalEntity? _updateEntryWithText(
    JournalEntity entity,
    Metadata newMeta,
    EntryText entryText,
  ) {
    return entity.maybeMap(
      journalEntry: (entry) => entry.copyWith(
        meta: newMeta,
        entryText: entryText,
      ),
      journalAudio: (audio) => audio.copyWith(
        meta: newMeta.copyWith(
          flag:
              newMeta.flag == EntryFlag.import ? EntryFlag.none : newMeta.flag,
        ),
        entryText: entryText,
      ),
      journalImage: (image) => image.copyWith(
        meta: newMeta.copyWith(
          flag:
              newMeta.flag == EntryFlag.import ? EntryFlag.none : newMeta.flag,
        ),
        entryText: entryText,
      ),
      measurement: (measurement) => measurement.copyWith(
        meta: newMeta,
        entryText: entryText,
      ),
      habitCompletion: (habit) => habit.copyWith(
        meta: newMeta,
        entryText: entryText,
      ),
      orElse: () => null,
    );
  }

  /// Upserts an entity definition
  Future<int> upsertEntityDefinition(EntityDefinition entityDefinition) async {
    final linesAffected =
        await journalDb.upsertEntityDefinition(entityDefinition);
    updateNotifications.notify({entityDefinition.id});
    await outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: entityDefinition,
        status: SyncEntryStatus.update,
      ),
    );
    return linesAffected;
  }
}
