import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

void main() {
  late MockJournalDb mockDb;
  late MockAiInputRepository mockAiInputRepo;
  late PromptBuilderHelper helper;

  setUp(() {
    mockDb = MockJournalDb();
    mockAiInputRepo = MockAiInputRepository();
    getIt.registerSingleton<JournalDb>(mockDb);
    helper = PromptBuilderHelper(
      aiInputRepository: mockAiInputRepo,
      checklistRepository: MockChecklistRepository(),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  AiConfigPrompt makePrompt() => AiConfigPrompt(
        id: 'p1',
        name: 'Checklist Updates',
        systemMessage: 'sys',
        userMessage:
            'Task:```json\n{{task}}\n```\nAssigned:```json\n{{assigned_labels}}\n```',
        defaultModelId: 'm1',
        modelIds: ['m1'],
        createdAt: DateTime(2024),
        useReasoning: false,
        requiredInputData: const [InputDataType.task],
        aiResponseType: AiResponseType.checklistUpdates,
      );

  Task makeTask() => Task(
        meta: Metadata(
          id: 't1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          categoryId: 'cat',
          labelIds: const ['a', 'b'],
        ),
        data: TaskData(
          title: 'Task',
          status: TaskStatus.open(
            id: 's',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          statusHistory: const [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

  LabelDefinition makeLabel(String id, String name) => LabelDefinition(
        id: id,
        name: name,
        color: '#000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
      );

  test('injects assigned labels JSON with id and name', () async {
    when(() => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')))
        .thenAnswer((_) async => '{}');
    when(() => mockDb.getAllLabelDefinitions()).thenAnswer(
      (_) async => [makeLabel('a', 'Alpha'), makeLabel('b', 'Beta')],
    );

    final prompt = await helper.buildPromptWithData(
      promptConfig: makePrompt(),
      entity: makeTask(),
    );
    expect(prompt, isNotNull);
    final match = RegExp(r'Assigned:```json\n(.*?)\n```', dotAll: true)
        .firstMatch(prompt!);
    expect(match, isNotNull);
    final jsonPart = match!.group(1)!;
    final list = (jsonDecode(jsonPart) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    expect(list.length, 2);
    expect(list[0]['id'], anyOf('a', 'b'));
    final names = list.map((m) => m['name']).toSet();
    expect(names, containsAll(['Alpha', 'Beta']));
  });
}
