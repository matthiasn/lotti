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
    bool? private,
  }) =>
      LabelDefinition(
        id: id,
        name: name,
        color: '#000000',
        description: null,
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

  test('limits to 100 labels total (50 usage + 50 alpha)', () async {
    when(() => mockDb.getConfigFlag(enableAiLabelAssignmentFlag))
        .thenAnswer((_) async => true);
    when(() => mockDb.getConfigFlag(includePrivateLabelsInPromptsFlag))
        .thenAnswer((_) async => true);

    // Create 150 labels
    final labels = List.generate(
      150,
      (i) => makeLabel(id: 'id$i', name: 'Label $i'),
    );
    when(() => mockDb.getAllLabelDefinitions()).thenAnswer((_) async => labels);

    // Usage for 60 labels, ensure top 50 are chosen by usage
    final usage = <String, int>{
      for (var i = 0; i < 60; i++) 'id$i': 100 - i, // descending usage
    };
    when(() => mockDb.getLabelUsageCounts()).thenAnswer((_) async => usage);
    when(() => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')))
        .thenAnswer((_) async => '{}');

    final prompt = await helper.buildPromptWithData(
      promptConfig: makePrompt(),
      entity: makeTask(),
    );
    final match =
        RegExp(r'Labels:```json\n(.*?)\n```', dotAll: true).firstMatch(prompt!);
    final jsonPart = match!.group(1)!;
    final list = (jsonDecode(jsonPart) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    expect(list.length, 100);
  });

  test('escapes special characters in label names', () async {
    when(() => mockDb.getConfigFlag(enableAiLabelAssignmentFlag))
        .thenAnswer((_) async => true);
    when(() => mockDb.getConfigFlag(includePrivateLabelsInPromptsFlag))
        .thenAnswer((_) async => true);
    when(() => mockDb.getAllLabelDefinitions()).thenAnswer((_) async => [
          makeLabel(id: '1', name: 'Quote " inside'),
          makeLabel(id: '2', name: 'Bracket } ] combo'),
          makeLabel(id: '3', name: 'New\nLine'),
        ]);
    when(() => mockDb.getLabelUsageCounts())
        .thenAnswer((_) async => <String, int>{});
    when(() => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')))
        .thenAnswer((_) async => '{}');

    final prompt = await helper.buildPromptWithData(
      promptConfig: makePrompt(),
      entity: makeTask(),
    );
    final match =
        RegExp(r'Labels:```json\n(.*?)\n```', dotAll: true).firstMatch(prompt!);
    final jsonPart = match!.group(1)!;
    expect(() => jsonDecode(jsonPart), returnsNormally);
  });

  test('returns empty list when feature disabled', () async {
    when(() => mockDb.getConfigFlag(enableAiLabelAssignmentFlag))
        .thenAnswer((_) async => false);
    when(() => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')))
        .thenAnswer((_) async => '{}');

    final prompt = await helper.buildPromptWithData(
      promptConfig: makePrompt(),
      entity: makeTask(),
    );
    final match =
        RegExp(r'Labels:```json\n(.*?)\n```', dotAll: true).firstMatch(prompt!);
    final jsonPart = match!.group(1)!;
    final list = jsonDecode(jsonPart) as List<dynamic>;
    expect(list, isEmpty);
  });
}
