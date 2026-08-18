// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';
import '../test_utils.dart';
import 'unified_ai_inference_repository_test_helpers.dart';

final harness = UnifiedAiInferenceRepositoryTestHarness();

UnifiedAiInferenceRepository get repository => harness.repository;
MockAiConfigRepository get mockAiConfigRepo => harness.mockAiConfigRepo;
MockAiInputRepository get mockAiInputRepo => harness.mockAiInputRepo;
MockCloudInferenceRepository get mockCloudInferenceRepo =>
    harness.mockCloudInferenceRepo;
MockJournalRepository get mockJournalRepo => harness.mockJournalRepo;
MockJournalDb get mockJournalDb => harness.mockJournalDb;
MockDirectory get mockDirectory => harness.mockDirectory;
List<Directory> get overrideTempDirs => harness.overrideTempDirs;

void main() {
  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);
  tearDownAll(harness.tearDownAll);

  group('UnifiedAiInferenceRepository', () {
    group('runInference', () {
      test('successfully runs inference for text prompt', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
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

        final progressUpdates = <String>[];
        final statusChanges = <InferenceStatus>[];

        final mockStream = createMockTextStream(['Hello', ' world', '!']);

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: taskEntity,
          model: model,
          provider: provider,
        );
        stubGenerate(mockCloudInferenceRepo, stream: mockStream);
        stubCreateAiResponseEntry(mockAiInputRepo);

        when(
          () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
        ).thenAnswer((_) async => true);

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: progressUpdates.add,
          onStatusChange: statusChanges.add,
        );

        expect(progressUpdates, ['Hello', 'Hello world', 'Hello world!']);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);

        verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: any(named: 'data'),
            start: any(named: 'start'),
            linkedId: 'test-id',
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);

        verify(
          () => mockCloudInferenceRepo.generate(
            any(),
            impactCollector: any(named: 'impactCollector'),
            model: 'gpt-4',
            temperature: 0.6,
            baseUrl: 'https://api.example.com',
            apiKey: 'test-api-key',
            systemMessage: 'System message',
            provider: provider,
            geminiThinkingMode: GeminiThinkingMode.low,
          ),
        ).called(1);
      });

      test('records an AI consumption event for the completed call', () async {
        final taskEntity = Task(
          meta: createMetadata(categoryId: 'cat-1'),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
          ),
        );
        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Prompt',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.promptGeneration,
        );
        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'glm-5.2',
        );
        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.melious,
        );

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: taskEntity,
          model: model,
          provider: provider,
        );
        stubGenerate(
          mockCloudInferenceRepo,
          stream: createMockTextStream(['done']),
        );
        stubCreateAiResponseEntry(mockAiInputRepo);
        when(
          () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
        ).thenAnswer((_) async => true);

        final bench = registerInteractionCapture();

        await repository.runInference(
          entityId: taskEntity.id,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        final captured = capturedEvents(bench);
        expect(captured, hasLength(1));
        final event = captured.single;
        expect(event.entryId, taskEntity.id);
        expect(event.taskId, taskEntity.id);
        expect(event.categoryId, 'cat-1');
        expect(event.providerType, InferenceProviderType.melious);
        expect(event.responseType, AiConsumptionResponseType.promptGeneration);
        expect(event.modelId, 'model-1');
        expect(event.providerModelId, 'glm-5.2');
      });

      test('maps response token usage and Melious impact onto the recorded '
          'consumption event', () async {
        final taskEntity = Task(
          meta: createMetadata(categoryId: 'cat-1'),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
          ),
        );
        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Prompt',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.promptGeneration,
        );
        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'glm-5.2',
        );
        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.melious,
        );

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: taskEntity,
          model: model,
          provider: provider,
        );
        // Usage arrives on the final stream chunk; impact arrives out of
        // band via the collector the repository threads through
        // `_runCloudInference` into `cloudRepo.generate`.
        stubGenerate(
          mockCloudInferenceRepo,
          stream: createMockTextStream(
            ['done'],
            usage: const CompletionUsage(
              promptTokens: 150,
              completionTokens: 60,
              totalTokens: 210,
              promptTokensDetails: PromptTokensDetails(cachedTokens: 40),
              completionTokensDetails: CompletionTokensDetails(
                reasoningTokens: 25,
              ),
            ),
          ),
          impact: const MeliousCallImpact(
            costCredits: 1.25,
            energyKwh: 0.004,
            carbonGCo2: 3.2,
            waterLiters: 0.8,
            renewablePercent: 85,
            pue: 1.15,
            dataCenter: 'FI',
            providerId: 'upstream-glm',
          ),
        );
        stubCreateAiResponseEntry(mockAiInputRepo);
        when(
          () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
        ).thenAnswer((_) async => true);

        final bench = registerInteractionCapture();

        await repository.runInference(
          entityId: taskEntity.id,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        final event = capturedEvents(bench).single;
        expect(event.promptId, 'prompt-1');
        expect(event.durationMs, isNotNull);
        expect(event.inputTokens, 150);
        expect(event.outputTokens, 60);
        expect(event.cachedInputTokens, 40);
        expect(event.thoughtsTokens, 25);
        expect(event.totalTokens, 210);
        expect(event.credits, 1.25);
        expect(event.energyKwh, 0.004);
        expect(event.carbonGCo2, 3.2);
        expect(event.waterLiters, 0.8);
        expect(event.renewablePercent, 85);
        expect(event.pue, 1.15);
        expect(event.dataCenter, 'FI');
        expect(event.upstreamProviderId, 'upstream-glm');
      });

      test(
        'terminalizes attribution when the output carrier cannot persist',
        () async {
          final taskEntity = Task(
            meta: createMetadata(categoryId: 'cat-failed'),
            data: TaskData(
              status: TaskStatus.inProgress(
                id: 'status-failed',
                createdAt: DateTime(2024, 3, 15, 10, 30),
                utcOffset: 0,
              ),
              title: 'Failed attributed output',
              statusHistory: [],
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
          );
          final promptConfig = createPrompt(
            id: 'prompt-failed',
            name: 'Failed prompt',
            requiredInputData: [InputDataType.task],
            aiResponseType: AiResponseType.promptGeneration,
          );
          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'glm-5.2',
          );
          final provider = createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.melious,
          );
          stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: taskEntity,
            model: model,
            provider: provider,
          );
          stubGenerate(
            mockCloudInferenceRepo,
            stream: createMockTextStream(['generated']),
          );
          when(
            () => mockAiInputRepo.createAiResponseEntry(
              id: any(named: 'id'),
              data: any(named: 'data'),
              start: any(named: 'start'),
              linkedId: any(named: 'linkedId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => null);
          final bench = registerInteractionCapture();

          await expectLater(
            repository.runInference(
              entityId: taskEntity.id,
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: (_) {},
            ),
            throwsStateError,
          );

          verify(
            () => bench.service.prepareCompletion(
              attributionId: any(named: 'attributionId'),
              outputs: const [],
              status: AiWorkStatus.failed,
              errorCode: 'StateError',
            ),
          ).called(1);
          verify(() => bench.service.finalize(any())).called(1);
        },
      );

      group('coding prompt task linking', () {
        // A coding prompt (AiResponseType.promptGeneration) should attach to
        // the parent task — like cover art — rather than the triggering
        // audio/image entry, so each generated prompt becomes part of the
        // task context for later prompts.

        JournalAudio audioEntity() => JournalAudio(
          meta: createMetadata(categoryId: 'cat-1'),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
            audioFile: 'test.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(seconds: 30),
          ),
        );

        Task parentTask() => Task(
          meta: createMetadata(id: 'task-id'),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Parent Task',
            statusHistory: const [],
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
          ),
        );

        AiConfigPrompt codingPrompt() => createPrompt(
          id: 'coding-prompt',
          name: 'Generate Coding Prompt',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.promptGeneration,
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

        Future<void> runCodingPrompt({
          required JournalEntity entity,
          required AiConfigPrompt prompt,
        }) async {
          stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: entity,
            model: model,
            provider: provider,
          );
          stubGenerate(
            mockCloudInferenceRepo,
            stream: createMockTextStream(['Generated prompt']),
          );
          stubCreateAiResponseEntry(mockAiInputRepo);
          when(
            () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
          ).thenAnswer((_) async => true);

          await repository.runInference(
            entityId: 'test-id',
            promptConfig: prompt,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );
        }

        test(
          'coding prompt from audio links to the resolved parent task',
          () async {
            when(
              () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
            ).thenAnswer((_) async => [parentTask()]);

            await runCodingPrompt(
              entity: audioEntity(),
              prompt: codingPrompt(),
            );

            // Linked to the parent task, not the triggering audio entry.
            verify(
              () => mockAiInputRepo.createAiResponseEntry(
                data: any(named: 'data'),
                start: any(named: 'start'),
                linkedId: 'task-id',
                categoryId: any(named: 'categoryId'),
              ),
            ).called(1);
          },
        );

        test(
          'coding prompt from audio falls back to the entry when no task',
          () async {
            when(
              () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
            ).thenAnswer((_) async => <JournalEntity>[]);

            await runCodingPrompt(
              entity: audioEntity(),
              prompt: codingPrompt(),
            );

            // No parent task resolved → keep linking to the source entry.
            verify(
              () => mockAiInputRepo.createAiResponseEntry(
                data: any(named: 'data'),
                start: any(named: 'start'),
                linkedId: 'test-id',
                categoryId: any(named: 'categoryId'),
              ),
            ).called(1);
          },
        );

        test(
          'coding prompt from a task links to the task without a lookup',
          () async {
            await runCodingPrompt(
              entity: parentTask().copyWith(meta: createMetadata()),
              prompt: codingPrompt(),
            );

            // Task entities resolve to themselves; no link traversal needed.
            verifyNever(
              () => mockJournalRepo.getLinkedToEntities(
                linkedTo: any(named: 'linkedTo'),
              ),
            );
            verify(
              () => mockAiInputRepo.createAiResponseEntry(
                data: any(named: 'data'),
                start: any(named: 'start'),
                linkedId: 'test-id',
                categoryId: any(named: 'categoryId'),
              ),
            ).called(1);
          },
        );

        test(
          'coding prompt from a non-task/non-audio entry keeps the entry link',
          () async {
            final textEntry = JournalEntry(
              meta: createMetadata(),
              entryText: const EntryText(plainText: 'note'),
            );

            await runCodingPrompt(entity: textEntry, prompt: codingPrompt());

            // _getTaskForEntity returns null for plain entries → fallback.
            verify(
              () => mockAiInputRepo.createAiResponseEntry(
                data: any(named: 'data'),
                start: any(named: 'start'),
                linkedId: 'test-id',
                categoryId: any(named: 'categoryId'),
              ),
            ).called(1);
          },
        );

        // Beyond the primary task link, the prompt is additionally linked back
        // to the source entry so it shows in both linked-entries lists. These
        // tests need a non-null response entry (the shared helper stubs null),
        // so they set the create/link stubs directly.
        group('dual link to source entry', () {
          AiResponseEntry responseEntry() => AiResponseEntry(
            meta: createMetadata(id: 'resp-1'),
            data: const AiResponseData(
              model: 'gpt-4',
              systemMessage: '',
              prompt: 'p',
              thoughts: '',
              response: 'r',
              type: AiResponseType.promptGeneration,
            ),
          );

          Future<void> runReturningEntry({
            required JournalEntity entity,
            Object linkOutcome = true,
          }) async {
            stubInferenceContext(
              mockAiInputRepo: mockAiInputRepo,
              mockAiConfigRepo: mockAiConfigRepo,
              entity: entity,
              model: model,
              provider: provider,
            );
            stubGenerate(
              mockCloudInferenceRepo,
              stream: createMockTextStream(['Generated prompt']),
            );
            when(
              () => mockAiInputRepo.createAiResponseEntry(
                data: any(named: 'data'),
                start: any(named: 'start'),
                linkedId: any(named: 'linkedId'),
                categoryId: any(named: 'categoryId'),
              ),
            ).thenAnswer((_) async => responseEntry());
            final linkStub = when(
              () => mockAiInputRepo.createLink(
                fromId: any(named: 'fromId'),
                toId: any(named: 'toId'),
              ),
            );
            if (linkOutcome is bool) {
              linkStub.thenAnswer((_) async => linkOutcome);
            } else {
              linkStub.thenThrow(linkOutcome);
            }
            when(
              () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
            ).thenAnswer((_) async => true);

            await repository.runInference(
              entityId: 'test-id',
              promptConfig: codingPrompt(),
              onProgress: (_) {},
              onStatusChange: (_) {},
            );
          }

          test(
            'links prompt to the parent task and back to the source entry',
            () async {
              when(
                () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
              ).thenAnswer((_) async => [parentTask()]);

              await runReturningEntry(entity: audioEntity());

              verify(
                () => mockAiInputRepo.createAiResponseEntry(
                  data: any(named: 'data'),
                  start: any(named: 'start'),
                  linkedId: 'task-id',
                  categoryId: any(named: 'categoryId'),
                ),
              ).called(1);
              verify(
                () => mockAiInputRepo.createLink(
                  fromId: 'test-id',
                  toId: 'resp-1',
                ),
              ).called(1);
            },
          );

          test(
            'does not add a second link when no parent task resolves',
            () async {
              when(
                () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
              ).thenAnswer((_) async => <JournalEntity>[]);

              await runReturningEntry(entity: audioEntity());

              verifyNever(
                () => mockAiInputRepo.createLink(
                  fromId: any(named: 'fromId'),
                  toId: any(named: 'toId'),
                ),
              );
            },
          );

          test(
            'a false link result is tolerated and the run still completes',
            () async {
              when(
                () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
              ).thenAnswer((_) async => [parentTask()]);

              await runReturningEntry(
                entity: audioEntity(),
                linkOutcome: false,
              );

              // Primary write still happened; the false back-link is swallowed.
              verify(
                () => mockAiInputRepo.createAiResponseEntry(
                  data: any(named: 'data'),
                  start: any(named: 'start'),
                  linkedId: 'task-id',
                  categoryId: any(named: 'categoryId'),
                ),
              ).called(1);
              verify(
                () => mockAiInputRepo.createLink(
                  fromId: 'test-id',
                  toId: 'resp-1',
                ),
              ).called(1);
            },
          );

          test(
            'a thrown link failure is isolated and does not fail the run',
            () async {
              when(
                () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
              ).thenAnswer((_) async => [parentTask()]);

              // The secondary link throws, but the primary prompt is already
              // persisted, so runInference must complete without rethrowing.
              await expectLater(
                runReturningEntry(
                  entity: audioEntity(),
                  linkOutcome: Exception('db down'),
                ),
                completes,
              );

              verify(
                () => mockAiInputRepo.createAiResponseEntry(
                  data: any(named: 'data'),
                  start: any(named: 'start'),
                  linkedId: 'task-id',
                  categoryId: any(named: 'categoryId'),
                ),
              ).called(1);
            },
          );
        });
      });

      test(
        'runInference emits single progress update when streaming flag is disabled',
        () async {
          final taskEntity = Task(
            meta: createMetadata(),
            data: TaskData(
              status: TaskStatus.inProgress(
                id: 'status-1',
                createdAt: DateTime(2024, 1, 1),
                utcOffset: 0,
              ),
              title: 'Test Task',
              statusHistory: const [],
              dateFrom: DateTime(2024, 1, 1),
              dateTo: DateTime(2024, 1, 1),
            ),
          );

          final model = AiConfigModel(
            id: 'model-1',
            name: 'Test Model',
            providerModelId: 'gpt-4',
            inferenceProviderId: 'provider-1',
            createdAt: DateTime(2024),
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: false,
            supportsFunctionCalling: false,
          );

          final provider = AiConfigInferenceProvider(
            id: 'provider-1',
            name: 'Test Provider',
            baseUrl: 'https://api.example.com',
            apiKey: 'test-api-key',
            createdAt: DateTime(2024),
            inferenceProviderType: InferenceProviderType.openAi,
          );

          final promptConfig = createPrompt(
            id: 'prompt-1',
            name: 'Test Prompt',
            defaultModelId: 'model-1',
            requiredInputData: const [InputDataType.tasksList],
            aiResponseType: AiResponseType.imageAnalysis,
          );

          final progressUpdates = <String>[];
          final statusChanges = <InferenceStatus>[];

          final mockStream = createMockTextStream(['Hello', ' world', '!']);

          stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: taskEntity,
            model: model,
            provider: provider,
          );
          stubGenerate(mockCloudInferenceRepo, stream: mockStream);
          stubCreateAiResponseEntry(mockAiInputRepo);
          when(
            () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
          ).thenAnswer((_) async => false);

          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: progressUpdates.add,
            onStatusChange: statusChanges.add,
          );

          expect(progressUpdates, ['Hello world!']);
          expect(statusChanges, [
            InferenceStatus.running,
            InferenceStatus.idle,
          ]);
        },
      );

      test('successfully runs inference with images', () async {
        // Create a temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('image_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final imageEntity = JournalImage(
          meta: createMetadata(),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/images').createSync(recursive: true);
        final imageFile = File('${tempDir.path}/images/test.jpg');
        final mockImageBytes = Uint8List.fromList([1, 2, 3, 4]);
        imageFile.writeAsBytesSync(mockImageBytes);

        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4-vision',
        );

        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        final progressUpdates = <String>[];
        final statusChanges = <InferenceStatus>[];

        final mockStream = createMockTextStream(['Image shows', ' a cat']);

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: imageEntity,
          model: model,
          provider: provider,
          taskDetailsJson: '{"image": "test.jpg"}',
        );
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []); // No linked task
        stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);
        stubCreateAiResponseEntry(mockAiInputRepo);

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        when(
          () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
        ).thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: progressUpdates.add,
            onStatusChange: statusChanges.add,
          );

          expect(progressUpdates, ['Image shows', 'Image shows a cat']);
          expect(statusChanges, [
            InferenceStatus.running,
            InferenceStatus.idle,
          ]);

          verify(
            () => mockCloudInferenceRepo.generateWithImages(
              any(),
              impactCollector: any(named: 'impactCollector'),
              provider: any(named: 'provider'),
              model: 'gpt-4-vision',
              temperature: 0.6,
              images: any(named: 'images'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
            ),
          ).called(1);

          verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test('forwards the model row thinking mode to generateWithImages '
          'for Gemini providers', () async {
        final tempDir = Directory.systemTemp.createTempSync('image_gemini');
        overrideTempDirs.add(tempDir);
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final imageEntity = JournalImage(
          meta: createMetadata(),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
        );
        Directory('${tempDir.path}/images').createSync(recursive: true);
        File(
          '${tempDir.path}/images/test.jpg',
        ).writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));

        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );
        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gemini-3-flash-preview',
          geminiThinkingMode: GeminiThinkingMode.high,
        );
        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.gemini,
        );

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: imageEntity,
          model: model,
          provider: provider,
          taskDetailsJson: '{"image": "test.jpg"}',
        );
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []);
        when(
          () => mockCloudInferenceRepo.generateWithImages(
            any(),
            impactCollector: any(named: 'impactCollector'),
            provider: any(named: 'provider'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
          ),
        ).thenAnswer((_) => createMockTextStream(['A cat']));
        stubCreateAiResponseEntry(mockAiInputRepo);
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );

          verify(
            () => mockCloudInferenceRepo.generateWithImages(
              any(),
              impactCollector: any(named: 'impactCollector'),
              provider: any(named: 'provider'),
              model: 'gemini-3-flash-preview',
              temperature: any(named: 'temperature'),
              images: any(named: 'images'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              geminiThinkingMode: GeminiThinkingMode.high,
            ),
          ).called(1);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('rethrows when the image file is missing on disk', () async {
        // Point the documents directory at an empty temp dir WITHOUT creating
        // the image file, so _prepareImages' readAsBytes fails.
        final tempDir = Directory.systemTemp.createTempSync('image_missing');
        overrideTempDirs.add(tempDir);
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final imageEntity = JournalImage(
          meta: createMetadata(),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
            imageId: 'test-image',
            imageFile: 'missing.jpg',
            imageDirectory: '/images/',
          ),
        );

        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: imageEntity,
          model: createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'gpt-4-vision',
          ),
          provider: createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.genericOpenAi,
          ),
          taskDetailsJson: '{"image": "missing.jpg"}',
        );
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []);

        final statusChanges = <InferenceStatus>[];

        // runInference logs and rethrows; the file read failure surfaces as
        // a FileSystemException and no idle status is ever emitted.
        await expectLater(
          repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: statusChanges.add,
          ),
          throwsA(isA<FileSystemException>()),
        );

        expect(statusChanges, [InferenceStatus.running]);
        verifyNever(
          () => mockCloudInferenceRepo.generateWithImages(
            any(),
            impactCollector: any(named: 'impactCollector'),
            provider: any(named: 'provider'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
          ),
        );
      });

      test('rejects image paths that escape the documents directory', () async {
        final sandbox = Directory.systemTemp.createTempSync('image_escape');
        overrideTempDirs.add(sandbox);
        final documentsDirectory = Directory('${sandbox.path}/Documents')
          ..createSync();
        when(() => mockDirectory.path).thenReturn(documentsDirectory.path);
        File('${sandbox.path}/secret.jpg').writeAsBytesSync([1, 2, 3, 4]);

        final imageEntity = JournalImage(
          meta: createMetadata(),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
            imageId: 'test-image',
            imageFile: 'secret.jpg',
            imageDirectory: '../',
          ),
        );
        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );
        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: imageEntity,
          model: createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'gpt-4-vision',
          ),
          provider: createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.genericOpenAi,
          ),
          taskDetailsJson: '{"image": "secret.jpg"}',
        );
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []);

        await expectLater(
          repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('escapes documents directory'),
            ),
          ),
        );

        verifyNever(
          () => mockCloudInferenceRepo.generateWithImages(
            any(),
            impactCollector: any(named: 'impactCollector'),
            provider: any(named: 'provider'),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            images: any(named: 'images'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
          ),
        );
      });

      test('rethrows when the audio file is missing on disk', () async {
        final tempDir = Directory.systemTemp.createTempSync('audio_missing');
        overrideTempDirs.add(tempDir);
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final audioEntity = JournalAudio(
          meta: createMetadata(),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
            audioFile: 'missing.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(seconds: 30),
          ),
        );

        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Audio Transcription',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: audioEntity,
          model: createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'whisper-1',
          ),
          provider: createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.genericOpenAi,
          ),
          taskDetailsJson: '{"audio": "missing.mp3"}',
        );
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []);

        final statusChanges = <InferenceStatus>[];

        await expectLater(
          repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: statusChanges.add,
          ),
          throwsA(isA<FileSystemException>()),
        );

        expect(statusChanges, [InferenceStatus.running]);
      });

      test('successfully runs inference with audio', () async {
        // Create a temporary directory for the test
        final tempDir = Directory.systemTemp.createTempSync('audio_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final audioEntity = JournalAudio(
          meta: createMetadata(),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
            audioFile: 'test.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(seconds: 30),
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/audio').createSync(recursive: true);
        final audioFile = File('${tempDir.path}/audio/test.mp3');
        final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
        audioFile.writeAsBytesSync(mockAudioBytes);

        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Audio Transcription',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );

        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'whisper-1',
        );

        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        final progressUpdates = <String>[];
        final statusChanges = <InferenceStatus>[];

        final mockStream = createMockTextStream(['Hello world']);

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: audioEntity,
          model: model,
          provider: provider,
          taskDetailsJson: '{"audio": "test.mp3"}',
        );
        stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);
        stubCreateAiResponseEntry(mockAiInputRepo);

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        // Mock getLinkedToEntities to return empty list (no linked tasks)
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: progressUpdates.add,
            onStatusChange: statusChanges.add,
          );

          expect(progressUpdates, ['Hello world']);
          expect(statusChanges, [
            InferenceStatus.running,
            InferenceStatus.idle,
          ]);

          verify(
            () => mockCloudInferenceRepo.generateWithAudio(
              provider: any(named: 'provider'),
              any(),
              model: 'whisper-1',
              audioBase64: any(named: 'audioBase64'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
              stream: any(named: 'stream'),
              audioFormat: any(named: 'audioFormat'),
            ),
          ).called(1);

          // updateJournalEntity verification is already done via the captured call above
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test('forwards the model row thinking mode to generateWithAudio '
          'for Gemini providers', () async {
        final tempDir = Directory.systemTemp.createTempSync('audio_gemini');
        overrideTempDirs.add(tempDir);
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final audioEntity = JournalAudio(
          meta: createMetadata(),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
            audioFile: 'test.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(seconds: 30),
          ),
        );
        Directory('${tempDir.path}/audio').createSync(recursive: true);
        File(
          '${tempDir.path}/audio/test.mp3',
        ).writeAsBytesSync(Uint8List.fromList([1, 2, 3]));

        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Audio Transcription',
          requiredInputData: [InputDataType.audioFiles],
          aiResponseType: AiResponseType.audioTranscription,
        );
        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gemini-3-flash-preview',
          geminiThinkingMode: GeminiThinkingMode.medium,
        );
        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.gemini,
        );

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: audioEntity,
          model: model,
          provider: provider,
          taskDetailsJson: '{"audio": "test.mp3"}',
        );
        when(
          () => mockCloudInferenceRepo.generateWithAudio(
            any(),
            provider: any(named: 'provider'),
            model: any(named: 'model'),
            audioBase64: any(named: 'audioBase64'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            stream: any(named: 'stream'),
            audioFormat: any(named: 'audioFormat'),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
          ),
        ).thenAnswer((_) => createMockTextStream(['Hello']));
        stubCreateAiResponseEntry(mockAiInputRepo);
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );

          verify(
            () => mockCloudInferenceRepo.generateWithAudio(
              any(),
              provider: any(named: 'provider'),
              model: 'gemini-3-flash-preview',
              audioBase64: any(named: 'audioBase64'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              maxCompletionTokens: any(named: 'maxCompletionTokens'),
              stream: any(named: 'stream'),
              audioFormat: any(named: 'audioFormat'),
              speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
              geminiThinkingMode: GeminiThinkingMode.medium,
            ),
          ).called(1);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('handles reasoning model response with thoughts', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
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

        final progressUpdates = <String>[];
        final statusChanges = <InferenceStatus>[];

        final mockStream = createMockTextStream([
          '<think>Let me analyze this task</think>Task completed successfully',
        ]);

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: taskEntity,
          model: model,
          provider: provider,
        );
        stubGenerate(mockCloudInferenceRepo, stream: mockStream);
        stubCreateAiResponseEntry(mockAiInputRepo);
        when(
          () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
        ).thenAnswer((_) async => true);

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: progressUpdates.add,
          onStatusChange: statusChanges.add,
        );

        expect(progressUpdates, [
          '<think>Let me analyze this task</think>Task completed successfully',
        ]);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);

        // Verify that the AI response entry was created with extracted thoughts
        final captured = verify(
          () => mockAiInputRepo.createAiResponseEntry(
            data: captureAny(named: 'data'),
            start: any(named: 'start'),
            linkedId: 'test-id',
            categoryId: any(named: 'categoryId'),
          ),
        ).captured;

        final data = captured.first as AiResponseData;
        // Thoughts should have <think> tags stripped during extraction
        expect(data.thoughts, 'Let me analyze this task');
        expect(data.response, 'Task completed successfully');
      });

      test('handles provider not found error', () {
        fakeAsync((async) {
          final taskEntity = Task(
            meta: createMetadata(),
            data: TaskData(
              status: TaskStatus.inProgress(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15, 10, 30),
                utcOffset: 0,
              ),
              title: 'Test Task',
              statusHistory: [],
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

          final statusChanges = <InferenceStatus>[];

          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);
          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => null);

          expect(
            () => repository.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: statusChanges.add,
            ),
            throwsA(isA<Exception>()),
          );

          // Deterministically process queued microtasks
          async.flushMicrotasks();
          // Note: Repository no longer emits error status - controller handles it
          expect(statusChanges, [InferenceStatus.running]);
        });
      });

      test('handles build prompt failure', () {
        fakeAsync((async) {
          final taskEntity = Task(
            meta: createMetadata(),
            data: TaskData(
              status: TaskStatus.inProgress(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15, 10, 30),
                utcOffset: 0,
              ),
              title: 'Test Task',
              statusHistory: [],
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

          final statusChanges = <InferenceStatus>[];

          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => model);
          when(
            () => mockAiConfigRepo.getConfigById('provider-1'),
          ).thenAnswer((_) async => provider);
          when(
            () => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'),
          ).thenAnswer((_) async => null);

          when(
            () => mockCloudInferenceRepo.generate(
              any(),
              impactCollector: any(named: 'impactCollector'),
              model: any(named: 'model'),
              temperature: any(named: 'temperature'),
              baseUrl: any(named: 'baseUrl'),
              apiKey: any(named: 'apiKey'),
              systemMessage: any(named: 'systemMessage'),
              provider: any(named: 'provider'),
              geminiThinkingMode: any(named: 'geminiThinkingMode'),
            ),
          ).thenThrow(Exception('Failed to build prompt'));

          expect(
            () => repository.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: statusChanges.add,
            ),
            throwsA(isA<Exception>()),
          );

          // Deterministically process queued microtasks
          async.flushMicrotasks();
          // Note: Repository no longer emits error status - controller handles it
          expect(statusChanges, [InferenceStatus.running]);
        });
      });

      test('handles empty stream chunk content', () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
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

        final progressUpdates = <String>[];
        final statusChanges = <InferenceStatus>[];

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
          CreateChatCompletionStreamResponse(
            id: 'response-2',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: 'Hello'),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        when(
          () => mockAiInputRepo.getEntity('test-id'),
        ).thenAnswer((_) async => taskEntity);
        when(
          () => mockAiConfigRepo.getConfigById('model-1'),
        ).thenAnswer((_) async => model);
        when(
          () => mockAiConfigRepo.getConfigById('provider-1'),
        ).thenAnswer((_) async => provider);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'),
        ).thenAnswer((_) async => '{"task": "Test Task"}');

        stubGenerate(mockCloudInferenceRepo, stream: mockStream);

        stubCreateAiResponseEntry(mockAiInputRepo);
        when(
          () => mockJournalDb.getConfigFlag(enableAiStreamingFlag),
        ).thenAnswer((_) async => true);

        await repository.runInference(
          entityId: 'test-id',
          promptConfig: promptConfig,
          onProgress: progressUpdates.add,
          onStatusChange: statusChanges.add,
        );

        expect(progressUpdates, ['', 'Hello']);
        expect(statusChanges, [InferenceStatus.running, InferenceStatus.idle]);
      });

      test('handles error during inference', () {
        fakeAsync((async) {
          final taskEntity = Task(
            meta: createMetadata(),
            data: TaskData(
              status: TaskStatus.inProgress(
                id: 'status-1',
                createdAt: DateTime(2024, 3, 15, 10, 30),
                utcOffset: 0,
              ),
              title: 'Test Task',
              statusHistory: [],
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
            ),
          );

          final promptConfig = createPrompt(
            id: 'prompt-1',
            name: 'Task Summary',
            requiredInputData: [InputDataType.task],
          );

          final statusChanges = <InferenceStatus>[];

          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => taskEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenThrow(Exception('Model not found'));

          expect(
            () => repository.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: statusChanges.add,
            ),
            throwsException,
          );

          // Deterministically process queued microtasks
          async.flushMicrotasks();
          // Note: Repository no longer emits error status - controller handles it
          expect(statusChanges, [InferenceStatus.running]);
        });
      });

      test('handles entity not found error', () {
        fakeAsync((async) {
          final promptConfig = createPrompt(
            id: 'prompt-1',
            name: 'Task Summary',
            requiredInputData: [InputDataType.task],
          );

          final statusChanges = <InferenceStatus>[];

          when(
            () => mockAiInputRepo.getEntity('test-id'),
          ).thenAnswer((_) async => null);

          expect(
            () => repository.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: statusChanges.add,
            ),
            throwsA(isA<Exception>()),
          );

          // Deterministically process queued microtasks
          async.flushMicrotasks();
          // Note: Repository no longer emits error status - controller handles it
          expect(statusChanges, [InferenceStatus.running]);
        });
      });

      test(
        'audio transcription updates both transcripts and entry text',
        () async {
          final tempDir = Directory.systemTemp.createTempSync('audio_test');
          overrideTempDirs.add(tempDir);

          // Update the mock directory to point to our temp directory
          when(() => mockDirectory.path).thenReturn(tempDir.path);

          final audioEntity = JournalAudio(
            meta: createMetadata(),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
              audioFile: 'test.mp3',
              audioDirectory: '/audio/',
              duration: const Duration(seconds: 30),
            ),
          );

          // Create the directory structure and file
          Directory('${tempDir.path}/audio').createSync(recursive: true);
          final audioFile = File('${tempDir.path}/audio/test.mp3');
          final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
          audioFile.writeAsBytesSync(mockAudioBytes);

          final promptConfig = createPrompt(
            id: 'prompt-1',
            name: 'Audio Transcription',
            requiredInputData: [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
          );

          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'whisper-1',
          );

          final provider = createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.genericOpenAi,
          );

          final progressUpdates = <String>[];
          final statusChanges = <InferenceStatus>[];
          const transcriptText = 'This is the transcribed audio content.';

          final mockStream = Stream.fromIterable([
            CreateChatCompletionStreamResponse(
              id: 'response-1',
              choices: [
                const ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(
                    content: transcriptText,
                  ),
                  finishReason: ChatCompletionFinishReason.stop,
                  index: 0,
                ),
              ],
              object: 'chat.completion.chunk',
              created:
                  DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
            ),
          ]);

          stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: audioEntity,
            model: model,
            provider: provider,
            taskDetailsJson: '{"audio": "test.mp3"}',
          );
          stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

          stubCreateAiResponseEntry(mockAiInputRepo);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          // Mock getLinkedToEntities to return empty list (no linked tasks)
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => []);

          try {
            await repository.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: progressUpdates.add,
              onStatusChange: statusChanges.add,
            );

            expect(progressUpdates, [transcriptText]);
            expect(statusChanges, [
              InferenceStatus.running,
              InferenceStatus.idle,
            ]);

            // Verify that updateJournalEntity was called with the correct data
            final captured = verify(
              () => mockJournalRepo.updateJournalEntity(captureAny()),
            ).captured;
            final updatedEntity = captured.first as JournalAudio;

            // Verify that the transcript was added to the transcripts array
            expect(updatedEntity.data.transcripts, isNotNull);
            expect(updatedEntity.data.transcripts!.length, 1);
            expect(
              updatedEntity.data.transcripts!.first.transcript,
              transcriptText.trim(),
            );
            expect(
              updatedEntity.data.transcripts!.first.library,
              'Test Provider',
            );

            // Verify that the entry text was updated with the transcript
            expect(updatedEntity.entryText, isNotNull);
            expect(updatedEntity.entryText!.plainText, transcriptText.trim());
            expect(updatedEntity.entryText!.markdown, transcriptText.trim());

            verify(
              () => mockCloudInferenceRepo.generateWithAudio(
                provider: any(named: 'provider'),
                any(),
                model: 'whisper-1',
                audioBase64: any(named: 'audioBase64'),
                baseUrl: 'https://api.example.com',
                apiKey: 'test-api-key',
                stream: any(named: 'stream'),
                audioFormat: any(named: 'audioFormat'),
              ),
            ).called(1);

            // updateJournalEntity verification is already done via the captured call above
          } finally {
            // Clean up the temporary directory
            tempDir.deleteSync(recursive: true);
          }
        },
      );

      group('attributed audio transcription', () {
        Future<AiInteractionCaptureTestBench> arrange({
          required bool persisted,
        }) async {
          final tempDir = Directory.systemTemp.createTempSync(
            'attributed_audio_test',
          );
          overrideTempDirs.add(tempDir);
          when(() => mockDirectory.path).thenReturn(tempDir.path);
          final audioEntity = JournalAudio(
            meta: createMetadata(categoryId: 'cat-audio'),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
              audioFile: 'test.mp3',
              audioDirectory: '/audio/',
              duration: const Duration(seconds: 30),
            ),
          );
          Directory('${tempDir.path}/audio').createSync(recursive: true);
          File('${tempDir.path}/audio/test.mp3').writeAsBytesSync([1, 2, 3, 4]);
          final promptConfig = createPrompt(
            id: 'prompt-audio-attributed',
            name: 'Attributed audio',
            requiredInputData: [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
          );
          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'whisper-1',
          );
          final provider = createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.genericOpenAi,
          );
          stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: audioEntity,
            model: model,
            provider: provider,
          );
          stubGenerateWithAudio(
            mockCloudInferenceRepo,
            stream: createMockTextStream(['Attributed transcript']),
          );
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: audioEntity.id),
          ).thenAnswer((_) async => []);
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => persisted);
          final bench = registerInteractionCapture();
          if (persisted) {
            await repository.runInference(
              entityId: audioEntity.id,
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: (_) {},
            );
          } else {
            await expectLater(
              repository.runInference(
                entityId: audioEntity.id,
                promptConfig: promptConfig,
                onProgress: (_) {},
                onStatusChange: (_) {},
              ),
              throwsStateError,
            );
          }
          return bench;
        }

        test('embeds and finalizes the transcript carrier', () async {
          final bench = await arrange(persisted: true);

          final updated =
              verify(
                    () => mockJournalRepo.updateJournalEntity(captureAny()),
                  ).captured.single
                  as JournalAudio;
          final transcript = updated.data.transcripts!.single;
          expect(transcript.transcript, 'Attributed transcript');
          expect(transcript.id, isNotNull);
          expect(transcript.aiAttribution?.primaryOutput?.subId, transcript.id);
          verify(() => bench.service.finalize(any())).called(1);
        });

        test(
          'fails the work when transcript persistence returns false',
          () async {
            final bench = await arrange(persisted: false);

            verify(
              () => bench.service.prepareCompletion(
                attributionId: any(named: 'attributionId'),
                outputs: const [],
                status: AiWorkStatus.failed,
                errorCode: 'StateError',
              ),
            ).called(1);
            verify(() => bench.service.finalize(any())).called(1);
          },
        );

        test('persists transcription failure before provider setup', () async {
          final audioEntity = JournalAudio(
            meta: createMetadata(categoryId: 'cat-audio'),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
              audioFile: 'missing.mp3',
              audioDirectory: '/audio/',
              duration: const Duration(seconds: 30),
            ),
          );
          final promptConfig = createPrompt(
            id: 'prompt-audio-attributed',
            name: 'Attributed audio',
            requiredInputData: [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
          );
          when(
            () => mockAiInputRepo.getEntity(audioEntity.id),
          ).thenAnswer((_) async => audioEntity);
          when(
            () => mockAiConfigRepo.getConfigById('model-1'),
          ).thenAnswer((_) async => null);
          final bench = registerInteractionCapture();

          await expectLater(
            repository.runInference(
              entityId: audioEntity.id,
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: (_) {},
            ),
            throwsA(isA<Exception>()),
          );

          final start =
              verify(() => bench.service.begin(captureAny())).captured.single
                  as AiAttributionStart;
          expect(start.workType, AiWorkType.audioTranscription);
          expect(
            start.intendedOutputs.single,
            isA<AiArtifactReference>()
                .having(
                  (output) => output.type,
                  'type',
                  AiArtifactType.journalAudio,
                )
                .having((output) => output.id, 'id', audioEntity.id),
          );
          verify(
            () => bench.service.prepareCompletion(
              attributionId: any(named: 'attributionId'),
              outputs: const [],
              status: AiWorkStatus.failed,
              errorCode: any(named: 'errorCode'),
            ),
          ).called(1);
          verify(() => bench.service.finalize(any())).called(1);
        });
      });

      test(
        'audio transcription preserves existing transcripts when adding new one',
        () async {
          final tempDir = Directory.systemTemp.createTempSync('audio_test');
          overrideTempDirs.add(tempDir);

          // Update the mock directory to point to our temp directory
          when(() => mockDirectory.path).thenReturn(tempDir.path);

          final existingTranscript = AudioTranscript(
            created: DateTime(2024, 3, 15, 9, 30),
            library: 'Previous Transcription',
            model: 'old-model',
            detectedLanguage: 'en',
            transcript: 'Previous transcript content',
            processingTime: const Duration(seconds: 5),
          );

          final audioEntity = JournalAudio(
            meta: createMetadata(),
            data: AudioData(
              dateFrom: DateTime(2024, 3, 15, 10, 30),
              dateTo: DateTime(2024, 3, 15, 10, 30),
              audioFile: 'test.mp3',
              audioDirectory: '/audio/',
              duration: const Duration(seconds: 30),
              transcripts: [existingTranscript],
            ),
          );

          // Create the directory structure and file
          Directory('${tempDir.path}/audio').createSync(recursive: true);
          final audioFile = File('${tempDir.path}/audio/test.mp3');
          final mockAudioBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
          audioFile.writeAsBytesSync(mockAudioBytes);

          final promptConfig = createPrompt(
            id: 'prompt-1',
            name: 'Audio Transcription',
            requiredInputData: [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
          );

          final model = createModel(
            id: 'model-1',
            inferenceProviderId: 'provider-1',
            providerModelId: 'whisper-1',
          );

          final provider = createProvider(
            id: 'provider-1',
            inferenceProviderType: InferenceProviderType.genericOpenAi,
          );

          const newTranscriptText = 'This is the new AI transcription.';

          final mockStream = Stream.fromIterable([
            CreateChatCompletionStreamResponse(
              id: 'response-1',
              choices: [
                const ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(
                    content: newTranscriptText,
                  ),
                  finishReason: ChatCompletionFinishReason.stop,
                  index: 0,
                ),
              ],
              object: 'chat.completion.chunk',
              created:
                  DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
            ),
          ]);

          stubInferenceContext(
            mockAiInputRepo: mockAiInputRepo,
            mockAiConfigRepo: mockAiConfigRepo,
            entity: audioEntity,
            model: model,
            provider: provider,
            taskDetailsJson: '{"audio": "test.mp3"}',
          );
          stubGenerateWithAudio(mockCloudInferenceRepo, stream: mockStream);

          stubCreateAiResponseEntry(mockAiInputRepo);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          // Mock getLinkedToEntities to return empty list (no linked tasks)
          when(
            () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
          ).thenAnswer((_) async => []);

          try {
            await repository.runInference(
              entityId: 'test-id',
              promptConfig: promptConfig,
              onProgress: (_) {},
              onStatusChange: (_) {},
            );

            // Verify that updateJournalEntity was called with the correct data
            final captured = verify(
              () => mockJournalRepo.updateJournalEntity(captureAny()),
            ).captured;
            final updatedEntity = captured.first as JournalAudio;

            // Verify that both transcripts are present (existing + new)
            expect(updatedEntity.data.transcripts, isNotNull);
            expect(updatedEntity.data.transcripts!.length, 2);

            // Check that the existing transcript is preserved
            expect(
              updatedEntity.data.transcripts!.first.transcript,
              'Previous transcript content',
            );
            expect(
              updatedEntity.data.transcripts!.first.library,
              'Previous Transcription',
            );

            // Check that the new transcript was added
            expect(
              updatedEntity.data.transcripts!.last.transcript,
              newTranscriptText.trim(),
            );
            expect(
              updatedEntity.data.transcripts!.last.library,
              'Test Provider',
            );

            // Verify that the entry text was updated with the new transcript
            expect(updatedEntity.entryText, isNotNull);
            expect(
              updatedEntity.entryText!.plainText,
              newTranscriptText.trim(),
            );
            expect(updatedEntity.entryText!.markdown, newTranscriptText.trim());
          } finally {
            // Clean up the temporary directory
            tempDir.deleteSync(recursive: true);
          }
        },
      );

      test('image analysis appends to existing entry text', () async {
        final tempDir = Directory.systemTemp.createTempSync('image_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        const existingText = 'This is existing text in the image entry.';

        final imageEntity = JournalImage(
          meta: createMetadata(),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
          entryText: const EntryText(
            plainText: 'This is existing text in the image entry.',
            markdown: 'This is existing text in the image entry.',
          ),
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/images').createSync(recursive: true);
        final imageFile = File('${tempDir.path}/images/test.jpg');
        final mockImageBytes = Uint8List.fromList([1, 2, 3, 4]);
        imageFile.writeAsBytesSync(mockImageBytes);

        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4-vision',
        );

        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        const analysisText =
            'This image shows a beautiful landscape with mountains.';

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: analysisText),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: imageEntity,
          model: model,
          provider: provider,
          taskDetailsJson: '{"image": "test.jpg"}',
        );
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []); // No linked task
        stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

        stubCreateAiResponseEntry(mockAiInputRepo);

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );

          // Verify that updateJournalEntity was called with the correct data
          final captured = verify(
            () => mockJournalRepo.updateJournalEntity(captureAny()),
          ).captured;
          final updatedEntity = captured.first as JournalImage;

          // Verify that the entry text contains both the original text and the analysis
          expect(updatedEntity.entryText, isNotNull);
          expect(updatedEntity.entryText!.markdown, contains(existingText));
          expect(updatedEntity.entryText!.markdown, contains(analysisText));
          expect(
            updatedEntity.entryText!.markdown,
            isNot(contains('Disclaimer')), // No disclaimer anymore
          );

          // Verify the structure: original text + newlines + analysis
          const expectedText = '$existingText\n\n$analysisText';
          expect(updatedEntity.entryText!.markdown, equals(expectedText));

          verify(
            () => mockCloudInferenceRepo.generateWithImages(
              any(),
              impactCollector: any(named: 'impactCollector'),
              provider: any(named: 'provider'),
              model: 'gpt-4-vision',
              temperature: 0.6,
              images: any(named: 'images'),
              baseUrl: 'https://api.example.com',
              apiKey: 'test-api-key',
            ),
          ).called(1);
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });

      test('image analysis works correctly with empty entry text', () async {
        final tempDir = Directory.systemTemp.createTempSync('image_test');
        overrideTempDirs.add(tempDir);

        // Update the mock directory to point to our temp directory
        when(() => mockDirectory.path).thenReturn(tempDir.path);

        final imageEntity = JournalImage(
          meta: createMetadata(),
          data: ImageData(
            capturedAt: DateTime(2024, 3, 15, 10, 30),
            imageId: 'test-image',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
          // No entryText - should be null
        );

        // Create the directory structure and file
        Directory('${tempDir.path}/images').createSync(recursive: true);
        final imageFile = File('${tempDir.path}/images/test.jpg');
        final mockImageBytes = Uint8List.fromList([1, 2, 3, 4]);
        imageFile.writeAsBytesSync(mockImageBytes);

        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Image Analysis',
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4-vision',
        );

        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        const analysisText =
            'This image shows a beautiful landscape with mountains.';

        final mockStream = Stream.fromIterable([
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: analysisText),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        ]);

        stubInferenceContext(
          mockAiInputRepo: mockAiInputRepo,
          mockAiConfigRepo: mockAiConfigRepo,
          entity: imageEntity,
          model: model,
          provider: provider,
          taskDetailsJson: '{"image": "test.jpg"}',
        );
        when(
          () => mockJournalRepo.getLinkedToEntities(linkedTo: 'test-id'),
        ).thenAnswer((_) async => []); // No linked task
        stubGenerateWithImages(mockCloudInferenceRepo, stream: mockStream);

        stubCreateAiResponseEntry(mockAiInputRepo);

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        try {
          await repository.runInference(
            entityId: 'test-id',
            promptConfig: promptConfig,
            onProgress: (_) {},
            onStatusChange: (_) {},
          );

          // Verify that updateJournalEntity was called with the correct data
          final captured = verify(
            () => mockJournalRepo.updateJournalEntity(captureAny()),
          ).captured;
          final updatedEntity = captured.first as JournalImage;

          // Verify that the entry text contains only the analysis (no existing text to append to)
          expect(updatedEntity.entryText, isNotNull);
          expect(updatedEntity.entryText!.markdown, equals(analysisText));
          expect(
            updatedEntity.entryText!.markdown,
            isNot(contains('Disclaimer')), // No disclaimer anymore
          );
        } finally {
          // Clean up the temporary directory
          tempDir.deleteSync(recursive: true);
        }
      });
    });
  });
}
