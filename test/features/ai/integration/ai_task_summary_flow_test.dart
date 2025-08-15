import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/latest_ai_response_summary.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockJournalRepository extends Mock implements JournalRepository {}

void main() {
  late MockLoggingService mockLoggingService;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockJournalRepository mockJournalRepository;
  late StreamController<Set<String>> updateStreamController;

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockUpdateNotifications = MockUpdateNotifications();
    mockJournalRepository = MockJournalRepository();
    updateStreamController = StreamController<Set<String>>.broadcast();

    // Register mocks in GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }

    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    // Setup mock behaviors
    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

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
    ).thenAnswer((_) {
      // Suppress stack trace logging in tests
    });
  });

  tearDown(() {
    updateStreamController.close();
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
  });

  Widget buildTestWidget(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('AI Task Summary Flow Integration Tests', () {
    const testTaskId = 'test-task-1';
    const testPromptId = 'prompt-1';
    const testResponseType = AiResponseType.taskSummary;
    late AiResponseEntry testResponse;

    setUp(() {
      final now = DateTime.now();

      testResponse = AiResponseEntry(
        meta: Metadata(
          id: 'response-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: const AiResponseData(
          model: 'gpt-4',
          temperature: 0.7,
          systemMessage: 'System message',
          prompt: 'User prompt',
          thoughts: '',
          response: 'This is the task summary',
          type: AiResponseType.taskSummary,
          promptId: testPromptId,
        ),
      );
    });

    testWidgets(
        'complete flow: refresh button → inference → animation → completion',
        (tester) async {
      // Setup mock to return the AI response
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testTaskId))
          .thenAnswer((_) async => [testResponse]);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Track inference triggering
      final inferenceTriggered = ValueNotifier(false);

      container.listen(
        triggerNewInferenceProvider(
          entityId: testTaskId,
          promptId: testPromptId,
        ),
        (previous, next) {
          inferenceTriggered.value = true;
        },
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestWidget(
            const Column(
              children: [
                Expanded(
                  child: LatestAiResponseSummary(
                    id: testTaskId,
                    aiResponseType: testResponseType,
                  ),
                ),
                AiRunningAnimationWrapperCard(
                  entryId: testTaskId,
                  height: 50,
                  responseTypes: {AiResponseType.taskSummary},
                  isInteractive: true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state: summary shown with refresh button
      expect(find.text('This is the task summary'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byType(AiRunningAnimation), findsNothing);

      // Tap refresh button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Verify inference was triggered
      expect(inferenceTriggered.value, isTrue);

      // Simulate inference running
      container
          .read(
            inferenceStatusControllerProvider(
              id: testTaskId,
              aiResponseType: testResponseType,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      await tester.pump();

      // Verify running state: spinner in header, animation at bottom
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing); // Hidden during run

      // Simulate inference completion with new response
      final updatedResponse = AiResponseEntry(
        meta: Metadata(
          id: 'response-2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const AiResponseData(
          model: 'gpt-4',
          temperature: 0.7,
          systemMessage: 'System message',
          prompt: 'User prompt',
          thoughts: '',
          response: 'This is the updated task summary with new content',
          type: AiResponseType.taskSummary,
          promptId: testPromptId,
        ),
      );

      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testTaskId))
          .thenAnswer((_) async => [updatedResponse]);

      container
          .read(
            inferenceStatusControllerProvider(
              id: testTaskId,
              aiResponseType: testResponseType,
            ).notifier,
          )
          .setStatus(InferenceStatus.idle);

      // Trigger update notification
      updateStreamController.add({aiResponseNotification, testTaskId});

      await tester.pumpAndSettle();

      // Verify completion state: new summary shown, animation hidden
      expect(find.text('This is the updated task summary with new content'),
          findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AiRunningAnimation), findsNothing);

      container.dispose();
    });

    testWidgets('animation interaction during inference', (tester) async {
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testTaskId))
          .thenAnswer((_) async => [testResponse]);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestWidget(
            const Column(
              children: [
                Expanded(
                  child: LatestAiResponseSummary(
                    id: testTaskId,
                    aiResponseType: testResponseType,
                  ),
                ),
                AiRunningAnimationWrapperCard(
                  entryId: testTaskId,
                  height: 50,
                  responseTypes: {AiResponseType.taskSummary},
                  isInteractive: true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger inference
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Set status to running
      container
          .read(
            inferenceStatusControllerProvider(
              id: testTaskId,
              aiResponseType: testResponseType,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      await tester.pump();

      // Verify animation is shown and interactive
      expect(find.byType(AiRunningAnimation), findsOneWidget);

      // Find the GestureDetector that's a parent of AiRunningAnimation
      final gestureDetector = find.ancestor(
        of: find.byType(AiRunningAnimation),
        matching: find.byType(GestureDetector),
      );
      expect(gestureDetector, findsOneWidget);

      // Verify the animation wrapper has the correct properties
      final animationWrapper = tester.widget<AiRunningAnimationWrapper>(
        find.byType(AiRunningAnimationWrapper),
      );
      expect(animationWrapper.isInteractive, isTrue);
      expect(
          animationWrapper.responseTypes.contains(AiResponseType.taskSummary),
          isTrue);

      container.dispose();
    });

    testWidgets('handles multiple simultaneous inferences', (tester) async {
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testTaskId))
          .thenAnswer((_) async => [testResponse]);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestWidget(
            const Column(
              children: [
                Expanded(
                  child: LatestAiResponseSummary(
                    id: testTaskId,
                    aiResponseType: testResponseType,
                  ),
                ),
                AiRunningAnimationWrapperCard(
                  entryId: testTaskId,
                  height: 50,
                  responseTypes: {
                    AiResponseType.taskSummary,
                    AiResponseType.checklistUpdates,
                  },
                  isInteractive: true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Simulate multiple inferences running
      container
          .read(
            inferenceStatusControllerProvider(
              id: testTaskId,
              aiResponseType: AiResponseType.taskSummary,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      container
          .read(
            inferenceStatusControllerProvider(
              id: testTaskId,
              aiResponseType: AiResponseType.checklistUpdates,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      await tester.pump();

      // Animation should be shown when any inference is running
      expect(find.byType(AiRunningAnimation), findsOneWidget);

      // Complete one inference
      container
          .read(
            inferenceStatusControllerProvider(
              id: testTaskId,
              aiResponseType: AiResponseType.taskSummary,
            ).notifier,
          )
          .setStatus(InferenceStatus.idle);

      await tester.pump();

      // Animation should still be shown as other inference is running
      expect(find.byType(AiRunningAnimation), findsOneWidget);

      // Complete all inferences
      container
          .read(
            inferenceStatusControllerProvider(
              id: testTaskId,
              aiResponseType: AiResponseType.checklistUpdates,
            ).notifier,
          )
          .setStatus(InferenceStatus.idle);

      await tester.pump();

      // Animation should be hidden when all inferences complete
      expect(find.byType(AiRunningAnimation), findsNothing);

      container.dispose();
    });
  });
}
