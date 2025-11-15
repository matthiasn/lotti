// ignore_for_file: avoid_redundant_argument_values
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
import 'package:lotti/utils/consts.dart';
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

  tearDown(getIt.reset);

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

  test('include_private true includes all labels when enabled', () async {
    when(() => mockDb.getConfigFlag(enableAiLabelAssignmentFlag))
        .thenAnswer((_) async => true);
    when(() => mockDb.getConfigFlag(includePrivateLabelsInPromptsFlag))
        .thenAnswer((_) async => true);
    when(() => mockDb.getAllLabelDefinitions()).thenAnswer((_) async => [
          makeLabel(id: 'a', name: 'Alpha', private: false),
          makeLabel(id: 'b', name: 'Beta', private: true),
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
    final list = jsonDecode(match!.group(1)!) as List<dynamic>;
    expect(list.length, 2);
  });

  test('all-private labels filtered when include_private=false', () async {
    when(() => mockDb.getConfigFlag(enableAiLabelAssignmentFlag))
        .thenAnswer((_) async => true);
    when(() => mockDb.getConfigFlag(includePrivateLabelsInPromptsFlag))
        .thenAnswer((_) async => false);
    when(() => mockDb.getAllLabelDefinitions()).thenAnswer((_) async => [
          makeLabel(id: 'b', name: 'Beta', private: true),
          makeLabel(id: 'c', name: 'Charlie', private: true),
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
    final list = jsonDecode(match!.group(1)!) as List<dynamic>;
    expect(list, isEmpty);
  });

  test('handles 600+ labels and caps to 100', () async {
    when(() => mockDb.getConfigFlag(enableAiLabelAssignmentFlag))
        .thenAnswer((_) async => true);
    when(() => mockDb.getConfigFlag(includePrivateLabelsInPromptsFlag))
        .thenAnswer((_) async => true);
    final labels = List.generate(
      620,
      (i) => makeLabel(id: 'id$i', name: 'Label $i'),
    );
    when(() => mockDb.getAllLabelDefinitions()).thenAnswer((_) async => labels);
    when(() => mockDb.getLabelUsageCounts()).thenAnswer(
        (_) async => {for (var i = 0; i < 100; i++) 'id$i': 100 - i});
    when(() => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')))
        .thenAnswer((_) async => '{}');

    final prompt = await helper.buildPromptWithData(
      promptConfig: makePrompt(),
      entity: makeTask(),
    );
    final match =
        RegExp(r'Labels:```json\n(.*?)\n```', dotAll: true).firstMatch(prompt!);
    final list = jsonDecode(match!.group(1)!) as List<dynamic>;
    expect(list.length, 100);
  });
}
