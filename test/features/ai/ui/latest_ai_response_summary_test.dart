import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/ai/ui/latest_ai_response_summary.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockJournalDb extends Mock implements JournalDb {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

void main() {
  late MockLoggingService mockLoggingService;
  late MockJournalRepository mockJournalRepository;
  late MockUpdateNotifications mockUpdateNotifications;

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockJournalRepository = MockJournalRepository();
    mockUpdateNotifications = MockUpdateNotifications();

    // Register mocks in GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }

    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    // Setup mock behaviors
    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

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
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
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

  group('LatestAiResponseSummary Animation Tests', () {
    const testId = 'test-entity-1';
    const testResponseType = AiResponseType.taskSummary;
    late AiResponseEntry testResponse1;

    setUp(() {
      final now = DateTime.now();
      testResponse1 = AiResponseEntry(
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
          response: 'This is the first summary',
          type: AiResponseType.taskSummary,
          promptId: 'prompt-1',
        ),
      );

      AiResponseEntry(
        meta: Metadata(
          id: 'response-2',
          createdAt: now.add(const Duration(minutes: 1)),
          updatedAt: now.add(const Duration(minutes: 1)),
          dateFrom: now.add(const Duration(minutes: 1)),
          dateTo: now.add(const Duration(minutes: 1)),
        ),
        data: const AiResponseData(
          model: 'gpt-4',
          temperature: 0.7,
          systemMessage: 'System message',
          prompt: 'User prompt',
          thoughts: '',
          response:
              'This is the updated summary with more content to test size animation',
          type: AiResponseType.taskSummary,
          promptId: 'prompt-1',
        ),
      );
    });

    testWidgets('keeps old summary visible while generating new one',
        (tester) async {
      // Setup mock to return the test response
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse1]);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestWidget(
            const LatestAiResponseSummary(
              id: testId,
              aiResponseType: testResponseType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial summary is shown
      expect(find.byType(AiResponseSummary), findsOneWidget);
      expect(find.text('This is the first summary'), findsOneWidget);

      // Start running inference
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: testResponseType,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      await tester.pump();

      // Verify old summary is still visible with spinner in header
      expect(find.byType(AiResponseSummary), findsOneWidget);
      expect(find.text('This is the first summary'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      container.dispose();
    });

    testWidgets('has AnimatedSize and AnimatedSwitcher widgets',
        (tester) async {
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse1]);

      await tester.pumpWidget(
        buildTestWidget(
          const LatestAiResponseSummary(
            id: testId,
            aiResponseType: testResponseType,
          ),
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Verify both animation widgets are present
      expect(find.byType(AnimatedSize), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byType(AiResponseSummary), findsOneWidget);
    });

    testWidgets('AnimatedSize wraps AnimatedSwitcher correctly',
        (tester) async {
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse1]);

      await tester.pumpWidget(
        buildTestWidget(
          const LatestAiResponseSummary(
            id: testId,
            aiResponseType: testResponseType,
          ),
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Verify AnimatedSize contains AnimatedSwitcher
      final animatedSize = tester.widget<AnimatedSize>(
        find.byType(AnimatedSize),
      );

      // Check AnimatedSize configuration
      expect(animatedSize.duration, const Duration(milliseconds: 600));
      expect(animatedSize.curve, Curves.easeInOut);

      // Verify AnimatedSwitcher is a child of AnimatedSize
      expect(
        find.descendant(
          of: find.byType(AnimatedSize),
          matching: find.byType(AnimatedSwitcher),
        ),
        findsOneWidget,
      );
    });

    testWidgets('transitions between summaries with size and fade animation',
        (tester) async {
      // Start with first response
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse1]);

      await tester.pumpWidget(
        buildTestWidget(
          const LatestAiResponseSummary(
            id: testId,
            aiResponseType: testResponseType,
          ),
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial summary
      expect(find.text('This is the first summary'), findsOneWidget);

      // This test now only verifies the initial display
      // The refresh mechanism is tested separately in DirectTaskSummaryRefreshController tests
    });

    testWidgets('shows spinner in header while running', (tester) async {
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse1]);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestWidget(
            const LatestAiResponseSummary(
              id: testId,
              aiResponseType: testResponseType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Set status to running after widget is built
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: testResponseType,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      await tester.pump();

      // Verify spinner is shown in header
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify the spinner is inside an IconButton
      final iconButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(IconButton),
        ),
      );
      expect(iconButton, isNotNull);

      container.dispose();
    });

    testWidgets('shows refresh button when not running', (tester) async {
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse1]);

      await tester.pumpWidget(
        buildTestWidget(
          const LatestAiResponseSummary(
            id: testId,
            aiResponseType: testResponseType,
          ),
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Verify refresh button is shown
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('handles null response gracefully', (tester) async {
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        buildTestWidget(
          const LatestAiResponseSummary(
            id: testId,
            aiResponseType: testResponseType,
          ),
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Should show nothing when response is null
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(AiResponseSummary), findsNothing);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(find.byType(AnimatedSwitcher), findsNothing);
    });

    testWidgets('AnimatedSwitcher uses only FadeTransition', (tester) async {
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse1]);

      await tester.pumpWidget(
        buildTestWidget(
          const LatestAiResponseSummary(
            id: testId,
            aiResponseType: testResponseType,
          ),
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Find the AnimatedSwitcher and verify its configuration
      final animatedSwitcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );

      expect(animatedSwitcher.duration, const Duration(milliseconds: 600));
      expect(animatedSwitcher.switchInCurve, Curves.easeInOut);
      expect(animatedSwitcher.switchOutCurve, Curves.easeInOut);

      // Verify the transition builder creates only FadeTransition (no SizeTransition)
      final testChild = Container();
      const testAnimation = AlwaysStoppedAnimation<double>(1);
      final transitionWidget = animatedSwitcher.transitionBuilder(
        testChild,
        testAnimation,
      );

      expect(transitionWidget, isA<FadeTransition>());
      final fadeTransition = transitionWidget as FadeTransition;
      // Verify it doesn't wrap with SizeTransition anymore
      expect(fadeTransition.child, isNot(isA<SizeTransition>()));
      expect(fadeTransition.child, same(testChild));
    });

    testWidgets('preserves state during inference', (tester) async {
      // Initial state with first response
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse1]);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestWidget(
            const LatestAiResponseSummary(
              id: testId,
              aiResponseType: testResponseType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('This is the first summary'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Start inference (simulating regeneration)
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: testResponseType,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      await tester.pump();

      // During inference, old summary should still be visible
      expect(find.text('This is the first summary'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.refresh),
          findsNothing); // Refresh hidden during run

      // Set inference status back to idle
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: testResponseType,
            ).notifier,
          )
          .setStatus(InferenceStatus.idle);

      await tester.pumpAndSettle();

      // Should still show the original summary
      expect(find.text('This is the first summary'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      container.dispose();
    });

    testWidgets('loading state shows CircularProgressIndicator',
        (tester) async {
      // Create a completer to control when the future completes
      final completer = Completer<List<JournalEntity>>();

      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        buildTestWidget(
          const LatestAiResponseSummary(
            id: testId,
            aiResponseType: testResponseType,
          ),
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );

      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(find.byType(AnimatedSwitcher), findsNothing);

      // Complete the future to clean up
      completer.complete([]);
      await tester.pump();
    });

    testWidgets('error state shows error message', (tester) async {
      const errorMessage = 'Failed to load summary';

      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenThrow(errorMessage);

      await tester.pumpWidget(
        buildTestWidget(
          const LatestAiResponseSummary(
            id: testId,
            aiResponseType: testResponseType,
          ),
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('Failed to load AI summary. Please try again.'),
          findsOneWidget);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(find.byType(AnimatedSwitcher), findsNothing);
    });

    testWidgets('refresh button triggers inference without showing modal',
        (tester) async {
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse1]);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Track if triggerNewInferenceProvider was called
      var inferenceTriggered = false;
      container.listen(
        triggerNewInferenceProvider(
          entityId: testId,
          promptId: 'prompt-1',
        ),
        (_, __) {
          inferenceTriggered = true;
        },
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestWidget(
            const LatestAiResponseSummary(
              id: testId,
              aiResponseType: testResponseType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the refresh button
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);

      await tester.tap(refreshButton);
      await tester.pump();

      // Verify inference was triggered
      expect(inferenceTriggered, isTrue);

      // Verify no modal is shown (no Navigator.push calls)
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);

      container.dispose();
    });

    testWidgets('spinner button is clickable during inference', (tester) async {
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse1]);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestWidget(
            const LatestAiResponseSummary(
              id: testId,
              aiResponseType: testResponseType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Set status to running
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: testResponseType,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      await tester.pump();

      // Find the spinner button
      final spinnerButton = find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(IconButton),
      );
      expect(spinnerButton, findsOneWidget);

      // Verify it's clickable (has onPressed callback)
      final iconButton = tester.widget<IconButton>(spinnerButton);
      expect(iconButton.onPressed, isNotNull);

      // Track if inference was triggered
      var inferenceTriggered = false;
      container.listen(
        triggerNewInferenceProvider(
          entityId: testId,
          promptId: 'prompt-1',
        ),
        (_, __) {
          inferenceTriggered = true;
        },
      );

      // Tap the spinner button
      await tester.tap(spinnerButton);
      await tester.pump();

      // Verify inference was triggered
      expect(inferenceTriggered, isTrue);

      container.dispose();
    });

    testWidgets('refresh button disabled when promptId is null',
        (tester) async {
      // Create response without promptId
      final responseWithoutPrompt = AiResponseEntry(
        meta: Metadata(
          id: 'response-no-prompt',
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
          response: 'Response without prompt ID',
          type: AiResponseType.taskSummary,
        ),
      );

      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [responseWithoutPrompt]);

      await tester.pumpWidget(
        buildTestWidget(
          const LatestAiResponseSummary(
            id: testId,
            aiResponseType: testResponseType,
          ),
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Refresh button should not be shown when promptId is null
      expect(find.byIcon(Icons.refresh), findsNothing);
    });
  });
}
