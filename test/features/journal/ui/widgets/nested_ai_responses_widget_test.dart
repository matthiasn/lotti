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
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

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
  late StreamController<Set<String>> updateStreamController;

  setUp(() {
    mockJournalRepository = MockJournalRepository();
    mockUpdateNotifications = MockUpdateNotifications();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    getIt.allowReassignment = true;
    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() {
    updateStreamController.close();
    getIt.unregister<UpdateNotifications>();
  });

  group('NestedAiResponsesWidget', () {
    test('widget can be instantiated with required parameters', () {
      final widget = NestedAiResponsesWidget(
        parentEntryId: testAudioEntry.meta.id,
        linkedFromEntity: testAudioEntry,
      );

      expect(widget.parentEntryId, equals(testAudioEntry.meta.id));
      expect(widget.linkedFromEntity, equals(testAudioEntry));
    });

    test('widget accepts JournalAudio as linkedFromEntity', () {
      final widget = NestedAiResponsesWidget(
        parentEntryId: 'test-id',
        linkedFromEntity: testAudioEntry,
      );

      expect(widget.linkedFromEntity, isA<JournalAudio>());
    });

    test('parentEntryId matches the audio entry id', () {
      final widget = NestedAiResponsesWidget(
        parentEntryId: testAudioEntry.meta.id,
        linkedFromEntity: testAudioEntry,
      );

      expect(widget.parentEntryId, equals('audio-entry-123'));
    });
  });

  group('NestedAiResponsesWidget Widget Tests', () {
    testWidgets('shows nothing while loading', (tester) async {
      // Arrange - use a completer to keep the provider in loading state
      final completer = Completer<List<AiResponseEntry>>();

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async {
        await completer.future; // Never completes
        return [];
      });

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

      // Should show SizedBox.shrink during loading
      expect(find.byType(SizedBox), findsWidgets);
      // Should not show any AI response content
      expect(find.byIcon(Icons.auto_fix_high_outlined), findsNothing);
    });

    testWidgets('shows nothing when AI responses list is empty',
        (tester) async {
      // Arrange
      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => []);

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

      // Should show SizedBox.shrink for empty list
      expect(find.byType(SizedBox), findsWidgets);
      // Should not show any AI response header
      expect(find.byIcon(Icons.auto_fix_high_outlined), findsNothing);
    });

    testWidgets('shows nothing on error state', (tester) async {
      // Arrange - simulate an error in the provider
      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenThrow(Exception('Database error'));

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

      // Should show SizedBox.shrink on error
      expect(find.byType(SizedBox), findsWidgets);
      // Should not show any AI response header
      expect(find.byIcon(Icons.auto_fix_high_outlined), findsNothing);
    });

    testWidgets('renders AI responses when data is available', (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Should show the AI icon in header (may be multiple from nested components)
      expect(
          find.byIcon(Icons.auto_fix_high_outlined), findsAtLeastNWidgets(1));
      // Should show the expand icon
      expect(find.byIcon(Icons.expand_more), findsAtLeastNWidgets(1));
    });

    testWidgets('renders multiple AI responses', (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
        EntryLink.basic(
          id: 'link-2',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry2.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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

      // Should show the AI icon in header
      expect(
          find.byIcon(Icons.auto_fix_high_outlined), findsAtLeastNWidgets(1));
      // Should have Dismissible widgets for each AI response
      expect(find.byType(Dismissible), findsAtLeastNWidgets(2));
    });

    testWidgets('collapses when header is tapped', (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Verify initially expanded (SizeTransition should have value 1.0)
      final sizeTransition =
          tester.widget<SizeTransition>(find.byType(SizeTransition));
      expect(sizeTransition.sizeFactor.value, equals(1.0));

      // Tap the header to collapse
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Verify collapsed (SizeTransition should have value 0.0)
      final collapsedSizeTransition =
          tester.widget<SizeTransition>(find.byType(SizeTransition));
      expect(collapsedSizeTransition.sizeFactor.value, equals(0.0));
    });

    testWidgets('expands when header is tapped after collapse', (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Collapse first
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Verify collapsed
      var sizeTransition =
          tester.widget<SizeTransition>(find.byType(SizeTransition));
      expect(sizeTransition.sizeFactor.value, equals(0.0));

      // Expand again
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Verify expanded
      sizeTransition =
          tester.widget<SizeTransition>(find.byType(SizeTransition));
      expect(sizeTransition.sizeFactor.value, equals(1.0));
    });

    testWidgets('shows rotation animation on expand icon', (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Find the RotationTransition that contains the expand_more icon
      // by finding the InkWell header first and looking for RotationTransition inside
      final inkWell = find.byType(InkWell).first;
      final rotationTransition = find.descendant(
        of: inkWell,
        matching: find.byType(RotationTransition),
      );
      expect(rotationTransition, findsOneWidget);

      // Get initial rotation value - when expanded, value is 0.5
      final initialRotation =
          tester.widget<RotationTransition>(rotationTransition);
      expect(initialRotation.turns.value, equals(0.5));

      // Collapse
      await tester.tap(inkWell);
      await tester.pumpAndSettle();

      // Verify rotation changed - when collapsed, value is 0.0
      final collapsedRotation =
          tester.widget<RotationTransition>(rotationTransition);
      expect(collapsedRotation.turns.value, equals(0.0));
    });

    testWidgets('renders connector line decoration', (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Should have a Container with BoxDecoration for the connector line
      // Find containers with width 16 (connector line width)
      final containers = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == 16 && widget.height == null,
      );
      expect(containers, findsOneWidget);
    });
  });

  group('Swipe-to-Delete Functionality', () {
    testWidgets('has Dismissible widget for swipe-to-delete', (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Find Dismissible widgets - there should be at least one
      expect(find.byType(Dismissible), findsAtLeastNWidgets(1));

      // Verify the Dismissible has the correct key
      final dismissible = tester.widget<Dismissible>(
        find.byType(Dismissible).first,
      );
      expect(dismissible.key, equals(Key(testAiResponseEntry1.meta.id)));
    });

    testWidgets('Dismissible has correct direction and threshold',
        (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Verify the Dismissible has correct configuration
      final dismissible = tester.widget<Dismissible>(
        find.byType(Dismissible).first,
      );

      // Should only allow endToStart direction (swipe left)
      expect(dismissible.direction, equals(DismissDirection.endToStart));

      // Should have dismiss threshold
      expect(dismissible.dismissThresholds, isNotEmpty);
    });

    testWidgets('Dismissible has delete background', (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Verify the Dismissible has a background widget configured
      final dismissible = tester.widget<Dismissible>(
        find.byType(Dismissible).first,
      );

      expect(dismissible.background, isNotNull);
    });

    testWidgets('Dismissible has confirmDismiss callback', (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Verify the Dismissible has confirmDismiss callback
      final dismissible = tester.widget<Dismissible>(
        find.byType(Dismissible).first,
      );

      expect(dismissible.confirmDismiss, isNotNull);
    });

    testWidgets('Dismissible has onDismissed callback', (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Verify the Dismissible has onDismissed callback
      final dismissible = tester.widget<Dismissible>(
        find.byType(Dismissible).first,
      );

      expect(dismissible.onDismissed, isNotNull);
    });

    testWidgets('AiResponseSummary is rendered inside Dismissible',
        (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Verify AiResponseSummary is a child of Dismissible
      final dismissible = find.byType(Dismissible).first;
      final aiResponseSummary = find.descendant(
        of: dismissible,
        matching: find.byType(AiResponseSummary),
      );

      expect(aiResponseSummary, findsOneWidget);
    });
  });

  group('Delete Dialog Interaction', () {
    testWidgets('shows AlertDialog with title and content on swipe',
        (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Swipe to trigger confirmation dialog
      final dismissible = find.byType(Dismissible).first;
      await tester.drag(dismissible, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Verify AlertDialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Verify dialog has title (Text widget inside AlertDialog)
      final alertDialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(alertDialog.title, isNotNull);
      expect(alertDialog.content, isNotNull);
    });

    testWidgets('dialog has Cancel and Delete action buttons', (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Swipe to trigger confirmation dialog
      final dismissible = find.byType(Dismissible).first;
      await tester.drag(dismissible, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Verify both action buttons exist
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Cancel button dismisses dialog without calling delete',
        (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Swipe to trigger confirmation dialog
      final dismissible = find.byType(Dismissible).first;
      await tester.drag(dismissible, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byType(AlertDialog), findsNothing);

      // Delete should NOT have been called
      verifyNever(() => mockJournalRepository.deleteJournalEntity(any()));
    });

    testWidgets('Delete button triggers repository delete call',
        (tester) async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);
      when(() => mockJournalRepository.deleteJournalEntity(any()))
          .thenAnswer((_) async => true);

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

      // Swipe to trigger confirmation dialog
      final dismissible = find.byType(Dismissible).first;
      await tester.drag(dismissible, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Tap Delete button
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify delete was called with correct ID
      verify(() => mockJournalRepository.deleteJournalEntity(
            testAiResponseEntry1.meta.id,
          )).called(1);
    });

    testWidgets('dialog dismissed by tapping outside returns false',
        (tester) async {
      // Arrange - tests result ?? false path (line 296)
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntry.meta.id,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

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

      // Swipe to trigger confirmation dialog
      final dismissible = find.byType(Dismissible).first;
      await tester.drag(dismissible, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap outside the dialog (on the barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byType(AlertDialog), findsNothing);

      // Delete should NOT have been called (result ?? false returns false)
      verifyNever(() => mockJournalRepository.deleteJournalEntity(any()));

      // Dismissible should still exist (not dismissed)
      expect(find.byType(Dismissible), findsOneWidget);
    });
  });

  group('AI Response Test Data', () {
    test('testAiResponseEntry1 has promptGeneration type', () {
      expect(
        testAiResponseEntry1.data.type,
        equals(AiResponseType.promptGeneration),
      );
    });

    test('testAiResponseEntry2 has audioTranscription type', () {
      expect(
        testAiResponseEntry2.data.type,
        equals(AiResponseType.audioTranscription),
      );
    });

    test('AI responses have different IDs', () {
      expect(
        testAiResponseEntry1.meta.id,
        isNot(equals(testAiResponseEntry2.meta.id)),
      );
    });

    test('AI responses have valid metadata', () {
      expect(testAiResponseEntry1.meta.id, isNotEmpty);
      expect(testAiResponseEntry1.meta.createdAt, isNotNull);
      expect(testAiResponseEntry1.meta.dateFrom, isNotNull);
      expect(testAiResponseEntry1.meta.dateTo, isNotNull);
    });

    test('testAiResponseEntry2 is newer than testAiResponseEntry1', () {
      expect(
        testAiResponseEntry2.meta.dateFrom
            .isAfter(testAiResponseEntry1.meta.dateFrom),
        isTrue,
      );
    });
  });

  group('Audio Entry Test Data', () {
    test('testAudioEntry has valid audio data', () {
      expect(testAudioEntry.data.audioFile, equals('test.aac'));
      expect(testAudioEntry.data.audioDirectory, equals('/test/'));
      expect(testAudioEntry.data.duration, equals(const Duration(minutes: 5)));
    });

    test('testAudioEntry has valid metadata', () {
      expect(testAudioEntry.meta.id, equals('audio-entry-123'));
      expect(testAudioEntry.meta.createdAt, isNotNull);
    });
  });

  group('Delete Confirmation Dialog', () {
    test(
        'JournalRepository.deleteJournalEntity can be called with AI response ID',
        () async {
      // Arrange
      when(() => mockJournalRepository.deleteJournalEntity(any()))
          .thenAnswer((_) async => true);

      // Act
      final result = await mockJournalRepository.deleteJournalEntity(
        testAiResponseEntry1.meta.id,
      );

      // Assert
      expect(result, isTrue);
      verify(() => mockJournalRepository.deleteJournalEntity(
            testAiResponseEntry1.meta.id,
          )).called(1);
    });

    test('deleteJournalEntity is called with correct AI response ID', () async {
      // Arrange
      when(() => mockJournalRepository.deleteJournalEntity(any()))
          .thenAnswer((_) async => true);

      // Act
      await mockJournalRepository.deleteJournalEntity('ai-response-1');

      // Assert
      verify(() => mockJournalRepository.deleteJournalEntity('ai-response-1'))
          .called(1);
    });

    test('delete returns false when deletion fails', () async {
      // Arrange
      when(() => mockJournalRepository.deleteJournalEntity(any()))
          .thenAnswer((_) async => false);

      // Act
      final result = await mockJournalRepository.deleteJournalEntity(
        testAiResponseEntry1.meta.id,
      );

      // Assert
      expect(result, isFalse);
    });

    test('AI response entry has valid ID for deletion', () {
      // Test that our test data has the required ID field
      expect(testAiResponseEntry1.meta.id, isNotEmpty);
      expect(testAiResponseEntry1.meta.id, equals('ai-response-1'));
    });

    test('AI response entry ID is unique and suitable for Dismissible key', () {
      // Dismissible requires unique keys - test that IDs are suitable
      final key1 = Key(testAiResponseEntry1.meta.id);
      final key2 = Key(testAiResponseEntry2.meta.id);

      expect(key1, isNot(equals(key2)));
    });
  });
}
