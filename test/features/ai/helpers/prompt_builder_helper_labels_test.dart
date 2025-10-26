// ignore_for_file: unnecessary_lambdas, avoid_redundant_argument_values
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
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

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
    );
  });

  tearDown(() {
    getIt.reset();
  });

  AiConfigPrompt makePrompt() => AiConfigPrompt(
        id: 'p1',
        name: 'Checklist Updates',
        systemMessage: 'sys',
        userMessage:
            'Task:```json\n{{task}}\n```\nLabels:```json\n{{labels}}\n```',
        defaultModelId: 'm1',
        modelIds: const ['m1'],
        createdAt: DateTime.now(),
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

  LabelDefinition makeLabel({
    required String id,
    required String name,
    String? groupId,
    bool? private,
  }) =>
      LabelDefinition(
        id: id,
        name: name,
        color: '#000000',
        description: null,
        groupId: groupId,
        sortOrder: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: private,
      );

  test('injects labels JSON with usage ordering and privacy filter', () async {
    when(() => mockDb.getConfigFlag(enableAiLabelAssignmentFlag))
        .thenAnswer((_) async => true);
    when(() => mockDb.getConfigFlag(includePrivateLabelsInPromptsFlag))
        .thenAnswer((_) async => false);
    when(() => mockDb.getAllLabelDefinitions()).thenAnswer((_) async => [
          makeLabel(id: 'a', name: 'Alpha', private: false),
          makeLabel(id: 'b', name: 'Beta', private: true), // private excluded
          makeLabel(id: 'c', name: 'Charlie', private: false),
        ]);
    when(() => mockDb.getLabelUsageCounts())
        .thenAnswer((_) async => {'c': 10, 'a': 3});
    when(() => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')))
        .thenAnswer((_) async => '{}');

    final prompt = await helper.buildPromptWithData(
      promptConfig: makePrompt(),
      entity: makeTask(),
    );

    expect(prompt, isNotNull);
    final match =
        RegExp(r'Labels:```json\n(.*?)\n```', dotAll: true).firstMatch(prompt!);
    expect(match, isNotNull);
    final jsonPart = match!.group(1)!;
    final list = (jsonDecode(jsonPart) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    // Private excluded
    expect(list.length, 2);
    // Usage top first: c before a
    expect(list[0]['id'], 'c');
    expect(list[1]['id'], 'a');
  });
}
