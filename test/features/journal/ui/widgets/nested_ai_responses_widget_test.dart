import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/summary_read_aloud_button.dart';
import 'package:lotti/features/ai/ui/ai_response_card.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_entrance.dart';
import 'package:lotti/features/journal/state/linked_ai_responses_controller.dart';
import 'package:lotti/features/journal/ui/widgets/nested_ai_responses_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/widgets/layout/viewport_stable_animated_size.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class _ControllableLinkedAiResponsesController
    extends LinkedAiResponsesController {
  _ControllableLinkedAiResponsesController({
    required String entryId,
    required this.initialResponses,
  }) : super(entryId);

  final List<AiResponseEntry> initialResponses;

  @override
  Future<List<AiResponseEntry>> build() async => initialResponses;

  void emit(List<AiResponseEntry> responses) {
    state = AsyncData(responses);
  }
}

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

  setUpAll(() {
    registerFallbackValue(const <String>[]);
  });

  setUp(() async {
    // Registers the core getIt graph (UpdateNotifications with an empty
    // update stream, LoggingService, DomainLogger, JournalDb, SettingsDb, …)
    // via a single shared helper instead of hand-rolled registrations.
    // The controller only reads getIt<UpdateNotifications>() and the
    // journalRepositoryProvider override below, so the empty update stream
    // is exactly what these tests want (no spurious background refreshes).
    await setUpTestGetIt();

    mockJournalRepository = MockJournalRepository();

    // Default stub for the bulk fetch path. The controller now coalesces
    // its N parallel `getJournalEntityById` calls into a single
    // `getJournalEntitiesByIds`. Existing test bodies still stub the
    // per-id getter; this default delegates to those stubs so the
    // individual setups keep working without rewrites.
    when(
      () => mockJournalRepository.getJournalEntitiesByIds(any()),
    ).thenAnswer((invocation) async {
      final ids = (invocation.positionalArguments.first as Iterable<String>)
          .toList();
      final results = <JournalEntity>[];
      for (final id in ids) {
        final entity = await mockJournalRepository.getJournalEntityById(id);
        if (entity != null) results.add(entity);
      }
      return results;
    });
  });

  tearDown(tearDownTestGetIt);

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

    when(
      () => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id),
    ).thenAnswer((_) async => links);
    when(
      () => mockJournalRepository.getJournalEntityById(
        testAiResponseEntry1.meta.id,
      ),
    ).thenAnswer((_) async => testAiResponseEntry1);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> swipeAiResponseToDelete(WidgetTester tester) async {
    final dismissible = find.byKey(Key(testAiResponseEntry1.meta.id));
    final swipeStart = tester.getTopLeft(dismissible) + const Offset(20, 20);

    await tester.dragFrom(swipeStart, const Offset(-300, 0));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  group('NestedAiResponsesWidget Rendering', () {
    testWidgets(
      'tracks response entrances outside build across provider updates',
      (tester) async {
        final controller = _ControllableLinkedAiResponsesController(
          entryId: testAudioEntry.meta.id,
          initialResponses: const [],
        );
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            NestedAiResponsesWidget(
              parentEntryId: testAudioEntry.meta.id,
              linkedFromEntity: testAudioEntry,
            ),
            overrides: [
              linkedAiResponsesControllerProvider(
                testAudioEntry.meta.id,
              ).overrideWith(() => controller),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(SizeFadeEntrance), findsNothing);

        controller.emit([testAiResponseEntry1]);
        await tester.pump();

        final sectionEntrance = tester.widget<SizeFadeEntrance>(
          find.byKey(
            ValueKey('nested-ai-section-${testAudioEntry.meta.id}'),
          ),
        );
        expect(sectionEntrance.animate, isTrue);

        await tester.pump(const Duration(milliseconds: 300));
        controller.emit([testAiResponseEntry2, testAiResponseEntry1]);
        await tester.pump();

        final responseEntrance = tester.widget<SizeFadeEntrance>(
          find.byKey(
            ValueKey('nested-ai-response-${testAiResponseEntry2.meta.id}'),
          ),
        );
        expect(responseEntrance.animate, isTrue);
      },
    );

    testWidgets(
      'switching parents treats the next parent responses as initial data',
      (tester) async {
        final otherParent = testAudioEntry.copyWith(
          meta: testAudioEntry.meta.copyWith(id: 'audio-entry-456'),
        );
        final firstController = _ControllableLinkedAiResponsesController(
          entryId: testAudioEntry.meta.id,
          initialResponses: [testAiResponseEntry1],
        );
        final secondController = _ControllableLinkedAiResponsesController(
          entryId: otherParent.meta.id,
          initialResponses: [testAiResponseEntry2],
        );
        var parent = testAudioEntry;
        late StateSetter setParent;

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                linkedAiResponsesControllerProvider(
                  testAudioEntry.meta.id,
                ).overrideWith(() => firstController),
                linkedAiResponsesControllerProvider(
                  otherParent.meta.id,
                ).overrideWith(() => secondController),
              ],
              child: StatefulBuilder(
                builder: (context, setState) {
                  setParent = setState;
                  return NestedAiResponsesWidget(
                    parentEntryId: parent.meta.id,
                    linkedFromEntity: parent,
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byKey(Key(testAiResponseEntry1.meta.id)), findsOneWidget);
        expect(find.byType(SizeFadeEntrance), findsNothing);

        setParent(() => parent = otherParent);
        await tester.pump();
        await tester.pump();

        expect(find.byKey(Key(testAiResponseEntry1.meta.id)), findsNothing);
        expect(find.byKey(Key(testAiResponseEntry2.meta.id)), findsOneWidget);
        expect(find.byType(SizeFadeEntrance), findsNothing);
      },
    );

    testWidgets('shows nothing while loading', (tester) async {
      // Arrange - use a completer to keep the provider in loading state
      final completer = Completer<List<EntryLink>>();

      when(
        () => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id),
      ).thenAnswer((_) => completer.future);

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

      expect(find.byType(AiResponseSummary), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(
        tester.getSize(find.byType(NestedAiResponsesWidget)).height,
        0,
      );
    });

    testWidgets('shows nothing when AI responses list is empty', (
      tester,
    ) async {
      when(
        () => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id),
      ).thenAnswer((_) async => []);

      await pumpWidget(tester);

      expect(find.byType(AiResponseSummary), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(
        tester.getSize(find.byType(NestedAiResponsesWidget)).height,
        0,
      );
    });

    testWidgets('says so when the responses could not be loaded', (
      tester,
    ) async {
      when(
        () => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id),
      ).thenThrow(Exception('Database error'));

      await pumpWidget(tester);

      // Not a blank: an entry whose AI results failed to load must not look
      // like one the agent made nothing of.
      final context = tester.element(find.byType(NestedAiResponsesWidget));
      expect(
        find.text(context.messages.nestedAiResponsesLoadFailed),
        findsOneWidget,
      );
      expect(find.byType(AiResponseSummary), findsNothing);
    });

    testWidgets(
      'draws each response on the entry gutter at full width, with no '
      'thread header, count or toggle of its own',
      (tester) async {
        setupSingleAiResponse();

        await pumpWidget(tester);

        final thread = find.byType(NestedAiResponsesWidget);
        final card = find.byType(Dismissible);
        expect(card, findsOneWidget);
        // No indent and no connector: the card spans the thread edge to edge.
        expect(tester.getTopLeft(card).dx, tester.getTopLeft(thread).dx);
        expect(tester.getSize(card).width, tester.getSize(thread).width);
        // The only text is the response's own: no "1 AI response" row.
        expect(find.textContaining('AI response'), findsNothing);
        expect(
          find.descendant(of: thread, matching: find.byType(SizeTransition)),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a long analysis starts collapsed inside the nested tree '
      '(collapsible wiring)',
      (tester) async {
        // Long enough (> 500 chars) that the per-card collapse kicks in.
        final longOcr = testAiResponseEntry2.copyWith(
          data: testAiResponseEntry2.data.copyWith(
            response: List.generate(
              30,
              (i) =>
                  'Manifest line $i: sardine pod $i cleared for Bay 7 '
                  'docking at Orbital Habitat Waddle One.',
            ).join('\n'),
            type: AiResponseType.imageAnalysis,
          ),
        );

        when(
          () => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id),
        ).thenAnswer(
          (_) async => [
            EntryLink.basic(
              id: 'link-long',
              fromId: testAudioEntry.meta.id,
              toId: longOcr.meta.id,
              createdAt: DateTime(2024, 1, 15, 10),
              updatedAt: DateTime(2024, 1, 15, 10),
              vectorClock: null,
            ),
          ],
        );
        when(
          () => mockJournalRepository.getJournalEntityById(longOcr.meta.id),
        ).thenAnswer((_) async => longOcr);

        await pumpWidget(tester);

        // The nested card passes collapsible: true, so the long analysis
        // starts as a faded preview with the expand toggle.
        expect(
          find.byKey(AiResponseCard.collapseToggleKey),
          findsOneWidget,
        );
      },
    );

    // A recording in Task A and its follow-up Task B carries the coding
    // prompt made in each. Inside a task only that task's prompt shows under
    // it; on its own, the recording shows both.
    group('a recording in two tasks', () {
      final promptForA = testAiResponseEntry1.copyWith(
        meta: testAiResponseEntry1.meta.copyWith(id: 'prompt-for-a'),
      );
      final promptForB = testAiResponseEntry1.copyWith(
        meta: testAiResponseEntry1.meta.copyWith(id: 'prompt-for-b'),
      );

      Future<void> pumpIn(WidgetTester tester, {String? taskId}) async {
        when(
          () => mockJournalRepository.getParentTaskIds(any()),
        ).thenAnswer(
          (_) async => {
            'prompt-for-a': {'task-a'},
            'prompt-for-b': {'task-b'},
          },
        );
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            NestedAiResponsesWidget(
              parentEntryId: testAudioEntry.meta.id,
              linkedFromEntity: testAudioEntry,
              contextTaskId: taskId,
            ),
            overrides: [
              journalRepositoryProvider.overrideWithValue(
                mockJournalRepository,
              ),
              linkedAiResponsesControllerProvider(
                testAudioEntry.meta.id,
              ).overrideWith(
                () => _ControllableLinkedAiResponsesController(
                  entryId: testAudioEntry.meta.id,
                  initialResponses: [promptForB, promptForA],
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets("shows only Task B's prompt inside Task B", (tester) async {
        await pumpIn(tester, taskId: 'task-b');

        expect(find.byKey(const Key('prompt-for-b')), findsOneWidget);
        expect(find.byKey(const Key('prompt-for-a')), findsNothing);
      });

      testWidgets("shows only Task A's prompt inside Task A", (tester) async {
        await pumpIn(tester, taskId: 'task-a');

        expect(find.byKey(const Key('prompt-for-a')), findsOneWidget);
        expect(find.byKey(const Key('prompt-for-b')), findsNothing);
      });

      testWidgets("Task A's prompt reads aloud with Task A's voice, under "
          "the prompt's own source", (tester) async {
        await pumpIn(tester, taskId: 'task-a');

        final summary = tester.widget<AiResponseSummary>(
          find.byType(AiResponseSummary),
        );
        final button =
            summary.readAloud!('The prompt.') as TaskPromptReadAloudButton;
        expect(button.taskId, 'task-a');
        expect(button.sourceId, 'prompt-for-a');
        expect(button.text, 'The prompt.');
      });

      testWidgets('shows both prompts, asking about no owners, on its own', (
        tester,
      ) async {
        await pumpIn(tester);

        expect(find.byKey(const Key('prompt-for-a')), findsOneWidget);
        expect(find.byKey(const Key('prompt-for-b')), findsOneWidget);
        verifyNever(() => mockJournalRepository.getParentTaskIds(any()));
      });
    });

    testWidgets('renders multiple AI responses with correct count', (
      tester,
    ) async {
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

      when(
        () => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id),
      ).thenAnswer((_) async => links);
      when(
        () => mockJournalRepository.getJournalEntityById(
          testAiResponseEntry1.meta.id,
        ),
      ).thenAnswer((_) async => testAiResponseEntry1);
      when(
        () => mockJournalRepository.getJournalEntityById(
          testAiResponseEntry2.meta.id,
        ),
      ).thenAnswer((_) async => testAiResponseEntry2);

      await pumpWidget(tester);

      // Should have Dismissible widgets for each AI response
      expect(find.byType(Dismissible), findsNWidgets(2));
    });

    testWidgets('enables animated response sizing in the task scroll scope', (
      tester,
    ) async {
      setupSingleAiResponse();
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskScrollStabilityScope(
            controller: controller,
            child: NestedAiResponsesWidget(
              parentEntryId: testAudioEntry.meta.id,
              linkedFromEntity: testAudioEntry,
            ),
          ),
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ViewportStableAnimatedSize), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ViewportStableAnimatedSize),
          matching: find.byType(AnimatedSize),
        ),
        findsOneWidget,
      );
      expect(find.byType(AiResponseSummary), findsOneWidget);
    });
  });

  group('Delete Flow', () {
    testWidgets('shows confirmation dialog on swipe', (tester) async {
      setupSingleAiResponse();
      await pumpWidget(tester);

      // Swipe to trigger confirmation dialog
      await swipeAiResponseToDelete(tester);

      // Verify the confirmation modal is shown with title and content
      expect(find.byKey(confirmationModalKey), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('cancel button dismisses dialog without deleting', (
      tester,
    ) async {
      setupSingleAiResponse();
      await pumpWidget(tester);

      // Swipe to trigger confirmation dialog
      await swipeAiResponseToDelete(tester);

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byKey(confirmationModalKey), findsNothing);

      // Delete should NOT have been called
      verifyNever(() => mockJournalRepository.deleteJournalEntity(any()));

      // Dismissible should still exist
      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('delete button calls repository and dismisses on success', (
      tester,
    ) async {
      setupSingleAiResponse();
      when(
        () => mockJournalRepository.deleteJournalEntity(any()),
      ).thenAnswer((_) async => true);

      await pumpWidget(tester);

      // Swipe to trigger confirmation dialog
      await swipeAiResponseToDelete(tester);

      // Tap Delete button
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify delete was called with correct ID
      verify(
        () => mockJournalRepository.deleteJournalEntity(
          testAiResponseEntry1.meta.id,
        ),
      ).called(1);

      // Dialog should be dismissed
      expect(find.byKey(confirmationModalKey), findsNothing);
    });

    testWidgets('shows error snackbar when delete fails', (tester) async {
      setupSingleAiResponse();
      when(
        () => mockJournalRepository.deleteJournalEntity(any()),
      ).thenAnswer((_) async => false);

      await pumpWidget(tester);

      // Find the specific Dismissible by key (not SnackBar's Dismissible)
      final dismissibleFinder = find.byKey(Key(testAiResponseEntry1.meta.id));

      // Swipe to trigger confirmation dialog
      await swipeAiResponseToDelete(tester);

      // Tap Delete button
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify delete was called
      verify(
        () => mockJournalRepository.deleteJournalEntity(
          testAiResponseEntry1.meta.id,
        ),
      ).called(1);

      // Error snackbar should be shown
      expect(find.byType(SnackBar), findsOneWidget);

      // Our AI response Dismissible should still exist (not dismissed on failure)
      expect(dismissibleFinder, findsOneWidget);
    });

    testWidgets('shows error snackbar when delete throws exception', (
      tester,
    ) async {
      setupSingleAiResponse();
      when(
        () => mockJournalRepository.deleteJournalEntity(any()),
      ).thenThrow(Exception('Network error'));

      await pumpWidget(tester);

      // Find the specific Dismissible by key (not SnackBar's Dismissible)
      final dismissibleFinder = find.byKey(Key(testAiResponseEntry1.meta.id));

      // Swipe to trigger confirmation dialog
      await swipeAiResponseToDelete(tester);

      // Tap Delete button
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Error snackbar should be shown
      expect(find.byType(SnackBar), findsOneWidget);

      // Our AI response Dismissible should still exist (not dismissed on failure)
      expect(dismissibleFinder, findsOneWidget);
    });

    testWidgets('dialog dismissed by tapping outside does not delete', (
      tester,
    ) async {
      setupSingleAiResponse();
      await pumpWidget(tester);

      // Swipe to trigger confirmation dialog
      await swipeAiResponseToDelete(tester);

      // Verify dialog is shown
      expect(find.byKey(confirmationModalKey), findsOneWidget);

      // Tap outside the dialog (on the barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byKey(confirmationModalKey), findsNothing);

      // Delete should NOT have been called
      verifyNever(() => mockJournalRepository.deleteJournalEntity(any()));

      // Dismissible should still exist (not dismissed)
      expect(find.byType(Dismissible), findsOneWidget);
    });
  });

  group('Dismissible Configuration', () {
    testWidgets('Dismissible has correct direction and threshold', (
      tester,
    ) async {
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

    testWidgets('AiResponseSummary is rendered inside Dismissible', (
      tester,
    ) async {
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
