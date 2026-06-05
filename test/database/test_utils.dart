/// Shared test infrastructure for the `JournalDb` test files in this
/// directory.
///
/// The original monolithic `database_test.dart` was mirror-split along the
/// `lib/database/database_*.dart` part-file seams; every split file uses the
/// same environment: a temp documents directory, GetIt registrations for
/// [UpdateNotifications], [DomainLogger], and [Directory], an in-memory
/// [JournalDb], and the entity builders below.
library;

import 'dart:io';

import 'package:flutter/widgets.dart' show UniqueKey;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

/// Creates a temp directory used as the documents directory for a test.
Directory setupTestDirectory() {
  final directory = Directory.systemTemp.createTempSync('lotti_test_');
  return directory;
}

/// Fallback values shared by every `JournalDb` test file; pass to
/// `setUpAll`.
void registerJournalDbTestFallbacks() {
  registerFallbackValue(StackTrace.empty);
  registerFallbackValue(InsightLevel.info);
  registerFallbackValue(const Stream<Set<String>>.empty());
  registerFallbackValue(fallbackJournalEntity);
  registerFallbackValue(
    EntryLink.basic(
      id: 'link-id',
      fromId: 'from',
      toId: 'to',
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      vectorClock: null,
    ),
  );
  registerFallbackValue(measurableWater);
  registerFallbackValue(fallbackAiConfig);
  registerFallbackValue(Uri.parse('mxc://placeholder'));
}

/// Registers the GetIt singletons a [JournalDb] test environment needs and
/// stubs the mock streams/log sinks. Mirror of the original monolith's
/// shared `setUp`.
void registerJournalDbTestServices({
  required MockUpdateNotifications updateNotifications,
  required MockDomainLogger loggingService,
  required Directory documentsDirectory,
}) {
  getIt
    ..registerSingleton<UpdateNotifications>(updateNotifications)
    ..registerSingleton<DomainLogger>(loggingService)
    ..registerSingleton<Directory>(documentsDirectory);

  when(() => updateNotifications.updateStream).thenAnswer(
    (_) => Stream<Set<String>>.fromIterable([]),
  );

  when(
    () => loggingService.log(
      any<LogDomain>(),
      any<String>(),
      subDomain: any<String?>(named: 'subDomain'),
      level: any<InsightLevel>(named: 'level'),
    ),
  ).thenAnswer((_) => Future<void>.value());

  when(
    () => loggingService.error(
      any<LogDomain>(),
      any<Object>(),
      stackTrace: any<StackTrace?>(named: 'stackTrace'),
      subDomain: any<String?>(named: 'subDomain'),
      message: any<String?>(named: 'message'),
    ),
  ).thenAnswer((_) async {});
}

/// Unregisters everything [registerJournalDbTestServices] registered.
void unregisterJournalDbTestServices() {
  getIt
    ..unregister<UpdateNotifications>()
    ..unregister<DomainLogger>()
    ..unregister<Directory>();
}

/// Deterministic timestamp shared by the entry builders below.
final testDate = DateTime(2024, 3, 15, 10, 30);

Future<File> createPlaceholderDbFile(Directory docDir) async {
  final dbFile = File('${docDir.path}/$journalDbFileName');
  if (!dbFile.existsSync()) {
    await dbFile.create(recursive: true);
  }
  await dbFile.writeAsBytes(const [0]);
  return dbFile;
}

Future<void> seedDeletedDatabaseContent(
  JournalDb database,
  DateTime deletionTime,
) async {
  final dashboard = testDashboardConfig.copyWith(
    id: 'dashboard-${deletionTime.millisecondsSinceEpoch}',
    createdAt: deletionTime,
    updatedAt: deletionTime,
    deletedAt: deletionTime,
  );
  final measurable = measurableWater.copyWith(
    id: 'measurable-${deletionTime.millisecondsSinceEpoch}',
    createdAt: deletionTime,
    updatedAt: deletionTime,
    deletedAt: deletionTime,
  );
  final journalEntry = buildTextEntry(
    id: 'deleted-${deletionTime.millisecondsSinceEpoch}',
    timestamp: deletionTime,
    text: 'Marked for purge',
    deletedAt: deletionTime,
  );

  await database.upsertDashboardDefinition(dashboard);
  await database.upsertMeasurableDataType(measurable);
  await database.updateJournalEntity(journalEntry);
}

JournalEntity buildTextEntry({
  required String id,
  required DateTime timestamp,
  required String text,
  DateTime? deletedAt,
  Duration duration = const Duration(minutes: 1),
}) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp.add(duration),
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    entryText: EntryText(plainText: text),
  );
}

JournalEntity buildImageEntry({
  required String id,
  required DateTime timestamp,
  required String imageDirectory,
  required String imageFile,
  DateTime? deletedAt,
}) {
  return JournalEntity.journalImage(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    data: ImageData(
      imageId: id,
      imageFile: imageFile,
      imageDirectory: imageDirectory,
      capturedAt: timestamp,
    ),
    entryText: const EntryText(plainText: 'image entry'),
  );
}

JournalEntity buildAudioEntry({
  required String id,
  required DateTime timestamp,
  required String audioDirectory,
  required String audioFile,
  DateTime? deletedAt,
}) {
  return JournalEntity.journalAudio(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    data: AudioData(
      dateFrom: timestamp,
      dateTo: timestamp,
      duration: const Duration(minutes: 5),
      audioDirectory: audioDirectory,
      audioFile: audioFile,
    ),
    entryText: const EntryText(plainText: 'audio entry'),
  );
}

JournalEntity buildWorkoutEntry({
  required String id,
  required DateTime start,
  required DateTime end,
  DateTime? deletedAt,
}) {
  return JournalEntity.workout(
    meta: Metadata(
      id: id,
      createdAt: end,
      updatedAt: end,
      dateFrom: start,
      dateTo: end,
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    data: WorkoutData(
      distance: 1000,
      dateFrom: start,
      dateTo: end,
      workoutType: 'running',
      energy: 200,
      id: 'workout-$id',
      source: 'test',
    ),
  );
}

JournalEntity buildHabitCompletionEntry({
  required String id,
  required String habitId,
  required DateTime timestamp,
  DateTime? deletedAt,
  DateTime? writtenAt,
  HabitCompletionType? completionType,
}) {
  final effectiveWrittenAt = writtenAt ?? timestamp;
  return JournalEntity.habitCompletion(
    meta: Metadata(
      id: id,
      createdAt: effectiveWrittenAt,
      updatedAt: effectiveWrittenAt,
      dateFrom: timestamp,
      dateTo: timestamp,
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    data: HabitCompletionData(
      habitId: habitId,
      dateFrom: timestamp,
      dateTo: timestamp,
      completionType: completionType,
    ),
  );
}

JournalEntity buildQuantitativeEntry({
  required String id,
  required String dataType,
  required DateTime timestamp,
  double value = 1,
  DateTime? deletedAt,
}) {
  return JournalEntity.quantitative(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    data: QuantitativeData.discreteQuantityData(
      dateFrom: timestamp,
      dateTo: timestamp,
      value: value,
      dataType: dataType,
      unit: 'unit',
    ),
  );
}

JournalEntity createJournalEntry(
  String text, {
  String? id,
  List<String>? labelIds,
}) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id ?? UniqueKey().toString(),
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
      starred: false,
      private: false,
      labelIds: labelIds,
    ),
    entryText: EntryText(plainText: text),
  );
}

JournalEntity createJournalEntryWithVclock(
  VectorClock vclock, {
  String? id,
  List<String>? labelIds,
}) {
  final entryId = id ?? UniqueKey().toString();

  return JournalEntity.journalEntry(
    meta: Metadata(
      id: entryId,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
      vectorClock: vclock,
      starred: false,
      private: false,
      labelIds: labelIds,
    ),
    entryText: const EntryText(plainText: 'Entry with vector clock'),
  );
}

JournalEntity buildJournalEntry({
  required String id,
  required DateTime timestamp,
  required String text,
  bool starred = false,
  bool privateFlag = false,
  EntryFlag? flag,
  String? categoryId,
}) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      starred: starred,
      private: privateFlag,
      flag: flag,
      categoryId: categoryId,
    ),
    entryText: EntryText(plainText: text),
  );
}

JournalEntity buildTaskEntry({
  required String id,
  required DateTime timestamp,
  required TaskStatus status,
  String title = 'Task title',
  bool starred = false,
  bool privateFlag = false,
  String? categoryId,
  DateTime? due,
}) {
  return JournalEntity.task(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      starred: starred,
      private: privateFlag,
      categoryId: categoryId,
    ),
    data: testTask.data.copyWith(
      status: status,
      statusHistory: [status],
      dateFrom: timestamp,
      dateTo: timestamp,
      title: title,
      due: due,
    ),
    entryText: const EntryText(plainText: 'Task body'),
  );
}
