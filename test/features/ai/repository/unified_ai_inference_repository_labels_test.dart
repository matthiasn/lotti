// ignore_for_file: avoid_redundant_argument_values
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockLabelsRepository extends Mock implements LabelsRepository {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockJournalRepository2 extends Mock implements JournalRepository {}

class MockChecklistRepository2 extends Mock implements ChecklistRepository {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  late ProviderContainer container;
  late MockJournalDb mockDb;
  late MockLabelsRepository mockLabelsRepo;
  late MockAiInputRepository mockAiInputRepo;
  late MockLoggingService mockLogging;

  setUpAll(() {
    registerFallbackValue(const ChatCompletionMessageToolCall(
      id: 't',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(name: 'f', arguments: '{}'),
    ));
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockLabelsRepo = MockLabelsRepository();
    mockAiInputRepo = MockAiInputRepository();
    mockLogging = MockLoggingService();

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<LoggingService>(mockLogging)
      ..registerSingleton<LabelAssignmentRateLimiter>(
          LabelAssignmentRateLimiter());

    container = ProviderContainer(overrides: [
      labelsRepositoryProvider.overrideWithValue(mockLabelsRepo),
      aiInputRepositoryProvider.overrideWithValue(mockAiInputRepo),
      journalRepositoryProvider.overrideWithValue(MockJournalRepository2()),
      checklistRepositoryProvider.overrideWithValue(MockChecklistRepository2()),
    ]);
  });

  tearDown(() {
    container.dispose();
    getIt.reset();
  });

  Task makeTask({List<String>? labels}) => Task(
        meta: Metadata(
          id: 'task-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          categoryId: 'cat',
          labelIds: labels,
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

  LabelDefinition makeLabel(String id,
          {String? groupId, bool deleted = false}) =>
      LabelDefinition(
        id: id,
        name: id,
        color: '#000000',
        description: null,
        sortOrder: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        deletedAt: deleted ? DateTime.now() : null,
      );

  ChatCompletionMessageToolCall makeCall(List<String> ids) =>
      ChatCompletionMessageToolCall(
        id: 'tool-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'assign_task_labels',
          arguments: jsonEncode({'labelIds': ids}),
        ),
      );

  test('assign_task_labels assigns valid labels and filters invalid', () async {
    // Existing labels on the task (group is ignored for exclusivity)
    final task = makeTask(labels: const ['l1']);
    when(() => mockDb.getLabelDefinitionById('l1'))
        .thenAnswer((_) async => makeLabel('l1', groupId: 'g1'));

    // Proposed: l2 (same group g1, allowed), l3 (g2, allowed), lX (deleted)
    when(() => mockDb.getLabelDefinitionById('l2'))
        .thenAnswer((_) async => makeLabel('l2', groupId: 'g1'));
    when(() => mockDb.getLabelDefinitionById('l3'))
        .thenAnswer((_) async => makeLabel('l3', groupId: 'g2'));
    when(() => mockDb.getLabelDefinitionById('lX'))
        .thenAnswer((_) async => makeLabel('lX', deleted: true));

    when(() => mockDb.getConfigFlag(aiLabelAssignmentShadowFlag))
        .thenAnswer((_) async => false);

    final repo = container.read(unifiedAiInferenceRepositoryProvider);
    final calls = [
      makeCall(['l2', 'l3', 'lX'])
    ];

    await repo.processToolCalls(toolCalls: calls, task: task);

    // l2 and l3 should be assigned; lX filtered as invalid
    verify(() => mockLabelsRepo.addLabels(
          journalEntityId: task.id,
          addedLabelIds: any(named: 'addedLabelIds'),
        )).called(1);
  });
}
