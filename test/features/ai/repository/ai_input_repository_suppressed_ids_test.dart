import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

class MockJournalDb extends Mock implements JournalDb {}

class TestAiInputRepo extends AiInputRepository {
  TestAiInputRepo(super.ref, {required super.projectRepository})
    : super(taskSummaryResolver: TaskSummaryResolver(null));

  @override
  Future<AiInputTaskObject?> generate(String id) async {
    // Return minimal task JSON base to allow buildTaskDetailsJson to extend
    return AiInputTaskObject(
      title: 't',
      status: 'OPEN',
      priority: 'P2',
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
    final mockProjectRepository = MockProjectRepository();
    getIt.registerSingleton<JournalDb>(db);
    final container = ProviderContainer();
    addTearDown(() {
      container.dispose();
      getIt.reset();
    });

    final testDate = DateTime(2024, 3, 15, 10, 30);
    final task = Task(
      meta: Metadata(
        id: 't1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        labelIds: const ['a'],
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 's',
          createdAt: testDate,
          utcOffset: 0,
        ),
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: const [],
        title: 't',
        aiSuppressedLabelIds: const {'x', 'y'},
      ),
    );
    when(() => db.journalEntityById('t1')).thenAnswer((_) async => task);
    when(db.getAllLabelDefinitions).thenAnswer((_) async => const []);

    final repo = TestAiInputRepo(
      container.read(testRefProvider),
      projectRepository: mockProjectRepository,
    );
    final jsonStr = await repo.buildTaskDetailsJson(id: 't1');
    expect(jsonStr, isNotNull);
    final map = jsonDecode(jsonStr!) as Map<String, dynamic>;
    expect(map['aiSuppressedLabelIds'], containsAll(['x', 'y']));

    // Clean up registration
    await getIt.reset();
  });
}
