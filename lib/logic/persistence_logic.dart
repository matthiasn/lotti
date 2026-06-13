import 'dart:async';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_create_ops.dart';
import 'package:lotti/logic/persistence_definition_ops.dart';
import 'package:lotti/logic/persistence_entries.dart';
import 'package:lotti/logic/persistence_logic_contract.dart';
import 'package:lotti/logic/persistence_update_ops.dart';
import 'package:lotti/logic/persistence_updates.dart';

export 'package:lotti/logic/persistence_logic_contract.dart'
    show PersistenceLogicContract;

/// Central persistence facade.
///
/// Behaviour lives in five collaborators wired together through this facade;
/// every public method is a thin delegator so mocktail mocks of
/// [PersistenceLogic] still intercept every call (the mixin layout this
/// replaced existed for the same reason). The facade implements
/// [PersistenceLogicContract] and injects itself into each collaborator, so
/// cross-collaborator calls dispatch back through it. That keeps the
/// virtual-override semantics test subclasses rely on: overriding
/// [updateDbEntity] or [updateMetadata] on a subclass still intercepts the
/// calls made from inside [updateJournalEntity], [createDbEntity], etc.
class PersistenceLogic implements PersistenceLogicContract {
  PersistenceLogic() {
    _create = PersistenceCreateOps(this);
    _definitions = PersistenceDefinitionOps(this);
    _updateOps = PersistenceUpdateOps(this);
    _entries = PersistenceEntries(this);
    _updates = PersistenceUpdates(this);
  }

  late final PersistenceCreateOps _create;
  late final PersistenceDefinitionOps _definitions;
  late final PersistenceUpdateOps _updateOps;
  late final PersistenceEntries _entries;
  late final PersistenceUpdates _updates;

  // --- Metadata (PersistenceEntries) ---------------------------------------

  @override
  Future<Metadata> createMetadata({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? uuidV5Input,
    bool? private,
    List<String>? labelIds,
    String? categoryId,
    bool? starred,
    EntryFlag? flag,
  }) => _entries.createMetadata(
    dateFrom: dateFrom,
    dateTo: dateTo,
    uuidV5Input: uuidV5Input,
    private: private,
    labelIds: labelIds,
    categoryId: categoryId,
    starred: starred,
    flag: flag,
  );

  @override
  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? deletedAt,
    List<String>? labelIds,
    bool clearLabelIds = false,
  }) => _entries.updateMetadata(
    metadata,
    dateFrom: dateFrom,
    dateTo: dateTo,
    categoryId: categoryId,
    clearCategoryId: clearCategoryId,
    deletedAt: deletedAt,
    labelIds: labelIds,
    clearLabelIds: clearLabelIds,
  );

  // --- Entry creation (public wrappers, PersistenceEntries) ----------------

  Future<QuantitativeEntry?> createQuantitativeEntry(QuantitativeData data) =>
      _entries.createQuantitativeEntry(data);

  Future<WorkoutEntry?> createWorkoutEntry(WorkoutData data) =>
      _entries.createWorkoutEntry(data);

  Future<bool> createSurveyEntry({
    required SurveyData data,
    String? linkedId,
  }) => _entries.createSurveyEntry(data: data, linkedId: linkedId);

  Future<MeasurementEntry?> createMeasurementEntry({
    required MeasurementData data,
    required bool private,
    String? linkedId,
    String? comment,
  }) => _entries.createMeasurementEntry(
    data: data,
    private: private,
    linkedId: linkedId,
    comment: comment,
  );

  Future<HabitCompletionEntry?> createHabitCompletionEntry({
    required HabitCompletionData data,
    required HabitDefinition? habitDefinition,
    String? linkedId,
    String? comment,
  }) => _entries.createHabitCompletionEntry(
    data: data,
    habitDefinition: habitDefinition,
    linkedId: linkedId,
    comment: comment,
  );

  Future<Task?> createTaskEntry({
    required TaskData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  }) => _entries.createTaskEntry(
    data: data,
    entryText: entryText,
    linkedId: linkedId,
    categoryId: categoryId,
  );

  Future<AiResponseEntry?> createAiResponseEntry({
    required AiResponseData data,
    DateTime? dateFrom,
    String? linkedId,
    String? categoryId,
  }) => _entries.createAiResponseEntry(
    data: data,
    dateFrom: dateFrom,
    linkedId: linkedId,
    categoryId: categoryId,
  );

  Future<JournalEvent?> createEventEntry({
    required EventData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  }) => _entries.createEventEntry(
    data: data,
    entryText: entryText,
    linkedId: linkedId,
    categoryId: categoryId,
  );

  Future<bool> createLink({
    required String fromId,
    required String toId,
  }) => _entries.createLink(fromId: fromId, toId: toId);

  @override
  Future<bool?> createDbEntity(
    JournalEntity journalEntity, {
    bool shouldAddGeolocation = true,
    bool enqueueSync = true,
    String? linkedId,
  }) => _entries.createDbEntity(
    journalEntity,
    shouldAddGeolocation: shouldAddGeolocation,
    enqueueSync: enqueueSync,
    linkedId: linkedId,
  );

  // --- Entry-creation builders (PersistenceCreateOps) ----------------------

  @override
  Future<QuantitativeEntry?> createQuantitativeEntryImpl(
    QuantitativeData data,
  ) => _create.createQuantitativeEntryImpl(data);

  @override
  Future<WorkoutEntry?> createWorkoutEntryImpl(WorkoutData data) =>
      _create.createWorkoutEntryImpl(data);

  @override
  Future<bool> createSurveyEntryImpl({
    required SurveyData data,
    String? linkedId,
  }) => _create.createSurveyEntryImpl(data: data, linkedId: linkedId);

  @override
  Future<MeasurementEntry?> createMeasurementEntryImpl({
    required MeasurementData data,
    required bool private,
    String? linkedId,
    String? comment,
  }) => _create.createMeasurementEntryImpl(
    data: data,
    private: private,
    linkedId: linkedId,
    comment: comment,
  );

  @override
  Future<HabitCompletionEntry?> createHabitCompletionEntryImpl({
    required HabitCompletionData data,
    required HabitDefinition? habitDefinition,
    String? linkedId,
    String? comment,
  }) => _create.createHabitCompletionEntryImpl(
    data: data,
    habitDefinition: habitDefinition,
    linkedId: linkedId,
    comment: comment,
  );

  @override
  Future<Task?> createTaskEntryImpl({
    required TaskData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  }) => _create.createTaskEntryImpl(
    data: data,
    entryText: entryText,
    linkedId: linkedId,
    categoryId: categoryId,
  );

  @override
  Future<AiResponseEntry?> createAiResponseEntryImpl({
    required AiResponseData data,
    DateTime? dateFrom,
    String? linkedId,
    String? categoryId,
  }) => _create.createAiResponseEntryImpl(
    data: data,
    dateFrom: dateFrom,
    linkedId: linkedId,
    categoryId: categoryId,
  );

  @override
  Future<JournalEvent?> createEventEntryImpl({
    required EventData data,
    required EntryText entryText,
    String? linkedId,
    String? categoryId,
  }) => _create.createEventEntryImpl(
    data: data,
    entryText: entryText,
    linkedId: linkedId,
    categoryId: categoryId,
  );

  // --- Entry updates (public wrappers, PersistenceUpdates) -----------------

  Future<bool> updateJournalEntityText(
    String journalEntityId,
    EntryText entryText,
    DateTime dateTo,
  ) => _updates.updateJournalEntityText(journalEntityId, entryText, dateTo);

  Future<bool> updateJournalEntry({
    required String journalEntityId,
    EntryText? entryText,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) => _updates.updateJournalEntry(
    journalEntityId: journalEntityId,
    entryText: entryText,
    dateFrom: dateFrom,
    dateTo: dateTo,
  );

  Future<bool> updateTask({
    required String journalEntityId,
    required TaskData taskData,
    String? categoryId,
    EntryText? entryText,
  }) => _updates.updateTask(
    journalEntityId: journalEntityId,
    taskData: taskData,
    categoryId: categoryId,
    entryText: entryText,
  );

  Future<bool> updateEvent({
    required String journalEntityId,
    required EventData data,
    EntryText? entryText,
  }) => _updates.updateEvent(
    journalEntityId: journalEntityId,
    data: data,
    entryText: entryText,
  );

  FutureOr<Geolocation?> addGeolocationAsync(String journalEntityId) =>
      _updates.addGeolocationAsync(journalEntityId);

  @override
  void addGeolocation(String journalEntityId) =>
      _updates.addGeolocation(journalEntityId);

  Future<bool> updateJournalEntity(
    JournalEntity journalEntity,
    Metadata metadata,
  ) => _updates.updateJournalEntity(journalEntity, metadata);

  @override
  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    String? linkedId,
    bool enqueueSync = true,
    bool overrideComparison = false,
    Future<void> Function()? beforeNotify,
  }) => _updates.updateDbEntity(
    journalEntity,
    linkedId: linkedId,
    enqueueSync: enqueueSync,
    overrideComparison: overrideComparison,
    beforeNotify: beforeNotify,
  );

  // --- Entry-update builders (PersistenceUpdateOps) ------------------------

  @override
  Future<bool> updateJournalEntityTextImpl(
    String journalEntityId,
    EntryText entryText,
    DateTime dateTo,
  ) => _updateOps.updateJournalEntityTextImpl(
    journalEntityId,
    entryText,
    dateTo,
  );

  @override
  Future<bool> updateJournalEntryImpl({
    required String journalEntityId,
    EntryText? entryText,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) => _updateOps.updateJournalEntryImpl(
    journalEntityId: journalEntityId,
    entryText: entryText,
    dateFrom: dateFrom,
    dateTo: dateTo,
  );

  @override
  Future<bool> updateTaskImpl({
    required String journalEntityId,
    required TaskData taskData,
    String? categoryId,
    EntryText? entryText,
  }) => _updateOps.updateTaskImpl(
    journalEntityId: journalEntityId,
    taskData: taskData,
    categoryId: categoryId,
    entryText: entryText,
  );

  @override
  Future<bool> updateEventImpl({
    required String journalEntityId,
    required EventData data,
    EntryText? entryText,
  }) => _updateOps.updateEventImpl(
    journalEntityId: journalEntityId,
    data: data,
    entryText: entryText,
  );

  // --- Definitions / config flags ------------------------------------------

  Future<int> upsertEntityDefinition(EntityDefinition entityDefinition) =>
      _updates.upsertEntityDefinition(entityDefinition);

  @override
  Future<int> upsertDashboardDefinition(DashboardDefinition dashboard) =>
      _updates.upsertDashboardDefinition(dashboard);

  Future<void> setConfigFlag(ConfigFlag configFlag) =>
      _updates.setConfigFlag(configFlag);

  Future<int> deleteDashboardDefinition(DashboardDefinition dashboard) =>
      _updates.deleteDashboardDefinition(dashboard);

  @override
  Future<int> upsertEntityDefinitionImpl(EntityDefinition entityDefinition) =>
      _definitions.upsertEntityDefinitionImpl(entityDefinition);

  @override
  Future<int> upsertDashboardDefinitionImpl(DashboardDefinition dashboard) =>
      _definitions.upsertDashboardDefinitionImpl(dashboard);

  @override
  Future<void> setConfigFlagImpl(ConfigFlag configFlag) =>
      _definitions.setConfigFlagImpl(configFlag);

  @override
  Future<int> deleteDashboardDefinitionImpl(DashboardDefinition dashboard) =>
      _definitions.deleteDashboardDefinitionImpl(dashboard);
}
