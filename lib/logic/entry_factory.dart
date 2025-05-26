import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/utils/entry_utils.dart';
import 'package:uuid/uuid.dart';

/// Configuration for creating a journal entry
class EntryCreationConfig {
  EntryCreationConfig({
    this.dateFrom,
    this.dateTo,
    this.uuidV5Input,
    this.private,
    this.tagIds,
    this.categoryId,
    this.starred,
    this.flag,
    this.shouldAddGeolocation = true,
    this.addTags = true,
    this.linkedId,
    this.comment,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? uuidV5Input;
  final bool? private;
  final List<String>? tagIds;
  final String? categoryId;
  final bool? starred;
  final EntryFlag? flag;
  final bool shouldAddGeolocation;
  final bool addTags;
  final String? linkedId;
  final String? comment;
}

/// Factory for creating different types of journal entries
class JournalEntryFactory {
  JournalEntryFactory({
    required this.createMetadata,
    this.notificationService,
  });

  final Future<Metadata> Function({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? uuidV5Input,
    bool? private,
    List<String>? tagIds,
    String? categoryId,
    bool? starred,
    EntryFlag? flag,
  }) createMetadata;

  final NotificationService? notificationService;

  /// Creates a quantitative entry
  Future<QuantitativeEntry> createQuantitativeEntry(
    QuantitativeData data, {
    EntryCreationConfig? config,
  }) async {
    final cfg = config ?? EntryCreationConfig();
    return QuantitativeEntry(
      data: data,
      meta: await createMetadata(
        dateFrom: cfg.dateFrom ?? data.dateFrom,
        dateTo: cfg.dateTo ?? data.dateTo,
        uuidV5Input: cfg.uuidV5Input ?? json.encode(data),
        private: cfg.private,
        tagIds: cfg.tagIds,
        categoryId: cfg.categoryId,
        starred: cfg.starred,
        flag: cfg.flag,
      ),
    );
  }

  /// Creates a workout entry
  Future<WorkoutEntry> createWorkoutEntry(
    WorkoutData data, {
    EntryCreationConfig? config,
  }) async {
    final cfg = config ?? EntryCreationConfig();
    return WorkoutEntry(
      data: data,
      meta: await createMetadata(
        dateFrom: cfg.dateFrom ?? data.dateFrom,
        dateTo: cfg.dateTo ?? data.dateTo,
        uuidV5Input: cfg.uuidV5Input ?? data.id,
        private: cfg.private,
        tagIds: cfg.tagIds,
        categoryId: cfg.categoryId,
        starred: cfg.starred,
        flag: cfg.flag,
      ),
    );
  }

  /// Creates a survey entry
  Future<SurveyEntry> createSurveyEntry(
    SurveyData data, {
    EntryCreationConfig? config,
  }) async {
    final cfg = config ?? EntryCreationConfig();
    return JournalEntity.survey(
      data: data,
      meta: await createMetadata(
        dateFrom: cfg.dateFrom ?? data.taskResult.startDate,
        dateTo: cfg.dateTo ?? data.taskResult.endDate,
        uuidV5Input: cfg.uuidV5Input ?? json.encode(data),
        private: cfg.private,
        tagIds: cfg.tagIds,
        categoryId: cfg.categoryId,
        starred: cfg.starred,
        flag: cfg.flag,
      ),
    ) as SurveyEntry;
  }

  /// Creates a measurement entry
  Future<MeasurementEntry> createMeasurementEntry(
    MeasurementData data, {
    required bool private,
    EntryCreationConfig? config,
  }) async {
    final cfg = config ?? EntryCreationConfig();
    final shouldAddGeolocation =
        data.dateFrom.difference(DateTime.now()).inMinutes.abs() < 1 &&
            data.dateTo.difference(DateTime.now()).inMinutes.abs() < 1;

    return MeasurementEntry(
      data: data,
      meta: await createMetadata(
        dateFrom: cfg.dateFrom ?? data.dateFrom,
        dateTo: cfg.dateTo ?? data.dateTo,
        uuidV5Input: cfg.uuidV5Input ?? json.encode(data),
        private: cfg.private ?? private,
        tagIds: cfg.tagIds,
        categoryId: cfg.categoryId,
        starred: cfg.starred,
        flag: cfg.flag,
      ),
      entryText: entryTextFromPlain(cfg.comment),
    );
  }

  /// Creates a habit completion entry
  Future<HabitCompletionEntry> createHabitCompletionEntry(
    HabitCompletionData data, {
    HabitDefinition? habitDefinition,
    EntryCreationConfig? config,
  }) async {
    final cfg = config ?? EntryCreationConfig();
    final defaultStoryId = habitDefinition?.defaultStoryId;
    final tagIds = defaultStoryId != null ? [defaultStoryId] : <String>[];

    final shouldAddGeolocation =
        data.dateFrom.difference(DateTime.now()).inMinutes.abs() < 1 &&
            data.dateTo.difference(DateTime.now()).inMinutes.abs() < 1;

    final entry = HabitCompletionEntry(
      data: data,
      meta: await createMetadata(
        dateFrom: cfg.dateFrom ?? data.dateFrom,
        dateTo: cfg.dateTo ?? data.dateTo,
        uuidV5Input: cfg.uuidV5Input ?? json.encode(data),
        private: cfg.private ?? habitDefinition?.private,
        tagIds: cfg.tagIds ?? tagIds,
        categoryId: cfg.categoryId,
        starred: cfg.starred,
        flag: cfg.flag,
      ),
      entryText: entryTextFromPlain(cfg.comment),
    );

    // Schedule habit notification if needed
    if (habitDefinition != null && notificationService != null) {
      await notificationService!.scheduleHabitNotification(
        habitDefinition,
        daysToAdd: 1,
      );
    }

    return entry;
  }

  /// Creates a task entry
  Future<Task> createTaskEntry(
    TaskData data, {
    required EntryText entryText,
    EntryCreationConfig? config,
  }) async {
    final cfg = config ?? EntryCreationConfig();
    return Task(
      data: data,
      entryText: entryText,
      meta: await createMetadata(
        dateFrom: cfg.dateFrom ?? data.dateFrom,
        dateTo: cfg.dateTo ?? data.dateTo,
        uuidV5Input: cfg.uuidV5Input ?? json.encode(data),
        categoryId: cfg.categoryId,
        starred: cfg.starred ?? false,
        private: cfg.private,
        tagIds: cfg.tagIds,
        flag: cfg.flag,
      ),
    );
  }

  /// Creates an AI response entry
  Future<AiResponseEntry> createAiResponseEntry(
    AiResponseData data, {
    DateTime? dateFrom,
    EntryCreationConfig? config,
  }) async {
    final cfg = config ?? EntryCreationConfig();
    return AiResponseEntry(
      data: data,
      meta: await createMetadata(
        dateFrom: cfg.dateFrom ?? dateFrom ?? DateTime.now(),
        dateTo: cfg.dateTo ?? DateTime.now(),
        uuidV5Input: cfg.uuidV5Input ?? json.encode(data),
        categoryId: cfg.categoryId,
        starred: cfg.starred ?? false,
        private: cfg.private,
        tagIds: cfg.tagIds,
        flag: cfg.flag,
      ),
    );
  }

  /// Creates an event entry
  Future<JournalEvent> createEventEntry(
    EventData data, {
    required EntryText entryText,
    EntryCreationConfig? config,
  }) async {
    final cfg = config ?? EntryCreationConfig();
    return JournalEvent(
      data: data,
      entryText: entryText,
      meta: await createMetadata(
        dateFrom: cfg.dateFrom,
        dateTo: cfg.dateTo,
        starred: cfg.starred ?? true,
        categoryId: cfg.categoryId,
        private: cfg.private,
        tagIds: cfg.tagIds,
        flag: cfg.flag,
        uuidV5Input: cfg.uuidV5Input,
      ),
    );
  }
}
