import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
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
    ).thenReturn(null);
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

  group('LatestAiResponseSummary Animation Tests', () {
    const testId = 'test-entity-1';
    const testResponseType = AiResponseType.taskSummary;
    late AiResponseEntry testResponse1;
    late AiResponseEntry testResponse2;

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

      testResponse2 = AiResponseEntry(
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

      // Update mock to return new response
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse2]);

      // Trigger update by sending notification
      updateStreamController.add({aiResponseNotification, testId});

      // Wait a bit for the stream to process
      await tester.pump(const Duration(milliseconds: 100));

      // Complete the animation
      await tester.pumpAndSettle();

      // Verify new summary is shown
      expect(
        find.text(
            'This is the updated summary with more content to test size animation'),
        findsOneWidget,
      );

      // Verify AnimatedSize is still present
      expect(find.byType(AnimatedSize), findsOneWidget);
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

      // Complete inference with new response
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: testId))
          .thenAnswer((_) async => [testResponse2]);

      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: testResponseType,
            ).notifier,
          )
          .setStatus(InferenceStatus.idle);

      // Trigger update
      updateStreamController.add({aiResponseNotification, testId});

      await tester.pumpAndSettle();

      // New summary should be shown
      expect(
        find.text(
            'This is the updated summary with more content to test size animation'),
        findsOneWidget,
      );
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
      expect(
          find.text('Error loading AI summary: $errorMessage'), findsOneWidget);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(find.byType(AnimatedSwitcher), findsNothing);
    });
  });
}
