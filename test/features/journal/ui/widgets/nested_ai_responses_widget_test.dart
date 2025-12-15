// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/ui/widgets/nested_ai_responses_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockLoggingService extends Mock implements LoggingService {}

// Test data
final testAudioEntry = JournalAudio(
  meta: Metadata(
    id: 'audio-entry-123',
    createdAt: DateTime(2024, 1, 15, 10),
    dateFrom: DateTime(2024, 1, 15, 10),
    dateTo: DateTime(2024, 1, 15, 10, 5),
    updatedAt: DateTime(2024, 1, 15, 10, 5),
  ),
  data: AudioData(
    dateFrom: DateTime(2024, 1, 15, 10),
    dateTo: DateTime(2024, 1, 15, 10, 5),
    duration: const Duration(minutes: 5),
    audioFile: 'test.aac',
    audioDirectory: '/test/',
  ),
);

final testAiResponseEntry1 = AiResponseEntry(
  meta: Metadata(
    id: 'ai-response-1',
    createdAt: DateTime(2024, 1, 15, 10),
    dateFrom: DateTime(2024, 1, 15, 10),
    dateTo: DateTime(2024, 1, 15, 10, 5),
    updatedAt: DateTime(2024, 1, 15, 10, 5),
  ),
  data: const AiResponseData(
    model: 'test-model',
    systemMessage: 'System message',
    prompt: 'Test prompt',
    thoughts: 'Test thoughts',
    response:
        '## Summary\nTest summary for coding prompt\n\n## Prompt\nTest prompt content here',
    type: AiResponseType.promptGeneration,
  ),
);

final testAiResponseEntry2 = AiResponseEntry(
  meta: Metadata(
    id: 'ai-response-2',
    createdAt: DateTime(2024, 1, 15, 11),
    dateFrom: DateTime(2024, 1, 15, 11),
    dateTo: DateTime(2024, 1, 15, 11, 5),
    updatedAt: DateTime(2024, 1, 15, 11, 5),
  ),
  data: const AiResponseData(
    model: 'test-model',
    systemMessage: 'System message 2',
    prompt: 'Test prompt 2',
    thoughts: 'Test thoughts 2',
    response: 'This is an audio transcription result.',
    type: AiResponseType.audioTranscription,
  ),
);

void main() {
  late MockJournalRepository mockJournalRepository;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockLoggingService mockLoggingService;
  late StreamController<Set<String>> updateStreamController;

  setUp(() {
    mockJournalRepository = MockJournalRepository();
    mockUpdateNotifications = MockUpdateNotifications();
    mockLoggingService = MockLoggingService();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    getIt.allowReassignment = true;
    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);
    getIt.registerSingleton<LoggingService>(mockLoggingService);
  });

  tearDown(() {
    updateStreamController.close();
    getIt.unregister<UpdateNotifications>();
    getIt.unregister<LoggingService>();
  });

  /// Helper to set up common test data and mocks for a single AI response
  void setupSingleAiResponse() {
    final links = [
      EntryLink.basic(
        id: 'link-1',
        fromId: testAudioEntry.meta.id,
        toId: testAiResponseEntry1.meta.id,
        createdAt: DateTime(2024, 1, 15, 10),
        updatedAt: DateTime(2024, 1, 15, 10),
        vectorClock: null,
      ),
    ];

    when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
        .thenAnswer((_) async => links);
    when(() => mockJournalRepository.getJournalEntityById(
          testAiResponseEntry1.meta.id,
        )).thenAnswer((_) async => testAiResponseEntry1);
  }

  /// Helper to pump the widget under test
  Future<void> pumpWidget(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        NestedAiResponsesWidget(
          parentEntryId: testAudioEntry.meta.id,
          linkedFromEntity: testAudioEntry,
        ),
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  group('NestedAiResponsesWidget Rendering', () {
    testWidgets('shows nothing while loading', (tester) async {
      // Arrange - use a completer to keep the provider in loading state
      final completer = Completer<List<EntryLink>>();

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          NestedAiResponsesWidget(
            parentEntryId: testAudioEntry.meta.id,
            linkedFromEntity: testAudioEntry,
          ),
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );

      // Should not show header during loading
      expect(
        find.byKey(NestedAiResponsesWidget.headerKey),
        findsNothing,
      );
    });

    testWidgets('shows nothing when AI responses list is empty',
        (tester) async {
      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => []);

      await pumpWidget(tester);

      expect(
        find.byKey(NestedAiResponsesWidget.headerKey),
        findsNothing,
      );
    });

    testWidgets('shows nothing on initial error state', (tester) async {
      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenThrow(Exception('Database error'));

      await pumpWidget(tester);

      expect(
        find.byKey(NestedAiResponsesWidget.headerKey),
        findsNothing,
      );
    });

    testWidgets('renders header and AI responses when data is available',
        (tester) async {
      setupSingleAiResponse();

      await pumpWidget(tester);

      // Should show header with key
      expect(
        find.byKey(NestedAiResponsesWidget.headerKey),
        findsOneWidget,
      );
      // Should show the AI icon in header
      expect(
          find.byIcon(Icons.auto_fix_high_outlined), findsAtLeastNWidgets(1));
      // Should have Dismissible for the AI response
      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('renders multiple AI responses with correct count',
        (tester) async {
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
        EntryLink.basic(
          id: 'link-2',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry2.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry2.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry2);

      await pumpWidget(tester);

      // Should have Dismissible widgets for each AI response
      expect(find.byType(Dismissible), findsNWidgets(2));
    });
  });

  group('Expand/Collapse Behavior', () {
    testWidgets('starts expanded and collapses when header is tapped',
        (tester) async {
      setupSingleAiResponse();
      await pumpWidget(tester);

      // Verify initially expanded (SizeTransition should have value 1.0)
      final sizeTransition =
          tester.widget<SizeTransition>(find.byType(SizeTransition));
      expect(sizeTransition.sizeFactor.value, equals(1.0));

      // Tap the header to collapse using the key
      await tester.tap(find.byKey(NestedAiResponsesWidget.headerKey));
      await tester.pumpAndSettle();

      // Verify collapsed (SizeTransition should have value 0.0)
      final collapsedSizeTransition =
          tester.widget<SizeTransition>(find.byType(SizeTransition));
      expect(collapsedSizeTransition.sizeFactor.value, equals(0.0));
    });

    testWidgets('expands when header is tapped after collapse', (tester) async {
      setupSingleAiResponse();
      await pumpWidget(tester);

      final headerFinder = find.byKey(NestedAiResponsesWidget.headerKey);

      // Collapse first
      await tester.tap(headerFinder);
      await tester.pumpAndSettle();

      // Verify collapsed
      var sizeTransition =
          tester.widget<SizeTransition>(find.byType(SizeTransition));
      expect(sizeTransition.sizeFactor.value, equals(0.0));

      // Expand again
      await tester.tap(headerFinder);
      await tester.pumpAndSettle();

      // Verify expanded
      sizeTransition =
          tester.widget<SizeTransition>(find.byType(SizeTransition));
      expect(sizeTransition.sizeFactor.value, equals(1.0));
    });

    testWidgets('shows rotation animation on expand icon', (tester) async {
      setupSingleAiResponse();
      await pumpWidget(tester);

      final headerFinder = find.byKey(NestedAiResponsesWidget.headerKey);
      final rotationTransition = find.descendant(
        of: headerFinder,
        matching: find.byType(RotationTransition),
      );
      expect(rotationTransition, findsOneWidget);

      // Get initial rotation value - when expanded, value is 0.5
      final initialRotation =
          tester.widget<RotationTransition>(rotationTransition);
      expect(initialRotation.turns.value, equals(0.5));

      // Collapse
      await tester.tap(headerFinder);
      await tester.pumpAndSettle();

      // Verify rotation changed - when collapsed, value is 0.0
      final collapsedRotation =
          tester.widget<RotationTransition>(rotationTransition);
      expect(collapsedRotation.turns.value, equals(0.0));
    });
  });

  group('Delete Flow', () {
    testWidgets('shows confirmation dialog on swipe', (tester) async {
      setupSingleAiResponse();
      await pumpWidget(tester);

      // Swipe to trigger confirmation dialog
      await tester.drag(find.byType(Dismissible), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Verify AlertDialog is shown with title and content
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('cancel button dismisses dialog without deleting',
        (tester) async {
      setupSingleAiResponse();
      await pumpWidget(tester);

      // Swipe to trigger confirmation dialog
      await tester.drag(find.byType(Dismissible), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byType(AlertDialog), findsNothing);

      // Delete should NOT have been called
      verifyNever(() => mockJournalRepository.deleteJournalEntity(any()));

      // Dismissible should still exist
      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('delete button calls repository and dismisses on success',
        (tester) async {
      setupSingleAiResponse();
      when(() => mockJournalRepository.deleteJournalEntity(any()))
          .thenAnswer((_) async => true);

      await pumpWidget(tester);

      // Swipe to trigger confirmation dialog
      await tester.drag(find.byType(Dismissible), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Tap Delete button
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify delete was called with correct ID
      verify(() => mockJournalRepository.deleteJournalEntity(
            testAiResponseEntry1.meta.id,
          )).called(1);

      // Dialog should be dismissed
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('shows error snackbar when delete fails', (tester) async {
      setupSingleAiResponse();
      when(() => mockJournalRepository.deleteJournalEntity(any()))
          .thenAnswer((_) async => false);

      await pumpWidget(tester);

      // Find the specific Dismissible by key (not SnackBar's Dismissible)
      final dismissibleFinder = find.byKey(Key(testAiResponseEntry1.meta.id));

      // Swipe to trigger confirmation dialog
      await tester.drag(dismissibleFinder, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Tap Delete button
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify delete was called
      verify(() => mockJournalRepository.deleteJournalEntity(
            testAiResponseEntry1.meta.id,
          )).called(1);

      // Error snackbar should be shown
      expect(find.byType(SnackBar), findsOneWidget);

      // Our AI response Dismissible should still exist (not dismissed on failure)
      expect(dismissibleFinder, findsOneWidget);
    });

    testWidgets('shows error snackbar when delete throws exception',
        (tester) async {
      setupSingleAiResponse();
      when(() => mockJournalRepository.deleteJournalEntity(any()))
          .thenThrow(Exception('Network error'));

      await pumpWidget(tester);

      // Find the specific Dismissible by key (not SnackBar's Dismissible)
      final dismissibleFinder = find.byKey(Key(testAiResponseEntry1.meta.id));

      // Swipe to trigger confirmation dialog
      await tester.drag(dismissibleFinder, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Tap Delete button
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Error snackbar should be shown
      expect(find.byType(SnackBar), findsOneWidget);

      // Our AI response Dismissible should still exist (not dismissed on failure)
      expect(dismissibleFinder, findsOneWidget);
    });

    testWidgets('dialog dismissed by tapping outside does not delete',
        (tester) async {
      setupSingleAiResponse();
      await pumpWidget(tester);

      // Swipe to trigger confirmation dialog
      await tester.drag(find.byType(Dismissible), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap outside the dialog (on the barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byType(AlertDialog), findsNothing);

      // Delete should NOT have been called
      verifyNever(() => mockJournalRepository.deleteJournalEntity(any()));

      // Dismissible should still exist (not dismissed)
      expect(find.byType(Dismissible), findsOneWidget);
    });
  });

  group('Dismissible Configuration', () {
    testWidgets('Dismissible has correct direction and threshold',
        (tester) async {
      setupSingleAiResponse();
      await pumpWidget(tester);

      final dismissible = tester.widget<Dismissible>(
        find.byType(Dismissible),
      );

      // Should only allow endToStart direction (swipe left)
      expect(dismissible.direction, equals(DismissDirection.endToStart));
      // Should have dismiss threshold
      expect(dismissible.dismissThresholds, isNotEmpty);
      // Should have background
      expect(dismissible.background, isNotNull);
      // Should have confirmDismiss callback
      expect(dismissible.confirmDismiss, isNotNull);
    });

    testWidgets('AiResponseSummary is rendered inside Dismissible',
        (tester) async {
      setupSingleAiResponse();
      await pumpWidget(tester);

      final dismissible = find.byType(Dismissible);
      final aiResponseSummary = find.descendant(
        of: dismissible,
        matching: find.byType(AiResponseSummary),
      );

      expect(aiResponseSummary, findsOneWidget);
    });
  });
}
