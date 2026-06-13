import 'dart:async';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_logic.dart' show PersistenceLogic;

/// Cross-collaborator contract used by the [PersistenceLogic] facade.
///
/// The facade implements this and is injected into each collaborator so
/// cross-group calls dispatch back through the facade. This preserves the
/// virtual-override behaviour the old mixin layout relied on: test
/// subclasses (`extends PersistenceLogic`) that override [updateDbEntity] or
/// [updateMetadata] must see their overrides invoked from inside the other
/// collaborators (e.g. the label-preserving update path or [createDbEntity]).
abstract class PersistenceLogicContract {
  Future<Metadata> createMetadata({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? uuidV5Input,
    bool? private,
    List<String>? labelIds,
    String? categoryId,
    bool? starred,
    EntryFlag? flag,
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
  });

  Future<bool?> createDbEntity(
    JournalEntity journalEntity, {
    bool shouldAddGeolocation = true,
    bool enqueueSync = true,
    String? linkedId,
  });

  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    String? linkedId,
    bool enqueueSync = true,
    bool overrideComparison = false,
    Future<void> Function()? beforeNotify,
  });

  void addGeolocation(String journalEntityId);

  Future<int> upsertDashboardDefinition(DashboardDefinition dashboard);

  Future<QuantitativeEntry?> createQuantitativeEntryImpl(
    QuantitativeData data,
  );

  Future<WorkoutEntry?> createWorkoutEntryImpl(WorkoutData data);

  Future<bool> createSurveyEntryImpl({
    required SurveyData data,
    String? linkedId,
  });

  Future<MeasurementEntry?> createMeasurementEntryImpl({
    required MeasurementData data,
    required bool private,
    String? linkedId,
    String? comment,
  });

  Future<HabitCompletionEntry?> createHabitCompletionEntryImpl({
    required HabitCompletionData data,
    required HabitDefinition? habitDefinition,
    String? linkedId,
    String? comment,
  });

  Future<Task?> createTaskEntryImpl({
    required TaskData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  });

  Future<AiResponseEntry?> createAiResponseEntryImpl({
    required AiResponseData data,
    DateTime? dateFrom,
    String? linkedId,
    String? categoryId,
  });

  Future<JournalEvent?> createEventEntryImpl({
    required EventData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
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

  Future<bool> updateTaskImpl({
    required String journalEntityId,
    required TaskData taskData,
    String? categoryId,
    EntryText? entryText,
  });

  Future<bool> updateEventImpl({
    required String journalEntityId,
    required EventData data,
    EntryText? entryText,
  });

  Future<int> upsertEntityDefinitionImpl(EntityDefinition entityDefinition);

  Future<int> upsertDashboardDefinitionImpl(DashboardDefinition dashboard);

  Future<void> setConfigFlagImpl(ConfigFlag configFlag);

  Future<int> deleteDashboardDefinitionImpl(DashboardDefinition dashboard);
}
