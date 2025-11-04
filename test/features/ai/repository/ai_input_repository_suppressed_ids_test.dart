import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class FakeRef extends Fake implements Ref {}

class TestAiInputRepo extends AiInputRepository {
  TestAiInputRepo(super.ref);

  @override
  Future<AiInputTaskObject?> generate(String id) async {
    // Return minimal task JSON base to allow buildTaskDetailsJson to extend
    return AiInputTaskObject(
      title: 't',
      status: 'OPEN',
      creationDate: DateTime(2024),
      actionItems: const [],
      logEntries: const [],
      estimatedDuration: '00:00',
      timeSpent: '00:00',
      languageCode: 'en',
    );
  }
}

void main() {
  test('buildTaskDetailsJson includes aiSuppressedLabelIds', () async {
    final db = MockJournalDb();
    getIt.registerSingleton<JournalDb>(db);

    final task = Task(
      meta: Metadata(
        id: 't1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        labelIds: const ['a'],
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 's',
          createdAt: DateTime.now(),
          utcOffset: 0,
        ),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        statusHistory: const [],
        title: 't',
        aiSuppressedLabelIds: const {'x', 'y'},
      ),
    );
    when(() => db.journalEntityById('t1')).thenAnswer((_) async => task);
    when(db.getAllLabelDefinitions).thenAnswer((_) async => const []);

    final repo = TestAiInputRepo(FakeRef());
    final jsonStr = await repo.buildTaskDetailsJson(id: 't1');
    expect(jsonStr, isNotNull);
    final map = jsonDecode(jsonStr!) as Map<String, dynamic>;
    expect(map['aiSuppressedLabelIds'], containsAll(['x', 'y']));

    // Clean up registration
    await getIt.reset();
  });
}
