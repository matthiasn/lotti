import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/demo/ai/demo_real_ai_wiring.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final created = DateTime(2026, 8, 5);

  CategoryDefinition category({String? defaultProfileId}) => CategoryDefinition(
    id: manualDemoCategoryId,
    createdAt: created,
    updatedAt: created,
    name: 'Penguin Operations',
    vectorClock: null,
    private: false,
    active: true,
    defaultProfileId: defaultProfileId,
  );

  Task task(String id, {String? profileId, DateTime? deletedAt}) {
    final base = TestTaskFactory.create(
      id: id,
      title: 'Task $id',
      createdAt: created,
      dateFrom: created,
      dateTo: created,
    );
    return base.copyWith(
      meta: base.meta.copyWith(deletedAt: deletedAt),
      data: base.data.copyWith(profileId: profileId),
    );
  }

  ({MockJournalDb db, MockPersistenceLogic persistence}) harness({
    required CategoryDefinition? seededCategory,
    required List<Task> tasks,
  }) {
    final db = MockJournalDb();
    final persistence = MockPersistenceLogic();
    when(
      () => db.getCategoryById(manualDemoCategoryId),
    ).thenAnswer((_) async => seededCategory);
    when(
      () => db.getJournalEntities(
        types: any(named: 'types'),
        starredStatuses: any(named: 'starredStatuses'),
        privateStatuses: any(named: 'privateStatuses'),
        flaggedStatuses: any(named: 'flaggedStatuses'),
        ids: any(named: 'ids'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((invocation) async {
      final offset = invocation.namedArguments[#offset] as int;
      return offset == 0 ? List<JournalEntity>.from(tasks) : const [];
    });
    when(
      () => persistence.upsertEntityDefinition(any()),
    ).thenAnswer((_) async => 1);
    when(
      () => persistence.updateTask(
        journalEntityId: any(named: 'journalEntityId'),
        taskData: any(named: 'taskData'),
      ),
    ).thenAnswer((_) async => true);
    return (db: db, persistence: persistence);
  }

  group('wireDemoWorldToRealProfile', () {
    test('sets the seeded category default and stamps every profile-less '
        'task, skipping deleted and already-stamped ones', () async {
      final h = harness(
        seededCategory: category(),
        tasks: [
          task('seeded-1'),
          task('seeded-2'),
          task('user-configured', profileId: 'user-picked-profile'),
          task('deleted', deletedAt: created),
        ],
      );

      await wireDemoWorldToRealProfile(
        profileId: 'real-profile',
        journalDb: h.db,
        persistence: h.persistence,
      );

      final upserted = verify(
        () => h.persistence.upsertEntityDefinition(captureAny()),
      ).captured.cast<CategoryDefinition>();
      expect(upserted.single.defaultProfileId, 'real-profile');
      expect(upserted.single.id, manualDemoCategoryId);

      final stampedIds = <String>[];
      final stampedData = <TaskData>[];
      final calls = verify(
        () => h.persistence.updateTask(
          journalEntityId: captureAny(named: 'journalEntityId'),
          taskData: captureAny(named: 'taskData'),
        ),
      ).captured;
      for (var i = 0; i < calls.length; i += 2) {
        stampedIds.add(calls[i] as String);
        stampedData.add(calls[i + 1] as TaskData);
      }
      expect(stampedIds, ['seeded-1', 'seeded-2']);
      for (final data in stampedData) {
        expect(data.profileId, 'real-profile');
      }
    });

    test('a category the user already pointed at a profile is left '
        'untouched', () async {
      final h = harness(
        seededCategory: category(defaultProfileId: 'user-picked'),
        tasks: const [],
      );

      await wireDemoWorldToRealProfile(
        profileId: 'real-profile',
        journalDb: h.db,
        persistence: h.persistence,
      );

      verifyNever(() => h.persistence.upsertEntityDefinition(any()));
    });

    test('a seeded world larger than one query page is stamped completely — '
        'pagination must keep reading past the first 200 rows', () async {
      final tasks = [for (var i = 0; i < 201; i++) task('seeded-$i')];
      final db = MockJournalDb();
      final persistence = MockPersistenceLogic();
      when(
        () => db.getCategoryById(manualDemoCategoryId),
      ).thenAnswer((_) async => category());
      when(
        () => db.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: any(named: 'starredStatuses'),
          privateStatuses: any(named: 'privateStatuses'),
          flaggedStatuses: any(named: 'flaggedStatuses'),
          ids: any(named: 'ids'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((invocation) async {
        final offset = invocation.namedArguments[#offset] as int;
        final limit = invocation.namedArguments[#limit] as int;
        return tasks.skip(offset).take(limit).toList();
      });
      when(
        () => persistence.upsertEntityDefinition(any()),
      ).thenAnswer((_) async => 1);
      when(
        () => persistence.updateTask(
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      await wireDemoWorldToRealProfile(
        profileId: 'real-profile',
        journalDb: db,
        persistence: persistence,
      );

      verify(
        () => persistence.updateTask(
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
        ),
      ).called(201);
    });

    test('a missing seeded category (deleted by the user) is skipped without '
        'throwing', () async {
      final h = harness(seededCategory: null, tasks: [task('seeded-1')]);

      await wireDemoWorldToRealProfile(
        profileId: 'real-profile',
        journalDb: h.db,
        persistence: h.persistence,
      );

      verifyNever(() => h.persistence.upsertEntityDefinition(any()));
      verify(
        () => h.persistence.updateTask(
          journalEntityId: 'seeded-1',
          taskData: any(named: 'taskData'),
        ),
      ).called(1);
    });
  });
}
