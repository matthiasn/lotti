import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/skill_type.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/backfill/inference_backfill.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_detector.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import 'backfill_fixtures.dart';

const _taskId = 'task-1';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalDb db;
  late MockProfileAutomationService automation;
  late InferenceBackfillDetector detector;

  setUp(() {
    db = MockJournalDb();
    automation = MockProfileAutomationService();
    detector = InferenceBackfillDetector(db: db, automation: automation);
    when(
      () => db.journalEntityById(_taskId),
    ).thenAnswer((_) async => TestTaskFactory.create(id: _taskId));
  });

  void stubLinked(
    List<JournalEntity> linked, {
    Map<String, List<JournalEntity>> responses = const {},
  }) {
    when(() => db.getLinkedEntities(_taskId)).thenAnswer((_) async => linked);
    when(
      () => db.getBulkLinkedEntities(any()),
    ).thenAnswer((_) async => responses);
  }

  void allowKinds(Set<SkillType> allowed) {
    when(
      () => automation.hasAutomatedSkillType(
        subjectId: any(named: 'subjectId'),
        skillType: any(named: 'skillType'),
      ),
    ).thenAnswer(
      (invocation) async => allowed.contains(
        invocation.namedArguments[#skillType] as SkillType,
      ),
    );
  }

  group('scan', () {
    test('finds nothing for an id that is not a task', () async {
      when(
        () => db.journalEntityById('note'),
      ).thenAnswer((_) async => backfillImage(id: 'note'));

      final scan = await detector.scan('note');

      expect(scan.candidates, isEmpty);
      expect(scan.watchedIds, isEmpty);
      verifyNever(() => db.getLinkedEntities(any()));
    });

    test('finds nothing for a deleted task', () async {
      final task = TestTaskFactory.create(id: _taskId);
      when(() => db.journalEntityById(_taskId)).thenAnswer(
        (_) async => task.copyWith(
          meta: task.meta.copyWith(deletedAt: testFixedDate),
        ),
      );

      final scan = await detector.scan(_taskId);

      expect(scan.candidates, isEmpty);
      verifyNever(() => db.getLinkedEntities(any()));
    });

    test('a task without media yields nothing and watches the task', () async {
      stubLinked([TestTaskFactory.create(id: 'linked-task')]);
      allowKinds(SkillType.values.toSet());

      final scan = await detector.scan(_taskId);

      expect(scan.candidates, isEmpty);
      expect(scan.watchedIds, {_taskId});
      verifyNever(() => db.getBulkLinkedEntities(any()));
      verifyNever(
        () => automation.hasAutomatedSkillType(
          subjectId: any(named: 'subjectId'),
          skillType: any(named: 'skillType'),
        ),
      );
    });

    test('offers one suggestion per entry missing inference, of every kind '
        'the task automates', () async {
      stubLinked(
        [
          backfillImage(id: 'img-new', dateFrom: DateTime(2024, 3, 4)),
          backfillImage(id: 'img-old', dateFrom: DateTime(2024, 3)),
          backfillImage(id: 'img-done', dateFrom: DateTime(2024, 3, 5)),
          backfillAudio(id: 'rec', dateFrom: DateTime(2024, 3, 3)),
          backfillAudio(
            id: 'rec-long',
            transcript: longTranscript,
            dateFrom: DateTime(2024, 3, 2),
          ),
          TestTaskFactory.create(id: 'not-media'),
        ],
        responses: {
          'img-done': [backfillResponse(AiResponseType.imageAnalysis)],
        },
      );
      allowKinds(SkillType.values.toSet());

      final scan = await detector.scan(_taskId);

      expect(
        scan.candidates.map((c) => (c.entryId, c.kind)),
        [
          ('img-new', InferenceBackfillKind.imageAnalysis),
          ('rec', InferenceBackfillKind.transcription),
          ('rec-long', InferenceBackfillKind.audioSummary),
          ('img-old', InferenceBackfillKind.imageAnalysis),
        ],
      );
      expect(scan.watchedIds, {
        _taskId,
        'img-new',
        'img-old',
        'img-done',
        'rec',
        'rec-long',
      });
      // The gate is asked once per kind, not once per entry.
      verify(
        () => automation.hasAutomatedSkillType(
          subjectId: _taskId,
          skillType: SkillType.imageAnalysis,
        ),
      ).called(1);
    });

    test('drops the kinds the task does not automate', () async {
      stubLinked([
        backfillImage(id: 'img'),
        backfillAudio(id: 'rec'),
      ]);
      allowKinds({SkillType.transcription});

      final scan = await detector.scan(_taskId);

      expect(scan.candidates.map((c) => c.entryId), ['rec']);
    });

    test('offers nothing when the category has automatic inference off', () {
      // The service folds the category switch into hasAutomatedSkillType, so
      // a switched-off category answers false for every kind.
      stubLinked([backfillImage(id: 'img'), backfillAudio(id: 'rec')]);
      allowKinds(const {});

      expect(
        detector.scan(_taskId).then((scan) => scan.candidates),
        completion(isEmpty),
      );
    });
  });

  group('isStillMissing', () {
    final candidate = InferenceBackfillCandidate(
      entryId: 'rec',
      kind: InferenceBackfillKind.transcription,
      capturedAt: testFixedDate,
      createdAt: testFixedDate,
    );

    void stubEntry(JournalEntity? entry, [List<JournalEntity>? responses]) {
      when(() => db.journalEntityById('rec')).thenAnswer((_) async => entry);
      when(() => db.getBulkLinkedEntities({'rec'})).thenAnswer(
        (_) async => {'rec': ?responses},
      );
    }

    test('is true while the entry still lacks it', () async {
      stubEntry(backfillAudio(id: 'rec'));
      expect(await detector.isStillMissing(candidate), isTrue);
    });

    test('is false once the inference has landed', () async {
      stubEntry(backfillAudio(id: 'rec', transcript: 'Buy milk.'));
      expect(await detector.isStillMissing(candidate), isFalse);
    });

    test('is false once the entry needs a different kind', () async {
      stubEntry(backfillAudio(id: 'rec', transcript: longTranscript));
      expect(await detector.isStillMissing(candidate), isFalse);
    });

    test('reads the responses linked from the entry', () async {
      stubEntry(backfillImage(id: 'rec'), [
        backfillResponse(AiResponseType.imageAnalysis),
      ]);
      expect(
        await detector.isStillMissing(
          InferenceBackfillCandidate(
            entryId: 'rec',
            kind: InferenceBackfillKind.imageAnalysis,
            capturedAt: testFixedDate,
            createdAt: testFixedDate,
          ),
        ),
        isFalse,
      );
    });

    test('is false when the entry is gone', () async {
      stubEntry(null);
      expect(await detector.isStillMissing(candidate), isFalse);
    });
  });
}
