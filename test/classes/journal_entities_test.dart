import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:research_package/model.dart';

import '../helpers/entity_factories.dart';

import 'project_test_generators.dart';

void main() {
  final fixedDate = DateTime(2024, 3, 15, 10);
  final meta = TestMetadataFactory.create(
    id: 'entity-1',
    categoryId: 'cat-1',
  );

  group('AudioTranscript.fromJson', () {
    test('round-trips all fields through JSON', () {
      final transcript = AudioTranscript(
        created: fixedDate,
        library: 'whisper',
        model: 'large-v3',
        detectedLanguage: 'en',
        transcript: 'hello world',
        processingTime: const Duration(seconds: 12),
      );

      final decoded = AudioTranscript.fromJson(
        jsonDecode(jsonEncode(transcript.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.created, fixedDate);
      expect(decoded.library, 'whisper');
      expect(decoded.model, 'large-v3');
      expect(decoded.detectedLanguage, 'en');
      expect(decoded.transcript, 'hello world');
      expect(decoded.processingTime, const Duration(seconds: 12));
      expect(decoded, transcript);
    });

    test('parses minimal JSON with null optional processingTime', () {
      final decoded = AudioTranscript.fromJson(<String, dynamic>{
        'created': fixedDate.toIso8601String(),
        'library': 'lib',
        'model': 'm',
        'detectedLanguage': 'de',
        'transcript': 'hallo',
      });

      expect(decoded.processingTime, isNull);
      expect(decoded.detectedLanguage, 'de');
      expect(decoded.transcript, 'hallo');
    });
  });

  group('JournalEntityExtension simple getters', () {
    test('id, categoryId and isDeleted reflect metadata', () {
      final entry = JournalEntity.journalEntry(meta: meta);
      expect(entry.id, 'entity-1');
      expect(entry.categoryId, 'cat-1');
      expect(entry.isDeleted, isFalse);

      final deleted = JournalEntity.journalEntry(
        meta: TestMetadataFactory.create(id: 'gone').copyWith(
          deletedAt: fixedDate,
        ),
      );
      expect(deleted.isDeleted, isTrue);
    });
  });

  group('JournalEntityExtension affectedIds', () {
    test('checklistItem includes id and linked checklists (line 244)', () {
      final entity = JournalEntity.checklistItem(
        meta: meta,
        data: const ChecklistItemData(
          title: 'Buy milk',
          isChecked: false,
          linkedChecklists: ['cl-a', 'cl-b'],
        ),
      );

      expect(
        entity.affectedIds,
        <String>{'entity-1', 'cl-a', 'cl-b'},
      );
    });

    test('dayPlan includes id and dayPlanNotification (line 279)', () {
      final entity = JournalEntity.dayPlan(
        meta: meta,
        data: DayPlanData(
          planDate: fixedDate,
          status: const DayPlanStatus.draft(),
        ),
      );

      expect(
        entity.affectedIds,
        <String>{'entity-1', dayPlanNotification},
      );
    });

    test('checklist includes linked items and linked tasks', () {
      final entity = JournalEntity.checklist(
        meta: meta,
        data: const ChecklistData(
          title: 'Groceries',
          linkedChecklistItems: ['item-1', 'item-2'],
          linkedTasks: ['task-1'],
        ),
      );

      expect(
        entity.affectedIds,
        <String>{'entity-1', 'item-1', 'item-2', 'task-1'},
      );
    });

    test('journalEntry includes textEntryNotification', () {
      final entity = JournalEntity.journalEntry(meta: meta);

      expect(
        entity.affectedIds,
        <String>{'entity-1', textEntryNotification},
      );
    });

    test('journalImage includes imageNotification', () {
      final entity = JournalEntity.journalImage(
        meta: meta,
        data: ImageData(
          capturedAt: fixedDate,
          imageId: 'img-1',
          imageFile: 'photo.jpg',
          imageDirectory: '/photos',
        ),
      );
      expect(
        entity.affectedIds,
        <String>{'entity-1', imageNotification},
      );
    });

    test('journalAudio includes audioNotification', () {
      final entity = JournalEntity.journalAudio(
        meta: meta,
        data: AudioData(
          dateFrom: fixedDate,
          dateTo: fixedDate,
          audioFile: 'recording.m4a',
          audioDirectory: '/audio',
          duration: const Duration(seconds: 30),
        ),
      );
      expect(
        entity.affectedIds,
        <String>{'entity-1', audioNotification},
      );
    });

    test('task includes taskNotification', () {
      final taskStatus = TaskStatus.open(
        id: 'status-1',
        createdAt: fixedDate,
        utcOffset: 0,
      );
      final entity = JournalEntity.task(
        meta: meta,
        data: TaskData(
          status: taskStatus,
          dateFrom: fixedDate,
          dateTo: fixedDate,
          statusHistory: [],
          title: 'Test task',
        ),
      );
      expect(
        entity.affectedIds,
        <String>{'entity-1', taskNotification},
      );
    });

    test('event includes eventNotification', () {
      final entity = JournalEntity.event(
        meta: meta,
        data: const EventData(
          title: 'Meeting',
          stars: 4.5,
          status: EventStatus.completed,
        ),
      );
      expect(
        entity.affectedIds,
        <String>{'entity-1', eventNotification},
      );
    });

    test('quantitative includes its dataType', () {
      const dataType = 'HealthDataType.STEPS';
      final entity = JournalEntity.quantitative(
        meta: meta,
        data: QuantitativeData.discreteQuantityData(
          dateFrom: fixedDate,
          dateTo: fixedDate,
          value: 8000,
          dataType: dataType,
          unit: 'count',
        ),
      );
      expect(
        entity.affectedIds,
        containsAll(<String>{'entity-1', dataType}),
      );
      expect(
        entity.affectedIds.length,
        2,
        reason: 'only entity id and dataType',
      );
    });

    test('survey includes surveyNotification', () {
      final entity = JournalEntity.survey(
        meta: meta,
        data: SurveyData(
          taskResult: RPTaskResult(identifier: 'test-survey'),
          scoreDefinitions: {},
          calculatedScores: {},
        ),
      );
      expect(
        entity.affectedIds,
        <String>{'entity-1', surveyNotification},
      );
    });

    test(
      'habitCompletion includes habitId and habitCompletionNotification',
      () {
        const habitId = 'habit-42';
        final entity = JournalEntity.habitCompletion(
          meta: meta,
          data: HabitCompletionData(
            dateFrom: fixedDate,
            dateTo: fixedDate,
            habitId: habitId,
          ),
        );
        expect(
          entity.affectedIds,
          <String>{'entity-1', habitId, habitCompletionNotification},
        );
      },
    );

    test('workout includes workoutNotification and workoutType', () {
      const workoutType = 'HKWorkoutActivityTypeRunning';
      final entity = JournalEntity.workout(
        meta: meta,
        data: WorkoutData(
          dateFrom: fixedDate,
          dateTo: fixedDate,
          id: 'workout-1',
          workoutType: workoutType,
          energy: 350,
          distance: 5000,
          source: 'Apple Watch',
        ),
      );
      expect(
        entity.affectedIds,
        <String>{'entity-1', workoutNotification, workoutType},
      );
    });

    test('measurement includes its dataTypeId', () {
      const dataTypeId = 'dt-weight';
      final entity = JournalEntity.measurement(
        meta: meta,
        data: MeasurementData(
          dateFrom: fixedDate,
          dateTo: fixedDate,
          value: 80.5,
          dataTypeId: dataTypeId,
        ),
      );
      expect(
        entity.affectedIds,
        <String>{'entity-1', dataTypeId},
      );
    });

    test('aiResponse includes aiResponseNotification', () {
      final entity = JournalEntity.aiResponse(
        meta: meta,
        data: const AiResponseData(
          model: 'claude-3',
          systemMessage: 'sys',
          prompt: 'prompt',
          thoughts: '',
          response: 'response text',
        ),
      );
      expect(
        entity.affectedIds,
        <String>{'entity-1', aiResponseNotification},
      );
    });

    test('rating includes ratingNotification', () {
      final entity = JournalEntity.rating(
        meta: meta,
        data: const RatingData(
          targetId: 'target-1',
          dimensions: [],
        ),
      );
      expect(
        entity.affectedIds,
        <String>{'entity-1', ratingNotification},
      );
    });

    test('project includes projectNotification', () {
      final projectStatus = ProjectStatus.active(
        id: 'proj-status-1',
        createdAt: fixedDate,
        utcOffset: 0,
      );
      final entity = JournalEntity.project(
        meta: meta,
        data: ProjectData(
          title: 'My Project',
          status: projectStatus,
          dateFrom: fixedDate,
          dateTo: fixedDate,
        ),
      );
      expect(
        entity.affectedIds,
        <String>{'entity-1', projectNotification},
      );
    });
  });

  group('Metadata JSON round-trips — static examples', () {
    final date = DateTime(2024, 3, 15, 10);

    Metadata roundTrip(Metadata m) => Metadata.fromJson(
      jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
    );

    test('minimal Metadata survives JSON round-trip', () {
      final m = Metadata(
        id: 'meta-1',
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date,
      );
      final decoded = roundTrip(m);
      expect(decoded, m, reason: 'minimal Metadata round-trip');
      expect(decoded.id, 'meta-1');
      expect(decoded.categoryId, isNull);
      expect(decoded.labelIds, isNull);
      expect(decoded.flag, isNull);
    });

    test('Metadata with all optional fields survives JSON round-trip', () {
      final m = Metadata(
        id: 'meta-2',
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date.add(const Duration(hours: 1)),
        categoryId: 'cat-1',
        labelIds: ['lbl-1', 'lbl-2'],
        utcOffset: 120,
        timezone: 'Europe/Berlin',
        vectorClock: const VectorClock({'node-a': 3, 'node-b': 1}),
        deletedAt: DateTime(2024, 12, 31),
        flag: EntryFlag.followUpNeeded,
        starred: true,
        private: false,
      );
      final decoded = roundTrip(m);
      expect(decoded, m, reason: 'full Metadata round-trip');
      expect(decoded.categoryId, 'cat-1');
      expect(decoded.labelIds, ['lbl-1', 'lbl-2']);
      expect(decoded.vectorClock?.vclock, {'node-a': 3, 'node-b': 1});
      expect(decoded.flag, EntryFlag.followUpNeeded);
      expect(decoded.starred, isTrue);
    });

    test('Metadata with EntryFlag.none survives JSON round-trip', () {
      final m = Metadata(
        id: 'meta-3',
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date,
        flag: EntryFlag.none,
      );
      final decoded = roundTrip(m);
      expect(decoded.flag, EntryFlag.none);
    });

    test('Metadata with EntryFlag.import survives JSON round-trip', () {
      final m = Metadata(
        id: 'meta-4',
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date,
        flag: EntryFlag.import,
      );
      final decoded = roundTrip(m);
      expect(decoded.flag, EntryFlag.import);
    });
  });

  group('Metadata Glados round-trips', () {
    glados.Glados(
      glados.any.generatedMetadata,
      glados.ExploreConfig(numRuns: 120),
    ).test('Metadata round-trips through JSON', (scenario) {
      final m = scenario.metadata;
      final decoded = Metadata.fromJson(
        jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, m, reason: '$scenario');
      expect(decoded.id, m.id, reason: 'id preserved');
      expect(decoded.flag, m.flag, reason: 'flag preserved');
      expect(decoded.labelIds, m.labelIds, reason: 'labelIds preserved');
    }, tags: 'glados');
  });

  final projectTestDate = DateTime(2024, 3, 15, 10, 30);

  group('JournalEntity.project', () {
    late ProjectEntry projectEntry;

    setUp(() {
      projectEntry = ProjectEntry(
        meta: Metadata(
          id: 'project-001',
          createdAt: projectTestDate,
          updatedAt: projectTestDate,
          dateFrom: projectTestDate,
          dateTo: projectTestDate,
          categoryId: 'cat-engineering',
        ),
        data: ProjectData(
          title: 'Device Synchronization',
          status: ProjectStatus.active(
            id: 'status-1',
            createdAt: projectTestDate,
            utcOffset: 60,
          ),
          dateFrom: projectTestDate,
          dateTo: projectTestDate,
          targetDate: DateTime(2024, 6, 30),
        ),
      );
    });

    test('round-trip JSON serialization preserves all fields', () {
      final json = jsonDecode(jsonEncode(projectEntry)) as Map<String, dynamic>;
      final restored = JournalEntity.fromJson(json);

      expect(restored, isA<ProjectEntry>());
      final restoredProject = restored as ProjectEntry;
      expect(restoredProject.meta.id, 'project-001');
      expect(restoredProject.data.title, 'Device Synchronization');
      expect(restoredProject.data.status, isA<ProjectActive>());
      expect(restoredProject.data.targetDate, DateTime(2024, 6, 30));
    });

    test('toDbEntity produces correct type and category', () {
      final dbEntity = toDbEntity(projectEntry);

      expect(dbEntity.id, 'project-001');
      expect(dbEntity.type, 'Project');
      expect(dbEntity.category, 'cat-engineering');
      expect(dbEntity.deleted, false);
    });

    test('fromDbEntity round-trips correctly', () {
      final dbEntity = toDbEntity(projectEntry);
      final restored = fromDbEntity(dbEntity);

      expect(restored, isA<ProjectEntry>());
      final restoredProject = restored as ProjectEntry;
      expect(restoredProject.meta.id, 'project-001');
      expect(restoredProject.data.title, 'Device Synchronization');
    });

    test('id and categoryId extension accessors work', () {
      final entity = projectEntry as JournalEntity;
      expect(entity.id, 'project-001');
      expect(entity.categoryId, 'cat-engineering');
      expect(entity.isDeleted, false);
    });

    test('affectedIds includes project notification token', () {
      final entity = projectEntry as JournalEntity;
      expect(entity.affectedIds, contains('project-001'));
      expect(entity.affectedIds, contains('PROJECT'));
    });

    glados.Glados(
      glados.any.generatedProjectEntry,
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'round-trips generated project entries through JSON and DB rows',
      (
        scenario,
      ) {
        final projectEntry = scenario.projectEntry;

        final jsonRestored = JournalEntity.fromJson(
          jsonDecode(jsonEncode(projectEntry.toJson())) as Map<String, dynamic>,
        );
        final dbEntity = toDbEntity(projectEntry);
        final dbRestored = fromDbEntity(dbEntity);

        expect(jsonRestored, equals(projectEntry), reason: '$scenario');
        expect(dbRestored, equals(projectEntry), reason: '$scenario');
        expect(dbEntity.id, projectEntry.meta.id, reason: '$scenario');
        expect(dbEntity.type, 'Project', reason: '$scenario');
        expect(
          dbEntity.category,
          projectEntry.meta.categoryId ?? '',
          reason: '$scenario',
        );
        expect(
          dbEntity.deleted,
          projectEntry.meta.deletedAt != null,
          reason: '$scenario',
        );
        expect(projectEntry.affectedIds, contains(projectEntry.meta.id));
        expect(projectEntry.affectedIds, contains('PROJECT'));
      },
      tags: 'glados',
    );
  });
}

// ---------------------------------------------------------------------------
// Glados generator helpers for Metadata.
// ---------------------------------------------------------------------------

class _GeneratedMetadata {
  const _GeneratedMetadata({
    required this.idSlot,
    required this.dateSlot,
    required this.categorySlot,
    required this.labelCountSlot,
    required this.flagSlot,
    required this.optionalsSlot,
  });

  final int idSlot;
  final int dateSlot;
  final int categorySlot;
  final int labelCountSlot;
  final int flagSlot;
  final int optionalsSlot;

  Metadata get metadata {
    final date = DateTime.utc(2024, (dateSlot % 12) + 1, (dateSlot % 28) + 1);
    final categoryId = categorySlot.isEven ? null : 'cat-$categorySlot';
    final labelCount = labelCountSlot % 4;
    final labelIds = labelCount == 0
        ? null
        : List.generate(labelCount, (i) => 'lbl-$idSlot-$i');
    final flag = flagSlot % 4 == 0
        ? null
        : EntryFlag.values[flagSlot % EntryFlag.values.length];
    final vclock = optionalsSlot.isEven
        ? null
        : VectorClock({'node-$idSlot': optionalsSlot % 10});
    final deletedAt = optionalsSlot % 5 == 0 ? DateTime(2025) : null;

    return Metadata(
      id: 'meta-$idSlot',
      createdAt: date,
      updatedAt: date,
      dateFrom: date,
      dateTo: date,
      categoryId: categoryId,
      labelIds: labelIds,
      utcOffset: optionalsSlot % 3 == 0 ? null : (optionalsSlot % 720) - 360,
      timezone: optionalsSlot.isOdd ? 'UTC' : null,
      vectorClock: vclock,
      deletedAt: deletedAt,
      flag: flag,
      starred: optionalsSlot.isEven ? true : null,
      private: optionalsSlot % 3 == 0 ? false : null,
    );
  }

  @override
  String toString() =>
      '_GeneratedMetadata(idSlot: $idSlot, dateSlot: $dateSlot, '
      'flagSlot: $flagSlot, optionalsSlot: $optionalsSlot)';
}

extension _AnyJournalEntities on glados.Any {
  glados.Generator<_GeneratedMetadata> get generatedMetadata =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 15),
        (
          idSlot,
          dateSlot,
          categorySlot,
          labelCountSlot,
          flagSlot,
          optionalsSlot,
        ) => _GeneratedMetadata(
          idSlot: idSlot,
          dateSlot: dateSlot,
          categorySlot: categorySlot,
          labelCountSlot: labelCountSlot,
          flagSlot: flagSlot,
          optionalsSlot: optionalsSlot,
        ),
      );
}
