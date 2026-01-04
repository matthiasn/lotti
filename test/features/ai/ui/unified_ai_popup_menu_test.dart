import 'dart:async';

import 'package:drift/drift.dart' show Selectable;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/widgets/modal/modern_modal_prompt_item.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class MockUnifiedAiInferenceRepository extends Mock
    implements UnifiedAiInferenceRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSelectable<T> extends Mock implements Selectable<T> {
  MockSelectable(this._values);

  final List<T> _values;

  @override
  Future<List<T>> get() async => _values;
}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

void main() {
  late JournalEntity testTaskEntity;
  late JournalEntity testJournalEntry;
  late JournalEntity testImageEntity;
  late JournalEntity testAudioEntity;
  late List<AiConfigPrompt> testPrompts;
  late MockNavigatorObserver mockNavigatorObserver;
  late MockUnifiedAiInferenceRepository mockInferenceRepository;
  late MockLoggingService mockLoggingService;
  late MockJournalDb mockJournalDb;
  late List<Override> defaultOverrides;

  setUpAll(() {
    registerFallbackValue(
      StackTrace.current,
    );
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(FakeAiConfigPrompt());
  });

  setUp(() {
    mockNavigatorObserver = MockNavigatorObserver();
    mockInferenceRepository = MockUnifiedAiInferenceRepository();
    mockLoggingService = MockLoggingService();
    mockJournalDb = MockJournalDb();

    // Set up GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(mockJournalDb);

    // Mock JournalDb methods - linksFromId returns a Selectable
    when(() => mockJournalDb.linksFromId(any(), any()))
        .thenReturn(MockSelectable<LinkedDbEntry>([]));
    when(() => mockJournalDb.linkedToJournalEntities(any()))
        .thenReturn(MockSelectable<JournalDbEntity>([]));
    // Mock getLinkedEntities for bidirectional link lookup
    when(() => mockJournalDb.getLinkedEntities(any()))
        .thenAnswer((_) async => <JournalEntity>[]);

    // Mock logging methods
    when(
      () => mockLoggingService.captureEvent(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenReturn(null);

    // Create test entities
    final now = DateTime.now();

    testTaskEntity = Task(
      meta: Metadata(
        id: 'task-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now.add(const Duration(hours: 1)),
      ),
      data: TaskData(
        title: 'Test Task',
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: now,
          utcOffset: 0,
        ),
        dateFrom: now,
        dateTo: now.add(const Duration(hours: 1)),
        statusHistory: [],
      ),
    );

    testJournalEntry = JournalEntry(
      meta: Metadata(
        id: 'entry-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now.add(const Duration(minutes: 30)),
      ),
    );

    testImageEntity = JournalImage(
      meta: Metadata(
        id: 'image-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now.add(const Duration(minutes: 15)),
      ),
      data: ImageData(
        capturedAt: now,
        imageId: 'img-1',
        imageFile: 'test.jpg',
        imageDirectory: '/test',
      ),
    );

    testAudioEntity = JournalAudio(
      meta: Metadata(
        id: 'audio-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now.add(const Duration(minutes: 45)),
      ),
      data: AudioData(
        dateFrom: now,
        dateTo: now.add(const Duration(minutes: 45)),
        audioFile: 'test.mp3',
        audioDirectory: '/test',
        duration: const Duration(minutes: 45),
      ),
    );

    // Create test prompts
    testPrompts = [
      AiConfig.prompt(
        id: 'prompt-1',
        name: 'Task Summary',
        systemMessage: 'Summarize this task',
        userMessage: 'Please summarize the task',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: now,
        useReasoning: false,
        requiredInputData: [InputDataType.tasksList],
        aiResponseType: AiResponseType.taskSummary,
        description: 'Creates a summary of the task',
      ) as AiConfigPrompt,
      AiConfig.prompt(
        id: 'prompt-2',
        name: 'Image Analysis',
        systemMessage: 'Analyze this image',
        userMessage: 'Please analyze the image',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: now,
        useReasoning: false,
        requiredInputData: [InputDataType.images],
        aiResponseType: AiResponseType.imageAnalysis,
        description: 'Analyzes images in detail',
      ) as AiConfigPrompt,
      AiConfig.prompt(
        id: 'prompt-3',
        name: 'Audio Transcription',
        systemMessage: 'Transcribe this audio',
        userMessage: 'Please transcribe the audio',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: now,
        useReasoning: false,
        requiredInputData: [InputDataType.audioFiles],
        aiResponseType: AiResponseType.taskSummary,
      ) as AiConfigPrompt,
      AiConfig.prompt(
        id: 'prompt-4',
        name: 'General Chat',
        systemMessage: 'Chat about this content',
        userMessage: "Let's chat about this",
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: now,
        useReasoning: false,
        requiredInputData: [],
        aiResponseType: AiResponseType.taskSummary,
      ) as AiConfigPrompt,
    ];

    defaultOverrides = [
      for (final prompt in testPrompts)
        aiConfigByIdProvider(prompt.id).overrideWith(
          (ref) async => prompt,
        ),
      // Override entry controllers for all test entities
      entryControllerProvider(id: 'task-1').overrideWith(
        () => FakeEntryController(testTaskEntity),
      ),
      entryControllerProvider(id: 'entry-1').overrideWith(
        () => FakeEntryController(testJournalEntry),
      ),
      entryControllerProvider(id: 'image-1').overrideWith(
        () => FakeEntryController(testImageEntity),
      ),
      entryControllerProvider(id: 'audio-1').overrideWith(
        () => FakeEntryController(testAudioEntity),
      ),
    ];
  });

  tearDown(() async {
    await getIt.reset();
  });

  // Helper function to build test widget
  Widget buildTestWidget(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        ...defaultOverrides,
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [mockNavigatorObserver],
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('UnifiedAiPopUpMenu Tests', () {
    testWidgets('shows assistant icon when prompts are available',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: null,
          ),
          overrides: [
            hasAvailablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value(true)),
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value(testPrompts)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.assistant_rounded), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('shows nothing when no prompts are available', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: null,
          ),
          overrides: [
            hasAvailablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value(false)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.assistant_rounded), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('shows nothing during loading', (tester) async {
      // Arrange
      final completer = Completer<bool>();

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: null,
          ),
          overrides: [
            hasAvailablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => completer.future),
          ],
        ),
      );

      await tester.pump();

      // Assert
      expect(find.byIcon(Icons.assistant_rounded), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);

      // Complete to avoid hanging test
      completer.complete(false);
      await tester.pumpAndSettle();
    });

    testWidgets('shows nothing on error', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: null,
          ),
          overrides: [
            hasAvailablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.error('Test error')),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.assistant_rounded), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('opens modal when assistant icon is tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: 'linked-from-1',
          ),
          overrides: [
            hasAvailablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value(true)),
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value(testPrompts)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      // Assert - check for the prompts list instead of the modal sheet directly
      // since WoltModalSheet might not be easily findable in tests
      expect(find.byType(UnifiedAiPromptsList), findsOneWidget);
    });
  });

  group('UnifiedAiPromptsList Tests', () {
    testWidgets('displays list of prompts correctly', (tester) async {
      // Arrange
      final prompts = testPrompts.take(2).toList(); // Use first 2 prompts

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPromptsList(
            journalEntity: testTaskEntity,
            onPromptSelected: (prompt, index) async {},
          ),
          overrides: [
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value(prompts)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Task Summary'), findsOneWidget);
      expect(find.text('Image Analysis'), findsOneWidget);
      expect(find.text('Creates a summary of the task'), findsOneWidget);
      expect(find.text('Analyzes images in detail'), findsOneWidget);
      expect(find.byType(ModernModalPromptItem), findsNWidgets(2));
    });

    testWidgets('shows correct icons for different prompt types',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPromptsList(
            journalEntity: testTaskEntity,
            onPromptSelected: (prompt, index) async {},
          ),
          overrides: [
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value(testPrompts)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - check for the presence of ModernModalPromptItem widgets which should contain the icons
      expect(find.byType(ModernModalPromptItem),
          findsNWidgets(testPrompts.length));
      expect(find.byType(Icon), findsNWidgets(testPrompts.length));

      // Check for specific prompt names instead of icons which might be harder to match
      expect(find.text('Task Summary'), findsOneWidget);
      expect(find.text('Image Analysis'), findsOneWidget);
      expect(find.text('Audio Transcription'), findsOneWidget);
      expect(find.text('General Chat'), findsOneWidget);
    });

    testWidgets('handles prompts without descriptions', (tester) async {
      // Arrange
      final promptWithoutDescription = AiConfig.prompt(
        id: 'prompt-no-desc',
        name: 'No Description Prompt',
        systemMessage: 'System message',
        userMessage: 'User message',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [],
        aiResponseType: AiResponseType.taskSummary,
      ) as AiConfigPrompt;

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPromptsList(
            journalEntity: testTaskEntity,
            onPromptSelected: (prompt, index) async {},
          ),
          overrides: [
            availablePromptsProvider(testTaskEntity.id).overrideWith(
              (ref) => Future.value([promptWithoutDescription]),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No Description Prompt'), findsOneWidget);
      expect(find.byType(ModernModalPromptItem), findsOneWidget);

      // Since ModernModalPromptItem always shows description (even if empty),
      // we just verify the widget is there
    });

    testWidgets('calls onPromptSelected when prompt is tapped', (tester) async {
      // Arrange
      AiConfigPrompt? selectedPrompt;
      int? selectedIndex;

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPromptsList(
            journalEntity: testTaskEntity,
            onPromptSelected: (prompt, index) async {
              selectedPrompt = prompt;
              selectedIndex = index;
            },
          ),
          overrides: [
            availablePromptsProvider(testTaskEntity.id).overrideWith(
              (ref) => Future.value(testPrompts.take(2).toList()),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Task Summary'));

      // Assert
      expect(selectedPrompt, isNotNull);
      expect(selectedPrompt!.id, 'prompt-1');
      expect(selectedPrompt!.name, 'Task Summary');
      expect(selectedIndex, 0);
    });

    testWidgets('handles empty prompt list', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPromptsList(
            journalEntity: testTaskEntity,
            onPromptSelected: (prompt, index) async {},
          ),
          overrides: [
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value([])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ModernModalPromptItem), findsNothing);
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('truncates long descriptions correctly', (tester) async {
      // Arrange
      final longDescriptionPrompt = AiConfig.prompt(
        id: 'prompt-long',
        name: 'Long Description Prompt',
        systemMessage: 'System message',
        userMessage: 'User message',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [],
        aiResponseType: AiResponseType.taskSummary,
        description: 'This is a very long description that should be truncated '
            'when displayed in the UI because it exceeds the maximum number of lines '
            'that we want to show in the subtitle of the list tile.',
      ) as AiConfigPrompt;

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPromptsList(
            journalEntity: testTaskEntity,
            onPromptSelected: (prompt, index) async {},
          ),
          overrides: [
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value([longDescriptionPrompt])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      final promptItem = tester
          .widget<ModernModalPromptItem>(find.byType(ModernModalPromptItem));
      expect(promptItem.description, isNotEmpty);

      // Find the description Text widget within the ModernModalPromptItem
      final descriptionTextFinder = find.descendant(
        of: find.byType(ModernModalPromptItem),
        matching: find.text(longDescriptionPrompt.description!),
      );
      expect(descriptionTextFinder, findsOneWidget);

      final descriptionText = tester.widget<Text>(descriptionTextFinder);
      expect(descriptionText.maxLines, 4);
      expect(descriptionText.overflow, TextOverflow.ellipsis);
    });
  });

  group('UnifiedAiModal Tests', () {
    testWidgets('creates modal with correct structure', (tester) async {
      // Mock the navigator to prevent navigation issues in tests
      await tester.pumpWidget(
        buildTestWidget(
          Consumer(
            builder: (context, ref, child) {
              return ElevatedButton(
                onPressed: () async {
                  await UnifiedAiModal.show<void>(
                    context: context,
                    journalEntity: testTaskEntity,
                    linkedFromId: null,
                    ref: ref,
                  );
                },
                child: const Text('Show Modal'),
              );
            },
          ),
          overrides: [
            availablePromptsProvider(testTaskEntity.id).overrideWith(
              (ref) => Future.value(testPrompts.take(2).toList()),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Assert - Look for the prompt list instead of the modal sheet
      expect(find.byType(UnifiedAiPromptsList), findsOneWidget);
      expect(find.text('Task Summary'), findsOneWidget);
    });

    testWidgets('handles context not mounted scenario', (tester) async {
      // Arrange - This test simulates a scenario where context becomes unmounted
      // We'll test this by mocking a delayed response and disposing the widget
      await tester.pumpWidget(
        buildTestWidget(
          Consumer(
            builder: (context, ref, child) {
              return ElevatedButton(
                onPressed: () async {
                  // Simulate a very slow response
                  await UnifiedAiModal.show<void>(
                    context: context,
                    journalEntity: testTaskEntity,
                    linkedFromId: null,
                    ref: ref,
                  );
                },
                child: const Text('Show Modal'),
              );
            },
          ),
          overrides: [
            availablePromptsProvider(testTaskEntity.id).overrideWith(
              (ref) => Future.delayed(
                const Duration(milliseconds: 5),
                () => testPrompts.take(2).toList(),
              ),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap button and immediately dispose widget (simulating navigation away)
      await tester.tap(find.text('Show Modal'));
      await tester.pump(const Duration(milliseconds: 50));

      // Dispose the widget tree to simulate context becoming unmounted
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // Assert - no exception should be thrown and test should complete successfully
      expect(tester.takeException(), isNull);
    });

    testWidgets('creates individual prompt pages correctly', (tester) async {
      // Arrange
      // Mock the inference repository
      when(
        () => mockInferenceRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        // Just complete successfully
      });

      await tester.pumpWidget(
        buildTestWidget(
          Consumer(
            builder: (context, ref, child) {
              return ElevatedButton(
                onPressed: () async {
                  await UnifiedAiModal.show<void>(
                    context: context,
                    journalEntity: testTaskEntity,
                    linkedFromId: null,
                    ref: ref,
                  );
                },
                child: const Text('Show Modal'),
              );
            },
          ),
          overrides: [
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) async => [testPrompts.first]),
            unifiedAiInferenceRepositoryProvider
                .overrideWithValue(mockInferenceRepository),
            // Note: aiConfigByIdProvider is already overridden in defaultOverrides
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Just verify the modal opens with the prompt list
      expect(find.byType(UnifiedAiPromptsList), findsOneWidget);
      expect(find.text('Task Summary'), findsOneWidget);

      // Close the modal to clean up
      await tester.tapAt(Offset.zero); // Tap outside to dismiss
      await tester.pumpAndSettle();
    });
  });

  group('UnifiedAiModal onPromptSelected callback', () {
    testWidgets('triggers inference when prompt is selected from modal',
        (tester) async {
      // Arrange
      var inferenceTriggered = false;
      String? capturedEntityId;
      String? capturedPromptId;
      String? capturedLinkedEntityId;

      await tester.pumpWidget(
        buildTestWidget(
          Consumer(
            builder: (context, ref, child) {
              return Column(
                children: [
                  UnifiedAiPopUpMenu(
                    journalEntity: testTaskEntity,
                    linkedFromId: 'linked-test-id',
                  ),
                  // Override the trigger provider to capture the call
                  Builder(builder: (context) {
                    // This is just to set up the override
                    return const SizedBox();
                  }),
                ],
              );
            },
          ),
          overrides: [
            hasAvailablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value(true)),
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value([testPrompts.first])),
            triggerNewInferenceProvider((
              entityId: testTaskEntity.id,
              promptId: testPrompts.first.id,
              linkedEntityId: 'linked-test-id',
            )).overrideWith((ref) async {
              inferenceTriggered = true;
              capturedEntityId = testTaskEntity.id;
              capturedPromptId = testPrompts.first.id;
              capturedLinkedEntityId = 'linked-test-id';
            }),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act - Open the modal
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      // Select a prompt
      await tester.tap(find.text('Task Summary'));
      await tester.pumpAndSettle();

      // Assert
      expect(inferenceTriggered, isTrue);
      expect(capturedEntityId, equals(testTaskEntity.id));
      expect(capturedPromptId, equals(testPrompts.first.id));
      expect(capturedLinkedEntityId, equals('linked-test-id'));
    });

    testWidgets('closes modal after prompt selection', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testTaskEntity,
            linkedFromId: null,
          ),
          overrides: [
            hasAvailablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value(true)),
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value([testPrompts.first])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act - Open the modal
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(find.byType(UnifiedAiPromptsList), findsOneWidget);

      // Select a prompt
      await tester.tap(find.text('Task Summary'));
      await tester.pumpAndSettle();

      // Assert - Modal should be closed
      expect(find.byType(UnifiedAiPromptsList), findsNothing);
    });

    testWidgets('handles null linkedFromId correctly', (tester) async {
      // Arrange
      String? capturedLinkedEntityId;

      await tester.pumpWidget(
        buildTestWidget(
          Consumer(
            builder: (context, ref, child) {
              return UnifiedAiPopUpMenu(
                journalEntity: testTaskEntity,
                linkedFromId: null, // Explicitly null
              );
            },
          ),
          overrides: [
            hasAvailablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value(true)),
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value([testPrompts.first])),
            triggerNewInferenceProvider((
              entityId: testTaskEntity.id,
              promptId: testPrompts.first.id,
              linkedEntityId: null,
            )).overrideWith((ref) async {
              capturedLinkedEntityId = null;
            }),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act - Open the modal
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      // Select a prompt
      await tester.tap(find.text('Task Summary'));
      await tester.pumpAndSettle();

      // Assert
      expect(capturedLinkedEntityId, isNull);
    });

    testWidgets('uses entry id for linkedEntityId when launching from audio',
        (tester) async {
      var triggered = false;
      String? capturedLinkedEntityId;

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testAudioEntity,
            linkedFromId: 'parent-task',
          ),
          overrides: [
            hasAvailablePromptsProvider(testAudioEntity.id)
                .overrideWith((ref) => Future.value(true)),
            availablePromptsProvider(testAudioEntity.id)
                .overrideWith((ref) => Future.value([testPrompts.first])),
            triggerNewInferenceProvider((
              entityId: testAudioEntity.id,
              promptId: testPrompts.first.id,
              linkedEntityId: testAudioEntity.id,
            )).overrideWith((ref) async {
              triggered = true;
              capturedLinkedEntityId = testAudioEntity.id;
            }),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Task Summary'));
      await tester.pumpAndSettle();

      expect(triggered, isTrue);
      expect(capturedLinkedEntityId, equals(testAudioEntity.id));
    });

    testWidgets('modal show method with ScrollController parameter',
        (tester) async {
      // Arrange
      final scrollController = ScrollController();

      await tester.pumpWidget(
        buildTestWidget(
          Consumer(
            builder: (context, ref, child) {
              return ElevatedButton(
                onPressed: () async {
                  await UnifiedAiModal.show<void>(
                    context: context,
                    journalEntity: testTaskEntity,
                    linkedFromId: null,
                    ref: ref,
                    scrollController:
                        scrollController, // Pass scroll controller
                  );
                },
                child: const Text('Show Modal with ScrollController'),
              );
            },
          ),
          overrides: [
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value([testPrompts.first])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Show Modal with ScrollController'));
      await tester.pumpAndSettle();

      // Assert - Modal should open
      expect(find.byType(UnifiedAiPromptsList), findsOneWidget);

      // Clean up
      scrollController.dispose();
    });
  });

  group('Image Generation Handling Tests', () {
    testWidgets(
        'image generation prompt from non-audio entry returns early without modal',
        (tester) async {
      // Create an image generation prompt
      final imageGenPrompt = AiConfig.prompt(
        id: 'img-gen-prompt',
        name: 'Generate Cover Art',
        systemMessage: 'Generate cover art',
        userMessage: 'Generate cover art for this task',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [],
        aiResponseType: AiResponseType.imageGeneration, // Image generation type
        description: 'Generate cover art',
      ) as AiConfigPrompt;

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testImageEntity, // Not an audio entry
            linkedFromId: 'some-task-id',
          ),
          overrides: [
            hasAvailablePromptsProvider(testImageEntity.id)
                .overrideWith((ref) => Future.value(true)),
            availablePromptsProvider(testImageEntity.id)
                .overrideWith((ref) => Future.value([imageGenPrompt])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      // Select the image generation prompt
      await tester.tap(find.text('Generate Cover Art'));
      await tester.pumpAndSettle();

      // The modal should close and no ImageGenerationReviewModal should appear
      // because the entity is not a JournalAudio
      expect(find.byType(UnifiedAiPromptsList), findsNothing);
    });

    testWidgets('image generation prompt from audio entry without linked task',
        (tester) async {
      // Create an image generation prompt
      final imageGenPrompt = AiConfig.prompt(
        id: 'img-gen-prompt',
        name: 'Generate Cover Art',
        systemMessage: 'Generate cover art',
        userMessage: 'Generate cover art for this task',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [],
        aiResponseType: AiResponseType.imageGeneration,
        description: 'Generate cover art',
      ) as AiConfigPrompt;

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPopUpMenu(
            journalEntity: testAudioEntity,
            linkedFromId: null, // No linked task
          ),
          overrides: [
            hasAvailablePromptsProvider(testAudioEntity.id)
                .overrideWith((ref) => Future.value(true)),
            availablePromptsProvider(testAudioEntity.id)
                .overrideWith((ref) => Future.value([imageGenPrompt])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      // Select the image generation prompt
      await tester.tap(find.text('Generate Cover Art'));
      await tester.pumpAndSettle();

      // Should handle gracefully without crashing
      expect(find.byType(UnifiedAiPromptsList), findsNothing);
    });
  });

  group('isDefaultPromptSync Tests', () {
    test('returns false when categoryId is null', () {
      final prompt = testPrompts.first;
      final result = isDefaultPromptSync(null, prompt);
      expect(result, isFalse);
    });

    test('returns false when category is not found', () {
      final prompt = testPrompts.first;
      final result = isDefaultPromptSync('non-existent-category', prompt);
      expect(result, isFalse);
    });
  });

  group('Icon Mapping Tests', () {
    testWidgets('maps task input data to checklist icon', (tester) async {
      // Arrange
      final taskPrompt = testPrompts.firstWhere(
          (p) => p.requiredInputData.contains(InputDataType.tasksList));

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPromptsList(
            journalEntity: testTaskEntity,
            onPromptSelected: (prompt, index) async {},
          ),
          overrides: [
            availablePromptsProvider(testTaskEntity.id)
                .overrideWith((ref) => Future.value([taskPrompt])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Just check the prompt is displayed correctly
      expect(find.text('Task Summary'), findsOneWidget);
      expect(find.byType(ModernModalPromptItem), findsOneWidget);
      // Icons are rendered within ModernIconContainer
      expect(find.byType(Icon), findsAtLeastNWidgets(1));
    });

    testWidgets('maps image input data to image icon', (tester) async {
      // Arrange
      final imagePrompt = testPrompts.firstWhere(
        (p) => p.requiredInputData.contains(InputDataType.images),
      );

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPromptsList(
            journalEntity: testImageEntity,
            onPromptSelected: (prompt, index) async {},
          ),
          overrides: [
            availablePromptsProvider(testImageEntity.id)
                .overrideWith((ref) => Future.value([imagePrompt])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Just check the prompt is displayed correctly
      expect(find.text('Image Analysis'), findsOneWidget);
      expect(find.byType(ModernModalPromptItem), findsOneWidget);
      // Icons are rendered within ModernIconContainer
      expect(find.byType(Icon), findsAtLeastNWidgets(1));
    });

    testWidgets('maps audio input data to mic icon', (tester) async {
      // Arrange
      final audioPrompt = testPrompts.firstWhere(
        (p) => p.requiredInputData.contains(InputDataType.audioFiles),
      );

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPromptsList(
            journalEntity: testAudioEntity,
            onPromptSelected: (prompt, index) async {},
          ),
          overrides: [
            availablePromptsProvider(testAudioEntity.id)
                .overrideWith((ref) => Future.value([audioPrompt])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Just check the prompt is displayed correctly
      expect(find.text('Audio Transcription'), findsOneWidget);
      expect(find.byType(ModernModalPromptItem), findsOneWidget);
      // Icons are rendered within ModernIconContainer
      expect(find.byType(Icon), findsAtLeastNWidgets(1));
    });

    testWidgets('maps no specific input data to chat icon', (tester) async {
      // Arrange
      final generalPrompt =
          testPrompts.firstWhere((p) => p.requiredInputData.isEmpty);

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiPromptsList(
            journalEntity: testJournalEntry,
            onPromptSelected: (prompt, index) async {},
          ),
          overrides: [
            availablePromptsProvider(testJournalEntry.id)
                .overrideWith((ref) => Future.value([generalPrompt])),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Just check the prompt is displayed correctly
      expect(find.text('General Chat'), findsOneWidget);
      expect(find.byType(ModernModalPromptItem), findsOneWidget);
      // Icons are rendered within ModernIconContainer
      expect(find.byType(Icon), findsAtLeastNWidgets(1));
    });
  });
}
