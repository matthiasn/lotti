// ignore_for_file: cascade_invocations

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:research_package/model.dart';

import '../test_data/test_data.dart';

// ---------------------------------------------------------------------------
// Generators for property-based tests
// ---------------------------------------------------------------------------

extension _AnyConversionGlados on glados.Any {
  glados.Generator<TaskPriority> get taskPriority =>
      glados.AnyUtils(this).choose(TaskPriority.values);
}

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
        // ignore: deprecated_member_use_from_same_package
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
      'Project': JournalEntity.project(
        meta: _meta('project'),
        data: ProjectData(
          title: 'Test Project',
          status: ProjectStatus.active(
            id: 'ps-1',
            createdAt: _baseTime,
            utcOffset: 0,
          ),
          dateFrom: _baseTime,
          dateTo: _baseTime,
        ),
      ),
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
    final entry = _aiResponseEntry(
      'ai-subtype',
      type: AiResponseType.imageAnalysis,
    );
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

  group('toDbEntity dueAt column', () {
    Task taskWithDue(String id, DateTime? due) {
      return _taskEntry(
        id: id,
        status: TaskStatus.open(
          id: 'open-$id',
          createdAt: _baseTime,
          utcOffset: 0,
        ),
      ).map(
        task: (task) => task.copyWith(
          data: task.data.copyWith(due: due),
        ),
        // The other branches are unreachable — `_taskEntry` always returns
        // the task variant. Throw rather than silently producing the wrong
        // shape if someone changes the helper later.
        journalEntry: (_) => throw StateError('unexpected variant'),
        journalImage: (_) => throw StateError('unexpected variant'),
        journalAudio: (_) => throw StateError('unexpected variant'),
        event: (_) => throw StateError('unexpected variant'),
        aiResponse: (_) => throw StateError('unexpected variant'),
        checklist: (_) => throw StateError('unexpected variant'),
        checklistItem: (_) => throw StateError('unexpected variant'),
        quantitative: (_) => throw StateError('unexpected variant'),
        measurement: (_) => throw StateError('unexpected variant'),
        workout: (_) => throw StateError('unexpected variant'),
        habitCompletion: (_) => throw StateError('unexpected variant'),
        survey: (_) => throw StateError('unexpected variant'),
        dayPlan: (_) => throw StateError('unexpected variant'),
        rating: (_) => throw StateError('unexpected variant'),
        project: (_) => throw StateError('unexpected variant'),
      );
    }

    test('mirrors task.data.due when present', () {
      final due = DateTime(2026, 5, 1, 17, 30);
      final entry = taskWithDue('task-with-due', due);
      final dbEntity = toDbEntity(entry);
      expect(dbEntity.dueAt, due);
    });

    test('updates dueAt when the entity is upserted with a new due date', () {
      final firstDue = DateTime(2026, 5, 1, 12);
      final secondDue = DateTime(2026, 6, 1, 12);
      expect(toDbEntity(taskWithDue('task-1', firstDue)).dueAt, firstDue);
      expect(toDbEntity(taskWithDue('task-1', secondDue)).dueAt, secondDue);
    });

    test('clears dueAt to null when due is removed from the entity', () {
      final withDue = taskWithDue('task-clear-due', DateTime(2026, 5));
      // Drop `due` by serializing through fromJson with the field stripped —
      // simulates an edit in the UI that nulls the due date.
      final clearedJson =
          jsonDecode(jsonEncode(withDue)) as Map<String, dynamic>;
      (clearedJson['data'] as Map<String, dynamic>).remove('due');
      final reparsed = JournalEntity.fromJson(clearedJson);

      expect(toDbEntity(withDue).dueAt, DateTime(2026, 5));
      expect(toDbEntity(reparsed).dueAt, isNull);
    });

    test('is null for non-task entries', () {
      final entry = JournalEntity.journalEntry(
        meta: _meta('plain-entry'),
        entryText: const EntryText(plainText: 'no task here'),
      );
      final dbEntity = toDbEntity(entry);
      expect(dbEntity.dueAt, isNull);
      expect(dbEntity.task, isFalse);
    });
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

  test(
    'measurableDataTypeStreamMapper sorts by displayName (case-insensitive)',
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
    },
  );

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

  group('fromDashboardDbEntity sanitizes unknown item types', () {
    Map<String, dynamic> makeDashboardJson({
      required List<Map<String, dynamic>> items,
    }) {
      return {
        'id': 'dash-1',
        'createdAt': _baseTime.toIso8601String(),
        'updatedAt': _baseTime.toIso8601String(),
        'lastReviewed': _baseTime.toIso8601String(),
        'name': 'Test Dashboard',
        'description': 'desc',
        'items': items,
        'version': '1',
        'vectorClock': null,
        'active': true,
        'private': false,
        'days': 30,
        'runtimeType': 'dashboard',
      };
    }

    DashboardDefinitionDbEntity makeDbEntity(Map<String, dynamic> jsonMap) {
      return DashboardDefinitionDbEntity(
        id: 'dash-1',
        createdAt: _baseTime,
        updatedAt: _baseTime,
        lastReviewed: _baseTime,
        serialized: json.encode(jsonMap),
        private: false,
        deleted: false,
        active: true,
        name: 'dash-1',
      );
    }

    test('filters out removed storyTimeChart items', () {
      final dashJson = makeDashboardJson(
        items: [
          {
            'runtimeType': 'measurement',
            'id': 'measurable-1',
            'aggregationType': 'dailySum',
          },
          {
            'runtimeType': 'storyTimeChart',
            'storyTagId': 'some-tag',
            'color': '#FF0000',
          },
          {
            'runtimeType': 'healthChart',
            'color': '#00FF00',
            'healthType': 'HEART_RATE',
          },
        ],
      );

      final dashboard = fromDashboardDbEntity(makeDbEntity(dashJson));
      expect(dashboard.items, hasLength(2));
      expect(dashboard.items[0], isA<DashboardMeasurementItem>());
      expect(dashboard.items[1], isA<DashboardHealthItem>());
    });

    test('filters out removed wildcardStoryTimeChart items', () {
      final dashJson = makeDashboardJson(
        items: [
          {
            'runtimeType': 'habitChart',
            'habitId': 'habit-1',
          },
          {
            'runtimeType': 'wildcardStoryTimeChart',
            'storySubstring': 'some-substring',
            'color': '#FF0000',
          },
        ],
      );

      final dashboard = fromDashboardDbEntity(makeDbEntity(dashJson));
      expect(dashboard.items, hasLength(1));
      expect(dashboard.items[0], isA<DashboardHabitItem>());
    });

    test('preserves all valid item types unchanged', () {
      final dashJson = makeDashboardJson(
        items: [
          {
            'runtimeType': 'measurement',
            'id': 'measurable-1',
          },
          {
            'runtimeType': 'healthChart',
            'color': '#00FF00',
            'healthType': 'HEART_RATE',
          },
          {
            'runtimeType': 'workoutChart',
            'workoutType': 'running',
            'displayName': 'Running',
            'color': '#0000FF',
            'valueType': 'energy',
          },
          {
            'runtimeType': 'habitChart',
            'habitId': 'habit-1',
          },
          {
            'runtimeType': 'surveyChart',
            'colorsByScoreKey': <String, String>{},
            'surveyType': 'panas',
            'surveyName': 'PANAS',
          },
        ],
      );

      final dashboard = fromDashboardDbEntity(makeDbEntity(dashJson));
      expect(dashboard.items, hasLength(5));
    });

    test('handles dashboard with no items gracefully', () {
      final dashJson = makeDashboardJson(items: []);
      final dashboard = fromDashboardDbEntity(makeDbEntity(dashJson));
      expect(dashboard.items, isEmpty);
    });

    test('filters out completely unknown runtimeType values', () {
      final dashJson = makeDashboardJson(
        items: [
          {
            'runtimeType': 'nonExistentType',
            'someField': 'value',
          },
          {
            'runtimeType': 'measurement',
            'id': 'measurable-1',
          },
        ],
      );

      final dashboard = fromDashboardDbEntity(makeDbEntity(dashJson));
      expect(dashboard.items, hasLength(1));
      expect(dashboard.items[0], isA<DashboardMeasurementItem>());
    });

    // Glados (MED): for any interleaving of known and unknown item types the
    // sanitizer must keep exactly the known-type items and drop the rest
    // before deserialization. Kinds 0..2 are valid known items, kind 3 is an
    // unknown runtimeType.
    Map<String, dynamic> itemForKind(int kind, int index) {
      switch (kind) {
        case 0:
          return {'runtimeType': 'measurement', 'id': 'm-$index'};
        case 1:
          return {
            'runtimeType': 'healthChart',
            'color': '#00FF00',
            'healthType': 'HEART_RATE',
          };
        case 2:
          return {'runtimeType': 'habitChart', 'habitId': 'h-$index'};
        default:
          return {'runtimeType': 'unknown_$index', 'x': 'y'};
      }
    }

    glados.Glados(
      glados.any.listWithLengthInRange(0, 12, glados.any.intInRange(0, 4)),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'keeps exactly the known-type items for any known/unknown mix',
      (kinds) {
        final items = [
          for (var i = 0; i < kinds.length; i++) itemForKind(kinds[i], i),
        ];
        final expectedKnown = kinds.where((k) => k != 3).length;

        final dashboard = fromDashboardDbEntity(
          makeDbEntity(makeDashboardJson(items: items)),
        );

        expect(
          dashboard.items,
          hasLength(expectedKnown),
          reason: 'kinds=$kinds',
        );
      },
      tags: 'glados',
    );
  });

  group('dashboardStreamMapper handles parse failures gracefully', () {
    test('skips dashboards that fail to parse entirely', () {
      final validJson = json.encode({
        'id': 'dash-valid',
        'createdAt': _baseTime.toIso8601String(),
        'updatedAt': _baseTime.toIso8601String(),
        'lastReviewed': _baseTime.toIso8601String(),
        'name': 'Valid Dashboard',
        'description': 'desc',
        'items': <Map<String, dynamic>>[],
        'version': '1',
        'vectorClock': null,
        'active': true,
        'private': false,
        'days': 30,
        'runtimeType': 'dashboard',
      });

      final results = dashboardStreamMapper([
        DashboardDefinitionDbEntity(
          id: 'dash-broken',
          createdAt: _baseTime,
          updatedAt: _baseTime,
          lastReviewed: _baseTime,
          serialized: '{"invalid json that will break}',
          private: false,
          deleted: false,
          active: true,
          name: 'dash-broken',
        ),
        DashboardDefinitionDbEntity(
          id: 'dash-valid',
          createdAt: _baseTime,
          updatedAt: _baseTime,
          lastReviewed: _baseTime,
          serialized: validJson,
          private: false,
          deleted: false,
          active: true,
          name: 'dash-valid',
        ),
      ]);

      expect(results, hasLength(1));
      expect(results[0].id, 'dash-valid');
    });
  });

  // -------------------------------------------------------------------------
  // fromDbEntity — HIGH coverage gap (previously untested direct path)
  // -------------------------------------------------------------------------

  group('fromDbEntity', () {
    /// Builds a minimal `JournalDbEntity` whose `serialized` column holds a
    /// freshly round-tripped JSON blob for `entity`. The `taskPriority` column
    /// starts unset so callers can override it independently.
    JournalDbEntity makeDbEntity(
      JournalEntity entity, {
      String? taskPriorityOverride,
    }) {
      final db = toDbEntity(entity);
      return JournalDbEntity(
        id: db.id,
        createdAt: db.createdAt,
        updatedAt: db.updatedAt,
        dateFrom: db.dateFrom,
        dateTo: db.dateTo,
        deleted: db.deleted,
        starred: db.starred,
        private: db.private,
        task: db.task,
        taskStatus: db.taskStatus,
        taskPriority: taskPriorityOverride ?? db.taskPriority,
        taskPriorityRank: db.taskPriorityRank,
        flag: db.flag,
        type: db.type,
        subtype: db.subtype,
        serialized: db.serialized,
        schemaVersion: db.schemaVersion,
        plainText: db.plainText,
        latitude: db.latitude,
        longitude: db.longitude,
        geohashString: db.geohashString,
        category: db.category,
        dueAt: db.dueAt,
      );
    }

    test(
      'restores a non-Task entity with id and type intact (patch path skipped)',
      () {
        final entry = _measurementEntry('measure-rt');
        final db = makeDbEntity(entry);
        final restored = fromDbEntity(db);

        expect(
          restored.meta.id,
          entry.meta.id,
          reason: 'id must survive round-trip',
        );
        expect(
          restored,
          isA<MeasurementEntry>(),
          reason: 'variant must be preserved',
        );
        // taskPriority column is null for non-Task rows — patch branch must
        // not execute.
        expect(
          db.taskPriority,
          isNull,
          reason: 'non-Task row must not have a taskPriority column value',
        );
      },
    );

    test(
      'returns entity unchanged when taskPriority column matches serialized '
      'priority (no-op patch)',
      () {
        const priority = TaskPriority.p1High;
        final entry =
            _taskEntry(
              id: 'task-noop',
              status: TaskStatus.open(
                id: 'open-noop',
                createdAt: _baseTime,
                utcOffset: 0,
              ),
            ).maybeMap(
              task: (t) =>
                  t.copyWith(data: t.data.copyWith(priority: priority)),
              orElse: () => throw StateError('unexpected variant'),
            );

        // Column value matches the serialized JSON — patch must be a no-op.
        final db = makeDbEntity(entry, taskPriorityOverride: 'P1');
        final restored = fromDbEntity(db);

        expect(
          restored.maybeMap(
            task: (t) => t.data.priority,
            orElse: () => throw StateError('unexpected variant'),
          ),
          priority,
          reason: 'priority must be preserved when column matches JSON',
        );
      },
    );

    test(
      'overrides serialized priority with taskPriority column value when they '
      'differ (patch applies)',
      () {
        // Serialize a task with p2Medium, then supply a column that says P0.
        final entry =
            _taskEntry(
              id: 'task-override',
              status: TaskStatus.open(
                id: 'open-override',
                createdAt: _baseTime,
                utcOffset: 0,
              ),
            ).maybeMap(
              task: (t) => t.copyWith(
                data: t.data.copyWith(priority: TaskPriority.p2Medium),
              ),
              orElse: () => throw StateError('unexpected variant'),
            );

        final db = makeDbEntity(entry, taskPriorityOverride: 'P0');
        final restored = fromDbEntity(db);

        expect(
          restored.maybeMap(
            task: (t) => t.data.priority,
            orElse: () => throw StateError('unexpected variant'),
          ),
          TaskPriority.p0Urgent,
          reason: 'DB column must win when it differs from serialized JSON',
        );
        // id must be preserved regardless.
        expect(restored.meta.id, entry.meta.id);
      },
    );

    test(
      'empty taskPriority column string is treated as absent (patch skipped)',
      () {
        final entry =
            _taskEntry(
              id: 'task-empty-prio',
              status: TaskStatus.open(
                id: 'open-empty',
                createdAt: _baseTime,
                utcOffset: 0,
              ),
            ).maybeMap(
              task: (t) => t.copyWith(
                data: t.data.copyWith(priority: TaskPriority.p3Low),
              ),
              orElse: () => throw StateError('unexpected variant'),
            );

        // An empty string must NOT trigger the patch.
        final db = makeDbEntity(entry, taskPriorityOverride: '');
        final restored = fromDbEntity(db);

        expect(
          restored.maybeMap(
            task: (t) => t.data.priority,
            orElse: () => throw StateError('unexpected variant'),
          ),
          TaskPriority.p3Low,
          reason: 'empty string column must not override serialized priority',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // fromDbEntity round-trip — HIGH Glados property
  // -------------------------------------------------------------------------

  group('fromDbEntity round-trip — Glados properties', () {
    JournalEntity taskWithPriority(String id, TaskPriority priority) {
      return _taskEntry(
        id: id,
        status: TaskStatus.open(
          id: 'open-$id',
          createdAt: _baseTime,
          utcOffset: 0,
        ),
      ).maybeMap(
        task: (t) => t.copyWith(data: t.data.copyWith(priority: priority)),
        orElse: () => throw StateError('unexpected variant'),
      );
    }

    glados.Glados(
      glados.any.taskPriority,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'toDbEntity → fromDbEntity preserves id and priority for every '
      'TaskPriority value',
      (priority) {
        final entity = taskWithPriority(
          'glados-prio-${priority.name}',
          priority,
        );
        final db = toDbEntity(entity);
        final restored = fromDbEntity(db);

        expect(
          restored.meta.id,
          entity.meta.id,
          reason: 'id must survive round-trip for $priority',
        );
        expect(
          restored.maybeMap(
            task: (t) => t.data.priority,
            orElse: () => throw StateError('unexpected variant'),
          ),
          priority,
          reason: 'priority $priority must survive toDbEntity → fromDbEntity',
        );
      },
      tags: 'glados',
    );
  });

  // -------------------------------------------------------------------------
  // labelDefinitionDbEntity / fromLabelDefinitionDbEntity — MED coverage gap
  // -------------------------------------------------------------------------

  group('labelDefinitionDbEntity and fromLabelDefinitionDbEntity', () {
    LabelDefinition makeLabel({
      required String id,
      required String name,
      DateTime? deletedAt,
      bool? private,
      String color = '#FF0000',
    }) {
      return LabelDefinition(
        id: id,
        createdAt: _baseTime,
        updatedAt: _baseTime,
        name: name,
        color: color,
        vectorClock: null,
        deletedAt: deletedAt,
        private: private,
      );
    }

    test('round-trip preserves id, name, color, and private flag', () {
      final label = makeLabel(
        id: 'label-rt',
        name: 'My Label',
        color: '#ABC123',
        private: true,
      );

      final dbEntity = labelDefinitionDbEntity(label);
      final restored = fromLabelDefinitionDbEntity(dbEntity);

      expect(restored.id, label.id);
      expect(restored.name, label.name);
      expect(restored.color, label.color);
      expect(restored.private, label.private);
    });

    test('uses id as name when label is deleted', () {
      final label = makeLabel(
        id: 'deleted-label-id',
        name: 'Original Name',
        deletedAt: _baseTime,
      );

      final dbEntity = labelDefinitionDbEntity(label);

      expect(
        dbEntity.name,
        label.id,
        reason: 'deleted label must store id in the name column',
      );
      expect(dbEntity.deleted, isTrue);
    });

    test('uses original name when label is not deleted', () {
      final label = makeLabel(id: 'active-label', name: 'Active Label');

      final dbEntity = labelDefinitionDbEntity(label);

      expect(dbEntity.name, 'Active Label');
      expect(dbEntity.deleted, isFalse);
    });

    test(
      'fromLabelDefinitionDbEntity restores deletedAt from serialized JSON',
      () {
        final label = makeLabel(
          id: 'deleted-rt',
          name: 'Was Deleted',
          deletedAt: _baseTime,
        );

        final dbEntity = labelDefinitionDbEntity(label);
        final restored = fromLabelDefinitionDbEntity(dbEntity);

        expect(
          restored.deletedAt,
          _baseTime,
          reason: 'deletedAt must round-trip through serialized JSON',
        );
      },
    );

    test('labelDefinitionsStreamMapper maps a list correctly', () {
      final labels = <LabelDefinition>[
        makeLabel(id: 'label-a', name: 'Alpha'),
        makeLabel(id: 'label-b', name: 'Beta', deletedAt: _baseTime),
      ];

      final dbEntities = labels.map(labelDefinitionDbEntity).toList();
      final restored = labelDefinitionsStreamMapper(dbEntities);

      expect(restored, hasLength(2));
      expect(restored[0].id, 'label-a');
      expect(restored[1].id, 'label-b');
      expect(restored[1].deletedAt, _baseTime);
    });
  });
}
