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
    helper = PromptBuilderHelper(aiInputRepository: mockAiInputRepo);
  });

  tearDown(() async {
    await getIt.reset();
  });

  AiConfigPrompt makePrompt() => AiConfigPrompt(
        id: 'p1',
        name: 'Checklist Updates',
        systemMessage: 'sys',
        userMessage:
            'Task:```json\n{{task}}\n```\nSuppressed:```json\n{{suppressed_labels}}\n```\nAvailable:```json\n{{labels}}\n```',
        defaultModelId: 'm1',
        modelIds: const ['m1'],
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
          categoryId: 'engineering',
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
          aiSuppressedLabelIds: {'x'},
        ),
      );

  LabelDefinition makeLabel(String id, String name, {List<String>? cats}) =>
      LabelDefinition(
        id: id,
        name: name,
        color: '#000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        applicableCategoryIds: cats,
      );

  test(
      'injects suppressed labels JSON with id and name; excludes from available',
      () async {
    when(() => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')))
        .thenAnswer((_) async => '{}');

    // Available: x (suppressed), a (in category), g (global)
    when(() => mockDb.getAllLabelDefinitions()).thenAnswer(
      (_) async => [
        makeLabel('x', 'Xylophone', cats: ['engineering']),
        makeLabel('a', 'Alpha', cats: ['engineering']),
        makeLabel('g', 'Global'),
      ],
    );
    when(() => mockDb.getLabelUsageCounts())
        .thenAnswer((_) async => {'a': 10, 'g': 5, 'x': 99});
    when(() => mockDb.getConfigFlag(enableAiLabelAssignmentFlag))
        .thenAnswer((_) async => true);
    when(() => mockDb.getConfigFlag(includePrivateLabelsInPromptsFlag))
        .thenAnswer((_) async => false);

    final prompt = await helper.buildPromptWithData(
      promptConfig: makePrompt(),
      entity: makeTask(),
    );
    expect(prompt, isNotNull);

    // Suppressed block
    final sMatch = RegExp(r'Suppressed:```json\n(.*?)\n```', dotAll: true)
        .firstMatch(prompt!);
    expect(sMatch, isNotNull);
    final sList = (jsonDecode(sMatch!.group(1)!) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    expect(sList.map((e) => e['id']).toList(), ['x']);
    expect(sList.first['name'], 'Xylophone');

    // Available block excludes suppressed 'x'
    final aMatch = RegExp(r'Available:```json\n(.*?)\n```', dotAll: true)
        .firstMatch(prompt);
    expect(aMatch, isNotNull);
    final aList = (jsonDecode(aMatch!.group(1)!) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final ids = aList.map((m) => m['id'] as String).toList();
    expect(ids, isNot(contains('x')));
    expect(ids.toSet(), containsAll({'a', 'g'}));
  });
}
