import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart' show toDbEntity;
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/functions/label_functions.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import 'unified_ai_inference_repository_test_helpers.dart';

final harness = UnifiedAiInferenceRepositoryTestHarness();

UnifiedAiInferenceRepository? get repository => harness.repository;
set repository(UnifiedAiInferenceRepository? value) =>
    harness.repository = value;
ProviderContainer get container => harness.container;
MockAiConfigRepository get mockAiConfigRepo => harness.mockAiConfigRepo;
MockAiInputRepository get mockAiInputRepo => harness.mockAiInputRepo;
MockCloudInferenceRepository get mockCloudInferenceRepo =>
    harness.mockCloudInferenceRepo;
MockJournalRepository get mockJournalRepo => harness.mockJournalRepo;
MockChecklistRepository get mockChecklistRepo => harness.mockChecklistRepo;
MockAutoChecklistService get mockAutoChecklistService =>
    harness.mockAutoChecklistService;
MockLoggingService get mockLoggingService => harness.mockLoggingService;
MockJournalDb get mockJournalDb => harness.mockJournalDb;
MockDirectory get mockDirectory => harness.mockDirectory;
MockCategoryRepository get mockCategoryRepo => harness.mockCategoryRepo;
MockPromptCapabilityFilter get mockPromptCapabilityFilter =>
    harness.mockPromptCapabilityFilter;
MockLabelsRepository get mockLabelsRepository => harness.mockLabelsRepository;
TestChecklistCompletionService get testChecklistCompletionService =>
    harness.testChecklistCompletionService;
Directory? get baseTempDir => harness.baseTempDir;
List<Directory> get overrideTempDirs => harness.overrideTempDirs;

void main() {
  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);
  tearDownAll(harness.tearDownAll);

  group(
    'processToolCalls – language detection (setTaskLanguage) branches (lines 1120-1178)',
    () {
      Task makeTask({String? languageCode, String id = 'task-lang-test'}) {
        return Task(
          meta: createMetadata(id: id),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            title: 'Language Test Task',
            statusHistory: const [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            languageCode: languageCode,
          ),
        );
      }

      ChatCompletionMessageToolCall langCall(String json) {
        return createMockMessageToolCall(
          id: 'lang-call-1',
          functionName: TaskFunctions.setTaskLanguage,
          arguments: json,
        );
      }

      test(
        'sets language when task has no language yet (lines 1149-1162)',
        () async {
          final task = makeTask();
          when(
            () => mockJournalRepo.getJournalEntityById(task.id),
          ).thenAnswer((_) async => task);
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final result = await repository!.processToolCalls(
            toolCalls: [
              langCall(
                '{"languageCode":"en","confidence":"high","reason":"Detected English"}',
              ),
            ],
            task: task,
          );

          expect(result, isTrue); // languageWasSet
          verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
        },
      );

      test(
        'skips language update when task already has a language set (lines 1171-1174)',
        () async {
          final task = makeTask(languageCode: 'de');
          when(
            () => mockJournalRepo.getJournalEntityById(task.id),
          ).thenAnswer((_) async => task);

          final result = await repository!.processToolCalls(
            toolCalls: [
              langCall(
                '{"languageCode":"en","confidence":"high","reason":"Detected English"}',
              ),
            ],
            task: task,
          );

          expect(result, isFalse); // languageWasSet stays false
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        },
      );

      test(
        'skips language update when freshEntity is not a Task (lines 1138-1143)',
        () async {
          final task = makeTask();
          // Return a non-Task entity to hit line 1138
          when(
            () => mockJournalRepo.getJournalEntityById(task.id),
          ).thenAnswer((_) async => JournalEntry(meta: createMetadata()));

          final result = await repository!.processToolCalls(
            toolCalls: [
              langCall(
                '{"languageCode":"fr","confidence":"medium","reason":"French"}',
              ),
            ],
            task: task,
          );

          expect(result, isFalse);
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        },
      );

      test(
        'handles updateJournalEntity failure when setting language (lines 1164-1168)',
        () async {
          final task = makeTask();
          when(
            () => mockJournalRepo.getJournalEntityById(task.id),
          ).thenAnswer((_) async => task);
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenThrow(Exception('DB write error'));

          // Should not throw despite update failure
          final result = await repository!.processToolCalls(
            toolCalls: [
              langCall(
                '{"languageCode":"es","confidence":"low","reason":"Maybe Spanish"}',
              ),
            ],
            task: task,
          );

          // languageWasSet should be false because update threw
          expect(result, isFalse);
        },
      );

      test(
        'handles malformed setTaskLanguage JSON (lines 1176-1181)',
        () async {
          final task = makeTask();

          // Should not throw — error is caught internally
          final result = await repository!.processToolCalls(
            toolCalls: [
              createMockMessageToolCall(
                id: 'bad-lang-call',
                functionName: TaskFunctions.setTaskLanguage,
                arguments: 'not-valid-json',
              ),
            ],
            task: task,
          );

          expect(result, isFalse);
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        },
      );
    },
  );

  group(
    'processToolCalls – language triggers auto-rerun when response is empty (lines 619-634)',
    () {
      test(
        're-runs inference when language is detected and response is empty',
        () async {
          final taskEntity = Task(
            meta: createMetadata(),
            data: TaskData(
              status: TaskStatus.inProgress(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15, 10, 30),
                utcOffset: 0,
              ),
              title: 'Language Detection Test',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
          );

          final promptConfig = createPrompt(
            id: 'prompt-1',
            name: 'Task Summary',
            requiredInputData: [InputDataType.task],
          );

          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'gpt-4',
          );

          final provider = createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.genericOpenAi,
          );

          // First call: returns only a language tool call with empty text
          // Second call (re-run): returns actual text
          var callCount = 0;
          when(
            () => mockAiInputRepo.getEntity(taskEntity.id),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);
          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => provider);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
          ).thenAnswer((_) async => '{"task":"details"}');

          when(
            () => mockJournalRepo.getJournalEntityById(taskEntity.id),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          when(
            () => mockCloudInferenceRepo.generate(
              any(),
              impactCollector: any(named: 'impactCollector'),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
              geminiThinkingMode: any(named: 'geminiThinkingMode'),
            ),
          ).thenAnswer((_) {
            callCount++;
            if (callCount == 1) {
              // First run: language tool call, no text
              return Stream.fromIterable([
                createStreamChunkWithToolCalls([
                  createMockToolCall(
                    index: 0,
                    id: 'lang-1',
                    functionName: TaskFunctions.setTaskLanguage,
                    arguments:
                        '{"languageCode":"de","confidence":"high","reason":"German text"}',
                  ),
                ]),
              ]);
            } else {
              // Second run (re-run): returns the actual summary
              return createMockTextStream(['Task summary in German']);
            }
          });

          stubCreateAiResponseEntry(mockAiInputRepo);

          final statusChanges = <InferenceStatus>[];
          await repository!.runInference(
            entityId: taskEntity.id,
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: statusChanges.add,
          );

          // Both runs completed → language was set and rerun happened
          expect(callCount, 2);
          expect(statusChanges, contains(InferenceStatus.idle));
        },
      );

      test(
        'skips re-run when language is detected but response is non-empty',
        () async {
          final taskEntity = Task(
            meta: createMetadata(),
            data: TaskData(
              status: TaskStatus.inProgress(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15, 10, 30),
                utcOffset: 0,
              ),
              title: 'Language Detection Test',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
          );

          final promptConfig = createPrompt(
            id: 'prompt-1',
            name: 'Task Summary',
            requiredInputData: [InputDataType.task],
          );

          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'gpt-4',
          );

          final provider = createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.genericOpenAi,
          );

          var callCount = 0;
          when(
            () => mockAiInputRepo.getEntity(taskEntity.id),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);
          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => provider);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
          ).thenAnswer((_) async => '{"task":"details"}');

          when(
            () => mockJournalRepo.getJournalEntityById(taskEntity.id),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          // Single run: BOTH a language tool call AND text content, so the
          // `response.trim().isEmpty` half of the re-run gate is false and
          // no second inference must be started.
          when(
            () => mockCloudInferenceRepo.generate(
              any(),
              impactCollector: any(named: 'impactCollector'),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
              geminiThinkingMode: any(named: 'geminiThinkingMode'),
            ),
          ).thenAnswer((_) {
            callCount++;
            return Stream.fromIterable([
              createStreamChunkWithToolCalls([
                createMockToolCall(
                  index: 0,
                  id: 'lang-1',
                  functionName: TaskFunctions.setTaskLanguage,
                  arguments:
                      '{"languageCode":"de","confidence":"high","reason":"German text"}',
                ),
              ]),
              CreateChatCompletionStreamResponse(
                id: 'response-text',
                choices: const [
                  ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      content: 'Zusammenfassung der Aufgabe',
                    ),
                    finishReason: ChatCompletionFinishReason.stop,
                    index: 0,
                  ),
                ],
                object: 'chat.completion.chunk',
                created: DateTime(2024, 3, 15).millisecondsSinceEpoch ~/ 1000,
              ),
            ]);
          });

          stubCreateAiResponseEntry(mockAiInputRepo);

          final statusChanges = <InferenceStatus>[];
          await repository!.runInference(
            entityId: taskEntity.id,
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: statusChanges.add,
          );

          // Language was set, but the non-empty response suppresses the
          // automatic re-run: exactly one inference call.
          expect(callCount, 1);
          verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
          expect(statusChanges, contains(InferenceStatus.idle));
        },
      );
    },
  );

  group('processToolCalls – suggestChecklistCompletion edge cases', () {
    Task makeTask2({String id = 'task-1'}) {
      return Task(
        meta: createMetadata(id: id),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          title: 'Edge Case Task',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          checklistIds: const ['checklist-1'],
        ),
      );
    }

    test(
      'skips when arguments contain no valid JSON object (line 906-911 — empty jsonObjects)',
      () async {
        final task = makeTask2();

        final result = await repository!.processToolCalls(
          toolCalls: [
            createMockMessageToolCall(
              id: 'bad-call',
              functionName:
                  ChecklistCompletionFunctions.suggestChecklistCompletion,
              // No {} braces → no JSON objects found
              arguments: 'no-braces-here',
            ),
          ],
          task: task,
        );

        expect(result, isFalse);
        expect(testChecklistCompletionService.capturedSuggestions, isEmpty);
      },
    );

    test(
      'uses orElse confidence fallback for unknown confidence value (line 932)',
      () async {
        final task = makeTask2();

        when(
          () => mockJournalRepo.getJournalEntityById(any()),
        ).thenAnswer((_) async => null);

        final result = await repository!.processToolCalls(
          toolCalls: [
            createMockMessageToolCall(
              id: 'unknown-confidence',
              functionName:
                  ChecklistCompletionFunctions.suggestChecklistCompletion,
              // 'extreme' is not a valid confidence level → orElse fallback
              arguments:
                  '{"checklistItemId":"item-x","reason":"Test","confidence":"extreme"}',
            ),
          ],
          task: task,
        );

        expect(result, isFalse);
        expect(testChecklistCompletionService.capturedSuggestions.length, 1);
        expect(
          testChecklistCompletionService.capturedSuggestions.first.confidence,
          ChecklistCompletionConfidence.low,
        );
      },
    );

    test(
      'logs and skips invalid JSON within arguments (lines 942-946)',
      () async {
        final task = makeTask2();

        // A valid outer JSON structure is needed so jsonObjects is non-empty, but
        // the inner content has a broken type cast.
        final result = await repository!.processToolCalls(
          toolCalls: [
            createMockMessageToolCall(
              id: 'bad-inner',
              functionName:
                  ChecklistCompletionFunctions.suggestChecklistCompletion,
              // checklistItemId is missing → cast to String throws
              arguments: '{"reason":"test","confidence":"high"}',
            ),
          ],
          task: task,
        );

        expect(result, isFalse);
        // No suggestion should have been added because parsing threw
        expect(testChecklistCompletionService.capturedSuggestions, isEmpty);
      },
    );
  });

  group('processToolCalls – add_multiple_checklist_items edge cases', () {
    Task makeTaskNoChecklists() {
      return Task(
        meta: createMetadata(id: 'task-no-cl'),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          title: 'No Checklist Task',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );
    }

    test('skips when items field is not a List (line 958-963)', () async {
      final task = makeTaskNoChecklists();

      final result = await repository!.processToolCalls(
        toolCalls: [
          createMockMessageToolCall(
            id: 'bad-items',
            functionName:
                ChecklistCompletionFunctions.addMultipleChecklistItems,
            arguments: '{"items":"not-a-list"}',
          ),
        ],
        task: task,
      );

      expect(result, isFalse);
      verifyNever(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: any(named: 'taskId'),
          suggestions: any(named: 'suggestions'),
        ),
      );
    });

    test('skips when batch size exceeds maximum (lines 968-973)', () async {
      // Build an array with 21 items (maxBatchSize is 20)
      final items = List.generate(
        21,
        (i) => '{"title":"Item $i","isChecked":false}',
      ).join(',');

      final task = makeTaskNoChecklists();

      final result = await repository!.processToolCalls(
        toolCalls: [
          createMockMessageToolCall(
            id: 'too-many',
            functionName:
                ChecklistCompletionFunctions.addMultipleChecklistItems,
            arguments: '{"items":[$items]}',
          ),
        ],
        task: task,
      );

      expect(result, isFalse);
      verifyNever(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: any(named: 'taskId'),
          suggestions: any(named: 'suggestions'),
        ),
      );
    });

    test(
      'breaks out of loop when task is not found after checklist creation (lines 1031-1036)',
      () async {
        // Task starts with no checklist IDs
        final task = Task(
          meta: createMetadata(id: 'task-disappears'),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            title: 'Disappearing Task',
            statusHistory: const [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            checklistIds: const [],
          ),
        );

        // autoCreateChecklist succeeds
        when(
          () => mockAutoChecklistService.autoCreateChecklist(
            taskId: task.id,
            suggestions: any(named: 'suggestions'),
            title: any(named: 'title'),
          ),
        ).thenAnswer(
          (_) async => (
            success: true,
            checklistId: 'new-cl',
            createdItems: <({String id, String title, bool isChecked})>[],
            error: null,
          ),
        );

        // But the journalDb can no longer find the task after creation
        // (simulates concurrent deletion)
        when(
          () => mockJournalDb.journalEntityById(task.id),
        ).thenAnswer((_) async => null);

        final result = await repository!.processToolCalls(
          toolCalls: [
            createMockMessageToolCall(
              id: 'add-cl',
              functionName:
                  ChecklistCompletionFunctions.addMultipleChecklistItems,
              arguments:
                  '{"items":[{"title":"Do something","isChecked":false}]}',
            ),
          ],
          task: task,
        );

        expect(result, isFalse);
      },
    );

    test(
      'logs error when autoCreateChecklist fails (lines 1039-1043)',
      () async {
        final task = Task(
          meta: createMetadata(id: 'task-cl-fail'),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            title: 'Failing Checklist Task',
            statusHistory: const [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            checklistIds: const [],
          ),
        );

        when(
          () => mockAutoChecklistService.autoCreateChecklist(
            taskId: task.id,
            suggestions: any(named: 'suggestions'),
            title: any(named: 'title'),
          ),
        ).thenAnswer(
          (_) async => (
            success: false,
            checklistId: null,
            createdItems: null,
            error: 'Creation failed',
          ),
        );

        final result = await repository!.processToolCalls(
          toolCalls: [
            createMockMessageToolCall(
              id: 'add-fail',
              functionName:
                  ChecklistCompletionFunctions.addMultipleChecklistItems,
              arguments: '{"items":[{"title":"Item 1","isChecked":false}]}',
            ),
          ],
          task: task,
        );

        expect(result, isFalse);
      },
    );
  });

  group(
    'processToolCalls – update_checklist_items failure path (lines 1093-1116)',
    () {
      test(
        'logs when processFunctionCall returns failure (lines 1093-1097)',
        () async {
          final task = Task(
            meta: createMetadata(id: 'task-update-fail'),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              title: 'Update Fail Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              checklistIds: const ['checklist-1'],
            ),
          );

          // Invalid JSON structure → processFunctionCall returns failure
          final result = await repository!.processToolCalls(
            toolCalls: [
              createMockMessageToolCall(
                id: 'bad-update',
                functionName: ChecklistCompletionFunctions.updateChecklistItems,
                arguments: '{"items": "not-array"}',
              ),
            ],
            task: task,
          );

          expect(result, isFalse);
        },
      );

      test(
        'catches exception thrown during update_checklist_items (lines 1110-1115)',
        () async {
          final task = Task(
            meta: createMetadata(id: 'task-update-throw'),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              title: 'Update Throw Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              checklistIds: const ['checklist-1'],
            ),
          );

          // DB throws during entriesForIds lookup inside executeUpdates
          final mockSelectable = MockSelectableSimple<JournalDbEntity>();
          when(mockSelectable.get).thenThrow(Exception('DB exploded'));
          when(
            () => mockJournalDb.entriesForIds(any()),
          ).thenReturn(mockSelectable);

          // Should not rethrow; caught internally
          final result = await repository!.processToolCalls(
            toolCalls: [
              createMockMessageToolCall(
                id: 'throw-update',
                functionName: ChecklistCompletionFunctions.updateChecklistItems,
                arguments: '{"items":[{"id":"item-1","isChecked":true}]}',
              ),
            ],
            task: task,
          );

          expect(result, isFalse);
        },
      );
    },
  );

  group(
    'processToolCalls – assign_task_labels empty requested set (line 1193)',
    () {
      test(
        'skips when parseLabelCallArgs returns empty selected IDs',
        () async {
          final task = Task(
            meta: createMetadata(id: 'task-empty-labels'),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              title: 'Label Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
            ),
          );

          // Empty labelIds → parseLabelCallArgs returns no selectedIds
          final result = await repository!.processToolCalls(
            toolCalls: [
              createMockMessageToolCall(
                id: 'empty-labels',
                functionName: LabelFunctions.assignTaskLabels,
                arguments: '{"labelIds":[]}',
              ),
            ],
            task: task,
          );

          expect(result, isFalse);
          verifyNever(
            () => mockLabelsRepository.addLabels(
              journalEntityId: any(named: 'journalEntityId'),
              addedLabelIds: any(named: 'addedLabelIds'),
            ),
          );
        },
      );
    },
  );

  group(
    'processToolCalls – assign_task_labels successful path (lines 1246-1247)',
    () {
      test(
        'calls processAssignment and logs result when labels are valid',
        () async {
          final task = Task(
            meta: createMetadata(id: 'task-valid-labels'),
            data: TaskData(
              status: TaskStatus.open(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              title: 'Label Assignment Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
            ),
          );

          // LabelAssignmentProcessor calls getIt<DomainLogger>() in its
          // constructor — register a mock so the constructor doesn't throw.
          final mockDomainLogger = MockDomainLogger();
          // Registered in this test's GetIt scope; tearDown pops the scope.
          getIt.registerSingleton<DomainLogger>(mockDomainLogger);

          // Build real LabelDefinition fixtures — global (no applicableCategoryIds)
          // and not deleted (no deletedAt) so the validator marks them valid.
          LabelDefinition makeLabelDef(String id) => LabelDefinition(
            id: id,
            name: id,
            color: '#000000',
            vectorClock: null,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
          );
          final labelA = makeLabelDef('label-A');
          final labelB = makeLabelDef('label-B');

          // LabelAssignmentProcessor uses getIt<JournalDb>() directly:
          // stub journalEntityById so task suppression fetch works.
          when(
            () => mockJournalDb.journalEntityById(task.id),
          ).thenAnswer((_) async => task);
          // Return matching LabelDefinition for each requested ID so the
          // LabelValidator places them in the "valid" bucket.
          when(
            () => mockJournalDb.getLabelDefinitionById('label-A'),
          ).thenAnswer((_) async => labelA);
          when(
            () => mockJournalDb.getLabelDefinitionById('label-B'),
          ).thenAnswer((_) async => labelB);
          // Stub addLabels so the repository call in the success path completes.
          when(
            () => mockLabelsRepository.addLabels(
              journalEntityId: task.id,
              addedLabelIds: any(named: 'addedLabelIds'),
            ),
          ).thenAnswer((_) async => true);

          final result = await repository!.processToolCalls(
            toolCalls: [
              createMockMessageToolCall(
                id: 'valid-labels',
                functionName: LabelFunctions.assignTaskLabels,
                arguments: '{"labelIds":["label-A","label-B"]}',
              ),
            ],
            task: task,
          );

          // processToolCalls returns languageWasSet; label assignment doesn't
          // flip that flag.
          expect(result, isFalse);
          // The success path (lines 1246-1247) must have called addLabels with
          // both validated label IDs.
          final captured = verify(
            () => mockLabelsRepository.addLabels(
              journalEntityId: task.id,
              addedLabelIds: captureAny(named: 'addedLabelIds'),
            ),
          ).captured;
          final assignedIds = captured.single as List<String>;
          expect(assignedIds, containsAll(['label-A', 'label-B']));
          expect(assignedIds, hasLength(2));
        },
      );
    },
  );

  group('processToolCalls – unknown tool call (lines 1261-1262)', () {
    test('logs and skips unknown function name', () async {
      final task = Task(
        meta: createMetadata(id: 'task-unknown-tool'),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          title: 'Unknown Tool Task',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );

      // Should not throw
      final result = await repository!.processToolCalls(
        toolCalls: [
          createMockMessageToolCall(
            id: 'unknown-tool',
            functionName: 'completely_unknown_function',
            arguments: '{}',
          ),
        ],
        task: task,
      );

      expect(result, isFalse);
    });
  });

  group('processToolCalls – assign_task_labels suppressed-only short-circuit '
      '(lines 1213-1233)', () {
    test(
      'skips processAssignment when every requested label is suppressed',
      () async {
        // LabelAssignmentProcessor's constructor resolves getIt<DomainLogger>
        // even though processAssignment is never reached on this path.
        final mockDomainLogger = MockDomainLogger();
        // Registered in this test's GetIt scope; tearDown pops the scope.
        getIt.registerSingleton<DomainLogger>(mockDomainLogger);

        // Both requested labels (X, Y) are on the task's suppression set, so
        // `proposed` becomes empty while `requested` is non-empty, taking the
        // suppressed-only short-circuit (builds the skipped list + noop result
        // and logs it, then continues without assigning).
        final task = Task(
          meta: createMetadata(id: 'task-suppressed-only'),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            title: 'Suppressed Labels Task',
            statusHistory: const [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            aiSuppressedLabelIds: const {'X', 'Y'},
          ),
        );

        final result = await repository!.processToolCalls(
          toolCalls: [
            createMockMessageToolCall(
              id: 'suppressed-labels',
              functionName: LabelFunctions.assignTaskLabels,
              arguments: '{"labelIds":["X","Y"]}',
            ),
          ],
          task: task,
        );

        // languageWasSet is never flipped by label assignment.
        expect(result, isFalse);
        // The short-circuit must NOT persist anything: processAssignment is
        // skipped, so addLabels is never invoked.
        verifyNever(
          () => mockLabelsRepository.addLabels(
            journalEntityId: any(named: 'journalEntityId'),
            addedLabelIds: any(named: 'addedLabelIds'),
          ),
        );
      },
    );
  });

  group('processToolCalls – update_checklist_items refreshes task on success '
      '(line 1085 onTaskUpdated)', () {
    test('invokes onTaskUpdated after a successful item update', () async {
      final task = Task(
        meta: createMetadata(id: 'task-update-success'),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          title: 'Update Success Task',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          checklistIds: const ['checklist-1'],
        ),
      );

      // A real checklist item that belongs to the task's checklist and is
      // currently unchecked — flipping isChecked is a genuine change.
      final checklistItem = ChecklistItem(
        meta: createMetadata(id: 'item-1'),
        data: const ChecklistItemData(
          title: 'Buy milk',
          isChecked: false,
          linkedChecklists: ['checklist-1'],
          // Agent-owned so the sovereignty guard allows the override.
          checkedBy: ChangeSource.agent,
        ),
      );

      // executeUpdates fetches items via entriesForIds(...).get() and
      // converts each row back through fromDbEntity, so we round-trip the
      // real ChecklistItem through toDbEntity.
      final mockSelectable = MockSelectableSimple<JournalDbEntity>();
      when(
        mockSelectable.get,
      ).thenAnswer((_) async => [toDbEntity(checklistItem)]);
      when(
        () => mockJournalDb.entriesForIds(['item-1']),
      ).thenReturn(mockSelectable);

      // The actual write succeeds, driving successCount > 0.
      when(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: 'item-1',
          data: any(named: 'data'),
          taskId: task.id,
        ),
      ).thenAnswer((_) async => true);

      // After a successful update the handler re-fetches the task; returning
      // a Task triggers the onTaskUpdated callback (line 1085) which swaps
      // currentTask for the refreshed instance.
      final refreshedTask = task.copyWith(
        data: task.data.copyWith(title: 'Refreshed Task Title'),
      );
      when(
        () => mockJournalDb.journalEntityById(task.id),
      ).thenAnswer((_) async => refreshedTask);

      final result = await repository!.processToolCalls(
        toolCalls: [
          createMockMessageToolCall(
            id: 'update-success',
            functionName: ChecklistCompletionFunctions.updateChecklistItems,
            arguments:
                '{"items":[{"id":"item-1","isChecked":true,'
                '"reason":"Confirmed done in the latest standup notes"}]}',
          ),
        ],
        task: task,
      );

      // update_checklist_items never sets language.
      expect(result, isFalse);
      // The write must have happened with the flipped, agent-stamped state.
      verify(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: 'item-1',
          data: any(
            named: 'data',
            that: isA<ChecklistItemData>()
                .having((d) => d.isChecked, 'isChecked', true)
                .having((d) => d.checkedBy, 'checkedBy', ChangeSource.agent),
          ),
          taskId: task.id,
        ),
      ).called(1);
      // The success branch re-fetched the task to refresh currentTask,
      // proving the onTaskUpdated callback path executed.
      verify(() => mockJournalDb.journalEntityById(task.id)).called(1);
    });
  });
}
