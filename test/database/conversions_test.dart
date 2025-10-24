// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';

import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'package:research_package/model.dart';

import '../test_data/test_data.dart';

final DateTime _baseTime = DateTime(2024, 1, 1, 12);

Metadata _meta(String id, {DateTime? deletedAt}) {
  return Metadata(
    id: id,
    createdAt: _baseTime,
    updatedAt: _baseTime,
    dateFrom: _baseTime,
    dateTo: _baseTime,
    deletedAt: deletedAt,
  );
}

Geolocation _geo(double latitude) {
  return Geolocation(
    createdAt: _baseTime,
    latitude: latitude,
    longitude: latitude + 0.1,
    geohashString: 'geo$latitude',
  );
}

JournalEntity _taskEntry({
  required String id,
  required TaskStatus status,
  Geolocation? geolocation,
  DateTime? deletedAt,
}) {
  final data = testTask.data.copyWith(
    status: status,
    statusHistory: [status],
    dateFrom: _baseTime,
    dateTo: _baseTime,
    title: 'Task $id',
  );
  return JournalEntity.task(
    meta: _meta(id, deletedAt: deletedAt),
    data: data,
    geolocation: geolocation,
    entryText: const EntryText(plainText: 'Task body'),
  );
}

JournalEntity _surveyEntry(String id) {
  return JournalEntity.survey(
    meta: _meta(id),
    data: SurveyData(
      taskResult: RPTaskResult(identifier: 'survey_$id'),
      scoreDefinitions: const {},
      calculatedScores: const {},
    ),
  );
}

JournalEntity _aiResponseEntry(String id, {AiResponseType? type}) {
  return JournalEntity.aiResponse(
    meta: _meta(id),
    data: AiResponseData(
      model: 'gpt',
      systemMessage: 'system',
      prompt: 'prompt',
      thoughts: 'thoughts',
      response: 'response',
      suggestedActionItems: const [],
      type: type,
    ),
  );
}

JournalEntity _measurementEntry(String id, {Geolocation? geolocation}) {
  return JournalEntity.measurement(
    meta: _meta(id),
    data: MeasurementData(
      value: 42,
      dataTypeId: 'measurement-type',
      dateFrom: _baseTime,
      dateTo: _baseTime,
    ),
    geolocation: geolocation,
  );
}

JournalEntity _quantitativeEntry(String id) {
  return JournalEntity.quantitative(
    meta: _meta(id),
    data: QuantitativeData.discreteQuantityData(
      dateFrom: _baseTime,
      dateTo: _baseTime,
      value: 10,
      dataType: 'quant-type',
      unit: 'unit',
    ),
  );
}

JournalEntity _workoutEntry(String id) {
  return JournalEntity.workout(
    meta: _meta(id),
    data: WorkoutData(
      id: 'w$id',
      workoutType: 'running',
      dateFrom: _baseTime,
      dateTo: _baseTime.add(const Duration(minutes: 30)),
      energy: 200,
      distance: 5000,
      source: 'apple',
    ),
  );
}

JournalEntity _habitEntry(String id) {
  return JournalEntity.habitCompletion(
    meta: _meta(id),
    data: HabitCompletionData(
      habitId: 'habit-$id',
      dateFrom: _baseTime,
      dateTo: _baseTime,
    ),
  );
}

void main() {
  test('toDbEntity uses correct type discriminator for all variants', () {
    final entries = <String, JournalEntity>{
      'JournalEntry': JournalEntity.journalEntry(
        meta: _meta('entry'),
        entryText: const EntryText(plainText: 'text'),
      ),
      'JournalImage': JournalEntity.journalImage(
        meta: _meta('image'),
        data: ImageData(
          imageId: 'img',
          imageFile: 'image.jpg',
          imageDirectory: '/images/',
          capturedAt: _baseTime,
        ),
      ),
      'JournalAudio': JournalEntity.journalAudio(
        meta: _meta('audio'),
        data: AudioData(
          dateFrom: _baseTime,
          dateTo: _baseTime,
          duration: const Duration(minutes: 3),
          audioFile: 'clip.m4a',
          audioDirectory: '/audio/',
        ),
      ),
      'Task': _taskEntry(
        id: 'task',
        status: TaskStatus.open(
          id: 'open',
          createdAt: _baseTime,
          utcOffset: 0,
        ),
      ),
      'JournalEvent': JournalEntity.event(
        meta: _meta('event'),
        data: const EventData(
          title: 'Event',
          stars: 5,
          status: EventStatus.planned,
        ),
      ),
      'AiResponse': _aiResponseEntry(
        'ai',
        type: AiResponseType.taskSummary,
      ),
      'Checklist': JournalEntity.checklist(
        meta: _meta('checklist'),
        data: const ChecklistData(
          title: 'Checklist',
          linkedChecklistItems: ['item'],
          linkedTasks: ['task'],
        ),
      ),
      'ChecklistItem': JournalEntity.checklistItem(
        meta: _meta('checklist-item'),
        data: const ChecklistItemData(
          title: 'Item',
          isChecked: false,
          linkedChecklists: [],
          id: 'item',
        ),
      ),
      'QuantitativeEntry': _quantitativeEntry('quant'),
      'MeasurementEntry': _measurementEntry('measurement'),
      'WorkoutEntry': _workoutEntry('workout'),
      'HabitCompletionEntry': _habitEntry('habit'),
      'SurveyEntry': _surveyEntry('survey'),
    };

    entries.forEach((expectedType, entity) {
      final dbEntity = toDbEntity(entity);
      expect(dbEntity.type, expectedType);
      expect(dbEntity.id, entity.meta.id);
    });
  });

  test('toDbEntity sets subtype for QuantitativeEntry', () {
    final entry = _quantitativeEntry('quant-subtype');
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.subtype, 'quant-type');
  });

  test('toDbEntity sets subtype for MeasurementEntry', () {
    final entry = _measurementEntry('measurement-subtype');
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.subtype, 'measurement-type');
  });

  test('toDbEntity sets subtype for SurveyEntry', () {
    final entry = _surveyEntry('survey-subtype');
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.subtype, 'survey_survey-subtype');
  });

  test('toDbEntity sets subtype for WorkoutEntry', () {
    final entry = _workoutEntry('workout-subtype');
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.subtype, 'running');
  });

  test('toDbEntity sets subtype for HabitCompletionEntry', () {
    final entry = _habitEntry('habit-subtype');
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.subtype, 'habit-habit-subtype');
  });

  test('toDbEntity sets subtype for AiResponseEntry', () {
    final entry =
        _aiResponseEntry('ai-subtype', type: AiResponseType.imageAnalysis);
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.subtype, AiResponseType.imageAnalysis.name);
  });

  test('toDbEntity sets task flag for task entries', () {
    final entry = _taskEntry(
      id: 'task-flag',
      status: TaskStatus.open(
        id: 'open-flag',
        createdAt: _baseTime,
        utcOffset: 0,
      ),
    );
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.task, isTrue);
  });

  test('toDbEntity extracts geolocation from JournalAudio', () async {
    final entry = JournalEntity.journalAudio(
      meta: _meta('audio-geo'),
      data: AudioData(
        dateFrom: _baseTime,
        dateTo: _baseTime,
        duration: const Duration(seconds: 10),
        audioFile: 'file.m4a',
        audioDirectory: '/audio/',
      ),
      geolocation: _geo(10),
    );
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.latitude, 10);
    expect(dbEntity.longitude, 10.1);
    expect(dbEntity.geohashString, 'geo10.0');
  });

  test('toDbEntity extracts geolocation from JournalImage', () {
    final entry = JournalEntity.journalImage(
      meta: _meta('image-geo'),
      data: ImageData(
        imageId: 'img-geo',
        imageFile: 'image.png',
        imageDirectory: '/images/',
        capturedAt: _baseTime,
      ),
      geolocation: _geo(11),
    );
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.latitude, 11);
    expect(dbEntity.longitude, 11.1);
    expect(dbEntity.geohashString, 'geo11.0');
  });

  test('toDbEntity extracts geolocation from JournalEntry', () {
    final entry = JournalEntity.journalEntry(
      meta: _meta('entry-geo'),
      entryText: const EntryText(plainText: 'geo'),
      geolocation: _geo(12),
    );
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.latitude, 12);
    expect(dbEntity.longitude, 12.1);
    expect(dbEntity.geohashString, 'geo12.0');
  });

  test('toDbEntity extracts geolocation from MeasurementEntry', () {
    final entry = _measurementEntry('measurement-geo', geolocation: _geo(13));
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.latitude, 13);
    expect(dbEntity.longitude, 13.1);
  });

  test('toDbEntity extracts geolocation from Task entries', () {
    final entry = _taskEntry(
      id: 'task-geo',
      geolocation: _geo(14),
      status: TaskStatus.open(
        id: 'open-geo',
        createdAt: _baseTime,
        utcOffset: 0,
      ),
    );
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.latitude, 14);
    expect(dbEntity.longitude, 14.1);
  });

  test('toDbEntity sets taskStatus correctly', () {
    final status = TaskStatus.inProgress(
      id: 'status',
      createdAt: _baseTime,
      utcOffset: 0,
    );
    final entry = _taskEntry(
      id: 'task-status',
      status: status,
    );
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.taskStatus, 'IN PROGRESS');
  });

  test('toDbEntity sets deleted flag when deletedAt is present', () {
    final entry = JournalEntity.journalEntry(
      meta: _meta('deleted', deletedAt: _baseTime),
      entryText: const EntryText(plainText: 'deleted'),
    );
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.deleted, isTrue);
  });

  test('toDbEntity keeps deleted flag false when deletedAt is null', () {
    final entry = JournalEntity.journalEntry(
      meta: _meta('not-deleted'),
      entryText: const EntryText(plainText: 'active'),
    );
    final dbEntity = toDbEntity(entry);
    expect(dbEntity.deleted, isFalse);
  });

  test('measurableDataTypeStreamMapper sorts by displayName (case-insensitive)',
      () {
    final typeB = measurableWater.copyWith(
      id: 'water-b',
      displayName: 'Beta',
    );
    final typeA = measurableWater.copyWith(
      id: 'water-a',
      displayName: 'alpha',
    );

    final mapped = measurableDataTypeStreamMapper([
      measurableDbEntity(typeB),
      measurableDbEntity(typeA),
    ]);

    expect(mapped.map((e) => e.displayName).toList(), ['alpha', 'Beta']);
  });

  test('tagDbEntity encodes tag type correctly', () {
    final generic = tagDbEntity(testTag1);
    final person = tagDbEntity(testPersonTag1);
    final story = tagDbEntity(testStoryTag1);

    expect(generic.type, 'GenericTag');
    expect(person.type, 'PersonTag');
    expect(story.type, 'StoryTag');
  });

  test('categoryDefinitionDbEntity uses id as name when deleted', () {
    final active = categoryMindfulness.copyWith(deletedAt: null);
    final deleted = categoryMindfulness.copyWith(
      id: 'cat-id',
      deletedAt: _baseTime,
    );

    final activeDb = categoryDefinitionDbEntity(active);
    final deletedDb = categoryDefinitionDbEntity(deleted);

    expect(activeDb.name, active.name);
    expect(deletedDb.name, deleted.id);
  });

  test('linkedDbEntity serializes entry link correctly', () {
    const clock = VectorClock({'origin': 1});
    final link = EntryLink.basic(
      id: 'link-id',
      fromId: 'from',
      toId: 'to',
      createdAt: _baseTime,
      updatedAt: _baseTime,
      vectorClock: clock,
    );

    final dbEntry = linkedDbEntity(link);
    expect(dbEntry.id, 'link-id');
    expect(dbEntry.fromId, 'from');
    expect(dbEntry.toId, 'to');
    expect(dbEntry.serialized, isNotEmpty);
  });
}
