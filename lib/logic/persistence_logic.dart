import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/entry_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:uuid/uuid.dart';

part 'persistence_create.dart';
part 'persistence_definitions.dart';
part 'persistence_update.dart';
part 'persistence_logic_entries.dart';
part 'persistence_logic_updates.dart';

abstract class _PersistenceLogicBase {
  JournalDb get _journalDb => getIt<JournalDb>();
  MetadataService get _metadataService => getIt<MetadataService>();
  VectorClockService get _vectorClockService => getIt<VectorClockService>();
  GeolocationService get _geolocationService => getIt<GeolocationService>();
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  DomainLogger get _loggingService => getIt<DomainLogger>();
  SyncSequenceLogService? get _sequenceLogService =>
      getIt.isRegistered<SyncSequenceLogService>()
      ? getIt<SyncSequenceLogService>()
      : null;
  final OutboxService outboxService = getIt<OutboxService>();
  final uuid = const Uuid();

  // Cross-mixin contracts.
  void addGeolocation(String journalEntityId);

  Future<AiResponseEntry?> createAiResponseEntryImpl({
    required AiResponseData data,
    DateTime? dateFrom,
    String? linkedId,
    String? categoryId,
  });

  Future<bool?> createDbEntity(
    JournalEntity journalEntity, {
    bool shouldAddGeolocation = true,
    bool enqueueSync = true,
    String? linkedId,
  });

  Future<JournalEvent?> createEventEntryImpl({
    required EventData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  });

  Future<HabitCompletionEntry?> createHabitCompletionEntryImpl({
    required HabitCompletionData data,
    required HabitDefinition? habitDefinition,
    String? linkedId,
    String? comment,
  });

  Future<MeasurementEntry?> createMeasurementEntryImpl({
    required MeasurementData data,
    required bool private,
    String? linkedId,
    String? comment,
  });

  Future<Metadata> createMetadata({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? uuidV5Input,
    bool? private,
    List<String>? labelIds,
    String? categoryId,
    bool? starred,
    EntryFlag? flag,
  }) => _metadataService.createMetadata(
    dateFrom: dateFrom,
    dateTo: dateTo,
    uuidV5Input: uuidV5Input,
    private: private,
    labelIds: labelIds,
    categoryId: categoryId,
    starred: starred,
    flag: flag,
  );

  Future<QuantitativeEntry?> createQuantitativeEntryImpl(
    QuantitativeData data,
  );

  Future<bool> createSurveyEntryImpl({
    required SurveyData data,
    String? linkedId,
  });

  Future<Task?> createTaskEntryImpl({
    required TaskData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  });

  Future<WorkoutEntry?> createWorkoutEntryImpl(WorkoutData data);

  Future<int> deleteDashboardDefinitionImpl(
    DashboardDefinition dashboard,
  );

  Future<void> _recordJournalSequence(
    JournalEntity entity, {
    required String subDomain,
  });

  Future<void> setConfigFlagImpl(ConfigFlag configFlag);

  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    String? linkedId,
    bool enqueueSync = true,
    bool overrideComparison = false,
    Future<void> Function()? beforeNotify,
  });

  Future<bool> updateEventImpl({
    required String journalEntityId,
    required EventData data,
    EntryText? entryText,
  });

  Future<bool> updateJournalEntityTextImpl(
    String journalEntityId,
    EntryText entryText,
    DateTime dateTo,
  );

  Future<bool> updateJournalEntryImpl({
    required String journalEntityId,
    EntryText? entryText,
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? deletedAt,
    List<String>? labelIds,
    bool clearLabelIds = false,
  }) => _metadataService.updateMetadata(
    metadata,
    dateFrom: dateFrom,
    dateTo: dateTo,
    categoryId: categoryId,
    clearCategoryId: clearCategoryId,
    deletedAt: deletedAt,
    labelIds: labelIds,
    clearLabelIds: clearLabelIds,
  );

  Future<bool> updateTaskImpl({
    required String journalEntityId,
    required TaskData taskData,
    String? categoryId,
    EntryText? entryText,
  });

  Future<int> upsertDashboardDefinition(DashboardDefinition dashboard);

  Future<int> upsertDashboardDefinitionImpl(
    DashboardDefinition dashboard,
  );

  Future<int> upsertEntityDefinitionImpl(
    EntityDefinition entityDefinition,
  );
}

class PersistenceLogic extends _PersistenceLogicBase
    with
        _PersistenceCreateOps,
        _PersistenceDefinitionOps,
        _PersistenceUpdateOps,
        _PersistenceEntries,
        _PersistenceUpdates {}
