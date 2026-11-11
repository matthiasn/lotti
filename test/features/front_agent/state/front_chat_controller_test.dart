import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_turn_failure.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_thread_builder.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_category.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../categories/test_utils.dart';

/// Counts how often the thread was re-projected: the controller's
/// invalidation is what the surface relies on after an awaited turn.
class _CountingBuilder extends FrontChatThreadBuilder {
  _CountingBuilder() : super(repository: MockAgentRepository());

  int builds = 0;

  @override
  Future<FrontChatThread> build({
    String? conversationId,
    Set<String> excluded = const {},
  }) async {
    builds++;
    return FrontChatThread.empty;
  }
}

void main() {
  late MockFrontAgentService agentService;
  late MockFrontChatService chatService;
  late MockFrontFilingService filing;
  late MockFrontConversationService conversations;
  late _CountingBuilder threadBuilder;
  late ProviderContainer container;

  setUp(() {
    agentService = MockFrontAgentService();
    chatService = MockFrontChatService();
    filing = MockFrontFilingService();
    conversations = MockFrontConversationService();
    threadBuilder = _CountingBuilder();
    when(
      () => agentService.getOrCreate(),
    ).thenAnswer((_) async => makeTestIdentity(id: 'front_agent'));
    container = ProviderContainer(
      overrides: [
        frontAgentServiceProvider.overrideWithValue(agentService),
        frontChatServiceProvider.overrideWithValue(chatService),
        frontFilingServiceProvider.overrideWithValue(filing),
        frontChatThreadBuilderProvider.overrideWithValue(threadBuilder),
        frontConversationServiceProvider.overrideWithValue(conversations),
        // Where the user left off, until they pick another.
        frontConversationsProvider.overrideWith(
          (ref) async => FrontConversationIndex(
            conversations: [
              FrontConversation(
                id: 'c-1',
                title: 'Census',
                // Moved just now: the conversation the user left off in
                // today, whenever the suite runs.
                lastActivity: clock.now(),
                archived: false,
              ),
            ],
          ),
        ),
        frontChatThreadProvider.overrideWith(
          (Ref ref) => ref.watch(frontChatThreadBuilderProvider).build(),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Someone is looking at the thread, so an invalidation re-projects it.
    container.listen(frontChatThreadProvider, (_, _) {});
  });

  FrontChatController controller() =>
      container.read(frontChatControllerProvider.notifier);
  FrontChatComposerState state() => container.read(frontChatControllerProvider);

  test('a spoken draft stays spoken through edits, and an emptied or sent '
      'draft is no longer spoken', () async {
    controller()
      ..updateDraft('Krill?')
      ..markDraftSpoken()
      ..updateDraft('Krill today?');
    expect(state().draftSpoken, isTrue);

    controller().updateDraft('');
    expect(state().draftSpoken, isFalse);

    controller()
      ..updateDraft('Krill?')
      ..markDraftSpoken();
    await controller().sendSpoken();
    // Sent — here it fails and the words come back — the next send is
    // typed unless something is said again.
    expect(state().draftSpoken, isFalse);
  });

  test('a draft is kept and clears a previous failure', () async {
    when(
      () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
    ).thenThrow(StateError('db closed'));
    controller().updateDraft('Hello');
    await controller().send();
    expect(state().failedMessage, 'Hello');
    // Not the turn's failure: nothing more specific to say.
    expect(state().failure, FrontTurnFailure.unknown);

    controller().updateDraft('Hel');

    expect(state().draft, 'Hel');
    expect(state().isSending, isFalse);
    expect(state().failedMessage, isNull);
    expect(state().failedMessageId, isNull);
    expect(state().failure, isNull);
  });

  group('conversations', () {
    String? picked() => container.read(frontPickedConversationProvider);

    setUp(() {
      // Kept alive across the calls: both auto-dispose otherwise.
      final subs = [
        container.listen(frontInboxFilterProvider, (_, _) {}),
        container.listen(frontActiveConversationProvider, (_, _) {}),
      ];
      addTearDown(() {
        for (final sub in subs) {
          sub.close();
        }
      });
    });

    test('a send lands in where the user left off and pins it', () async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenAnswer((_) async {});
      expect(picked(), isNull);

      await controller().sendText('Hello');

      verify(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).called(1);
      expect(picked(), 'c-1');
    });

    test('a new conversation is empty and the next send starts it', () async {
      when(
        () => chatService.sendMessage(
          text: 'Count the hatchlings',
          conversationId: any(named: 'conversationId'),
        ),
      ).thenAnswer((_) async {});
      container.read(frontInboxFilterProvider.notifier).toggle();

      controller().startConversation();
      final fresh = picked();
      await controller().sendText('Count the hatchlings');

      expect(fresh, isNot(anyOf(isNull, 'c-1')));
      expect(container.read(frontInboxFilterProvider), isFalse);
      verify(
        () => chatService.sendMessage(
          text: 'Count the hatchlings',
          conversationId: fresh!,
        ),
      ).called(1);
    });

    test('opening one leaves the inbox and shows it', () async {
      container.read(frontInboxFilterProvider.notifier).toggle();

      controller().openConversation('c-9');

      expect(picked(), 'c-9');
      expect(container.read(frontInboxFilterProvider), isFalse);
      expect(
        await container.read(frontActiveConversationProvider.future),
        'c-9',
      );
    });

    test('archiving the open one moves to a fresh conversation; restoring it '
        'does not leave it', () async {
      when(
        () => conversations.archive(any(), archived: any(named: 'archived')),
      ).thenAnswer((_) async {});
      controller().openConversation('c-2');

      await controller().archiveConversation('c-2', archived: false);
      expect(picked(), 'c-2');

      await controller().archiveConversation('c-2', archived: true);
      expect(picked(), isNot(anyOf(isNull, 'c-1', 'c-2')));
    });

    test('rename, archive and delete go through the service; deleting the '
        'open one moves to a fresh conversation', () async {
      when(
        () => conversations.rename(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => conversations.archive(any(), archived: any(named: 'archived')),
      ).thenAnswer((_) async {});
      when(() => conversations.delete(any())).thenAnswer((_) async {});
      controller().openConversation('c-2');

      await controller().renameConversation('c-2', 'Hatchlings');
      await controller().archiveConversation('c-4', archived: true);
      await controller().deleteConversation('c-3');
      expect(picked(), 'c-2', reason: 'other ones were put away');
      await controller().deleteConversation('c-2');

      verifyInOrder([
        () => conversations.rename('c-2', 'Hatchlings'),
        () => conversations.archive('c-4', archived: true),
        () => conversations.delete('c-3'),
        () => conversations.delete('c-2'),
      ]);
      expect(picked(), isNot(anyOf(isNull, 'c-1', 'c-2')));
    });

    test(
      'a pick from another day is not the open conversation any more',
      () async {
        withClock(Clock.fixed(DateTime(2026, 10, 30, 23)), () {
          controller().openConversation('c-9');
          expect(controller().isOpen('c-9'), isTrue);
        });

        withClock(Clock.fixed(DateTime(2026, 10, 31, 7)), () {
          expect(controller().isOpen('c-9'), isFalse);
        });
      },
    );

    test('each conversation keeps its own draft', () async {
      await container.read(frontConversationsProvider.future);
      controller()
        ..openConversation('c-1')
        ..updateDraft('Half a census question');

      controller().startConversation();
      expect(state().draft, isEmpty);
      controller().updateDraft('Krill?');

      controller().openConversation('c-1');
      expect(state().draft, 'Half a census question');

      controller().openConversation('c-1');
      expect(state().draft, 'Half a census question', reason: 'no switch');
    });

    test('a new chat on a conversation that is already new and empty does '
        'nothing, so its draft is not orphaned', () async {
      await container.read(frontConversationsProvider.future);
      controller().startConversation();
      final fresh = picked();
      controller().updateDraft('Krill?');

      controller().startConversation();

      expect(picked(), fresh);
      expect(state().draft, 'Krill?');
    });

    test('talking in an archived conversation brings it back — best '
        'effort: a failed un-archive does not fail the sent turn', () async {
      final archivedOnly = ProviderContainer(
        overrides: [
          frontAgentServiceProvider.overrideWithValue(agentService),
          frontChatServiceProvider.overrideWithValue(chatService),
          frontFilingServiceProvider.overrideWithValue(filing),
          frontChatThreadBuilderProvider.overrideWithValue(threadBuilder),
          frontConversationServiceProvider.overrideWithValue(conversations),
          frontConversationsProvider.overrideWith(
            (ref) async => FrontConversationIndex(
              conversations: [
                FrontConversation(
                  id: 'c-0',
                  title: 'Ice shelf survey',
                  lastActivity: DateTime(2026, 9, 2),
                  archived: true,
                ),
              ],
            ),
          ),
          frontChatThreadProvider.overrideWith(
            (Ref ref) => ref.watch(frontChatThreadBuilderProvider).build(),
          ),
        ],
      );
      addTearDown(archivedOnly.dispose);
      final keep = [
        archivedOnly.listen(frontConversationsProvider, (_, _) {}),
        archivedOnly.listen(frontActiveConversationProvider, (_, _) {}),
      ];
      addTearDown(() {
        for (final sub in keep) {
          sub.close();
        }
      });
      when(
        () => chatService.sendMessage(text: 'More', conversationId: 'c-0'),
      ).thenAnswer((_) async {});
      when(
        () => conversations.archive(any(), archived: any(named: 'archived')),
      ).thenThrow(StateError('db closed'));
      await archivedOnly.read(frontConversationsProvider.future);
      final archivedController = archivedOnly.read(
        frontChatControllerProvider.notifier,
      )..openConversation('c-0');

      await archivedController.sendText('More');

      verify(() => conversations.archive('c-0', archived: false)).called(1);
      final settled = archivedOnly.read(frontChatControllerProvider);
      expect(settled.failedMessage, isNull, reason: 'the turn was sent');
      expect(settled.isSending, isFalse);
      verify(
        () => chatService.sendMessage(text: 'More', conversationId: 'c-0'),
      ).called(1);
    });
  });

  group('send', () {
    test('creates the identity on first use, sends the trimmed draft, '
        'refreshes the thread, clears the composer and leaves the inbox '
        'filter', () async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenAnswer((_) async {});
      controller().updateDraft('  Hello ');
      final before = threadBuilder.builds;
      // Kept alive across the send: the filter is auto-disposed otherwise.
      final filter = container.listen(frontInboxFilterProvider, (_, _) {});
      addTearDown(filter.close);
      container.read(frontInboxFilterProvider.notifier).toggle();
      expect(container.read(frontInboxFilterProvider), isTrue);

      await controller().send();

      expect(container.read(frontInboxFilterProvider), isFalse);

      verifyInOrder([
        () => agentService.getOrCreate(),
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ]);
      expect(state().draft, isEmpty);
      expect(state().isSending, isFalse);
      expect(state().failedMessage, isNull);
      await container.read(frontChatThreadProvider.future);
      expect(threadBuilder.builds, before + 1);
    });

    test('an empty draft sends nothing', () async {
      controller().updateDraft('   ');
      await controller().send();
      verifyNever(() => agentService.getOrCreate());
      verifyNever(
        () => chatService.sendMessage(
          text: any(named: 'text'),
          conversationId: any(named: 'conversationId'),
        ),
      );
    });

    test('a chip tap sends its label as the next turn', () async {
      when(
        () => chatService.sendMessage(text: 'Swim 2 km', conversationId: 'c-1'),
      ).thenAnswer((_) async {});
      await controller().sendText('Swim 2 km');
      verify(
        () => chatService.sendMessage(text: 'Swim 2 km', conversationId: 'c-1'),
      ).called(1);
    });

    test(
      'a failed turn keeps the draft, offers the text for a retry and '
      'remembers the durable id so the retry re-wakes the same turn',
      () async {
        when(
          () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
        ).thenThrow(
          const FrontChatTurnException('boom', messageId: 'm-1'),
        );
        controller().updateDraft('Hello');

        await controller().send();

        expect(state().isSending, isFalse);
        expect(state().draft, 'Hello');
        expect(state().failedMessage, 'Hello');
        expect(state().failedMessageId, 'm-1');
      },
    );

    test('the box empties the moment the words are sent, not once her '
        'answer is in', () async {
      final answering = Completer<void>();
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenAnswer((_) => answering.future);
      controller().updateDraft('Hello');

      final sending = controller().send();
      await pumpEventQueue();

      expect(state().isSending, isTrue);
      expect(state().draft, isEmpty);
      answering.complete();
      await sending;
      expect(state().draft, isEmpty);
    });

    test('a failed send keeps what the user typed meanwhile, the failed '
        'words still offered for a retry', () async {
      final answering = Completer<void>();
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenAnswer((_) => answering.future);
      controller().updateDraft('Hello');

      final sending = controller().send();
      await pumpEventQueue();
      controller().updateDraft('And another thing');
      answering.completeError(
        const FrontChatTurnException('boom', messageId: 'm-1'),
      );
      await sending;

      expect(state().draft, 'And another thing');
      expect(state().failedMessage, 'Hello');
    });

    test(
      'a send that goes through keeps what the user typed meanwhile',
      () async {
        final answering = Completer<void>();
        when(
          () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
        ).thenAnswer((_) => answering.future);
        controller().updateDraft('Hello');

        final sending = controller().send();
        await pumpEventQueue();
        controller().updateDraft('And another thing');
        answering.complete();
        await sending;

        expect(state().draft, 'And another thing');
        expect(state().failedMessage, isNull);
      },
    );

    test('an unexpected error fails the turn without a durable id', () async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenThrow(StateError('db closed'));
      controller().updateDraft('Hello');

      await controller().send();

      expect(state().failedMessage, 'Hello');
      expect(state().failedMessageId, isNull);
    });
  });

  test('a retry of a turn that never persisted sends it to the '
      'conversation it was typed in', () async {
    var calls = 0;
    when(
      () => chatService.sendMessage(
        text: 'Hello',
        conversationId: 'c-1',
      ),
    ).thenAnswer((_) async {
      if (calls++ == 0) throw StateError('first');
    });
    controller().updateDraft('Hello');
    await controller().send();
    expect(state().failedMessage, 'Hello');

    await controller().retry();

    expect(calls, 2);
    expect(state().failedMessage, isNull);
  });

  group('a spoken turn', () {
    test('marks its conversation for a spoken reply, as of the send', () async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenAnswer((_) async {
        // Her reply can land before the send returns: the mark is there.
        expect(container.read(frontSpokenTurnProvider)?.conversationId, 'c-1');
      });
      controller().updateDraft('Hello');

      await controller().sendSpoken();

      final turn = container.read(frontSpokenTurnProvider);
      expect(turn?.conversationId, 'c-1');
      expect(turn?.spokenAt, isNotNull);
      expect(state().failedMessage, isNull);
    });

    test('a typed turn after it gets a written reply only', () async {
      when(
        () => chatService.sendMessage(
          text: any(named: 'text'),
          conversationId: 'c-1',
        ),
      ).thenAnswer((_) async {});
      controller().updateDraft('Hello');
      await controller().sendSpoken();
      expect(container.read(frontSpokenTurnProvider), isNotNull);

      controller().updateDraft('And the cave?');
      await controller().send();

      expect(container.read(frontSpokenTurnProvider), isNull);
    });

    test('a spoken turn whose wake fails waits for no reply either', () async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenThrow(const FrontChatTurnException('boom', messageId: 'm-1'));
      controller().updateDraft('Hello');

      await controller().sendSpoken();

      expect(container.read(frontSpokenTurnProvider), isNull);
      expect(state().failedMessageId, 'm-1');
    });

    test('a spoken turn that cannot be sent waits for no reply', () async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenThrow(StateError('db closed'));
      controller().updateDraft('Hello');

      await controller().sendSpoken();

      expect(container.read(frontSpokenTurnProvider), isNull);
      expect(state().failedMessage, 'Hello');
    });
  });

  group('retry', () {
    test("a failed turn keeps its cause; a retry's own failure replaces it "
        'and its success clears it', () async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenThrow(
        const FrontChatTurnException(
          'boom',
          messageId: 'm-1',
          failure: FrontTurnFailure.rateLimit,
        ),
      );
      var retries = 0;
      when(() => chatService.retryMessage(messageId: 'm-1')).thenAnswer((
        _,
      ) async {
        if (retries++ == 0) {
          throw const FrontChatTurnException(
            'again',
            messageId: 'm-1',
            failure: FrontTurnFailure.timeout,
          );
        }
      });
      controller().updateDraft('Hello');

      await controller().send();
      expect(state().failure, FrontTurnFailure.rateLimit);

      await controller().retry();
      expect(state().failure, FrontTurnFailure.timeout);

      await controller().retry();
      expect(state().failure, isNull);
      expect(state().failedMessage, isNull);
    });

    test(
      'with a durable id re-wakes that turn rather than sending again',
      () async {
        when(
          () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
        ).thenThrow(
          const FrontChatTurnException('boom', messageId: 'm-1'),
        );
        when(
          () => chatService.retryMessage(messageId: 'm-1'),
        ).thenAnswer((_) async {});
        controller().updateDraft('Hello');
        await controller().send();

        await controller().retry();

        verify(() => chatService.retryMessage(messageId: 'm-1')).called(1);
        verify(
          () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
        ).called(1);
        expect(state().failedMessage, isNull);
        expect(state().draft, isEmpty);
      },
    );

    test('without a durable id sends the text again', () async {
      var calls = 0;
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenAnswer((
        _,
      ) async {
        if (calls++ == 0) throw StateError('first');
      });
      controller().updateDraft('Hello');
      await controller().send();

      await controller().retry();

      expect(calls, 2);
      expect(state().failedMessage, isNull);
      verifyNever(
        () => chatService.retryMessage(messageId: any(named: 'messageId')),
      );
    });

    test('a failed turn stays with the conversation it was typed in', () async {
      var calls = 0;
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenAnswer((_) async {
        if (calls++ == 0) throw StateError('first');
      });
      controller().updateDraft('Hello');
      await controller().send();
      expect(state().failedConversationId, 'c-1');

      // The failure stays with its conversation: opening another leaves it
      // behind, so nothing typed in one can be retried into the other.
      controller().openConversation('c-2');
      expect(state().failedMessage, isNull);
      await controller().retry();
      expect(calls, 1);

      // Back in it, the words wait in the draft.
      controller().openConversation('c-1');
      expect(state().draft, 'Hello');
      verifyNever(
        () => chatService.sendMessage(
          text: any(named: 'text'),
          conversationId: 'c-2',
        ),
      );
    });

    test('a retry that fails again keeps the failure, with the id it '
        'learned', () async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenThrow(StateError('first'));
      controller().updateDraft('Hello');
      await controller().send();
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenThrow(
        const FrontChatTurnException('second', messageId: 'm-2'),
      );

      await controller().retry();

      expect(state().failedMessage, 'Hello');
      expect(state().failedMessageId, 'm-2');
      expect(state().draft, 'Hello');
    });

    test('a retry that fails for an unexpected reason keeps the id it '
        'already had', () async {
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenThrow(
        const FrontChatTurnException('boom', messageId: 'm-1'),
      );
      when(
        () => chatService.retryMessage(messageId: 'm-1'),
      ).thenThrow(StateError('db closed'));
      controller().updateDraft('Hello');
      await controller().send();

      await controller().retry();

      expect(state().isSending, isFalse);
      expect(state().failedMessage, 'Hello');
      expect(state().failedMessageId, 'm-1');
      expect(state().draft, 'Hello');
    });

    test('with nothing failed does nothing', () async {
      await controller().retry();
      verifyNever(
        () => chatService.sendMessage(
          text: any(named: 'text'),
          conversationId: any(named: 'conversationId'),
        ),
      );
    });
  });

  group('a door action', () {
    test('runs the filing service, keeps the door busy meanwhile, and '
        're-projects the thread after', () async {
      final gate = Completer<void>();
      when(() => filing.fileUnderOwner('d1')).thenAnswer((_) => gate.future);
      final before = threadBuilder.builds;

      final action = controller().fileUnderOwner('d1');
      expect(state().busyDoorIds, {'d1'});
      // A second tap while busy is a no-op.
      await controller().fileUnderOwner('d1');
      gate.complete();
      await action;

      verify(() => filing.fileUnderOwner('d1')).called(1);
      expect(state().busyDoorIds, isEmpty);
      expect(state().failedDoorIds, isEmpty);
      await container.read(frontChatThreadProvider.future);
      expect(threadBuilder.builds, before + 1);
    });

    test(
      'that fails marks the door, until its next action clears it',
      () async {
        when(() => filing.decline('d1')).thenThrow(StateError('gone'));
        await controller().decline('d1');
        expect(state().failedDoorIds, {'d1'});
        expect(state().busyDoorIds, isEmpty);

        when(() => filing.decline('d1')).thenAnswer((_) async {});
        await controller().decline('d1');
        expect(state().failedDoorIds, isEmpty);
      },
    );

    test('every action reaches its service call', () async {
      when(() => filing.undoDecline('d')).thenAnswer((_) async {});
      when(() => filing.takeBack('d')).thenAnswer((_) async {});
      when(() => filing.makeTask('d')).thenAnswer((_) async {});
      when(() => filing.saveAsNote('d')).thenAnswer((_) async {});
      when(() => filing.makeEvent('d')).thenAnswer((_) async {});
      final day = DateTime(2026, 11);
      when(() => filing.markDayPlanned('d', day)).thenAnswer((_) async {});
      when(() => filing.markProjectCreated('d', 'p')).thenAnswer((_) async {});
      await controller().undoDecline('d');
      await controller().takeBack('d');
      await controller().makeTask('d');
      await controller().saveAsNote('d');
      await controller().makeEvent('d');
      await controller().planDay('d', () async => day);
      await controller().newProject('d', () async => 'p');
      // Nothing accepted, nothing made: nothing settles.
      await controller().planDay('d', () async => null);
      await controller().newProject('d', () async => null);
      verifyInOrder([
        () => filing.undoDecline('d'),
        () => filing.takeBack('d'),
        () => filing.makeTask('d'),
        () => filing.saveAsNote('d'),
        () => filing.makeEvent('d'),
        () => filing.markDayPlanned('d', day),
        () => filing.markProjectCreated('d', 'p'),
      ]);
      verifyNoMoreInteractions(filing);
    });

    test('making a task answers whether it was made: true once made, false '
        'when it failed or the door was already busy', () async {
      final gate = Completer<void>();
      when(() => filing.makeTask('d1')).thenAnswer((_) => gate.future);
      final made = controller().makeTask('d1');
      expect(await controller().makeTask('d1'), isFalse);
      gate.complete();
      expect(await made, isTrue);

      when(() => filing.makeTask('d1')).thenThrow(StateError('gone'));
      expect(await controller().makeTask('d1'), isFalse);
      expect(state().failedDoorIds, {'d1'});
    });

    test("the doors' state survives a send settling either way", () async {
      when(() => filing.decline('d1')).thenThrow(StateError('gone'));
      await controller().decline('d1');
      when(
        () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
      ).thenAnswer((_) async {});
      controller().updateDraft('Hello');
      await controller().send();
      expect(state().failedDoorIds, {'d1'});
      when(
        () => chatService.sendMessage(text: 'Again', conversationId: 'c-1'),
      ).thenThrow(StateError('x'));
      controller().updateDraft('Again');
      await controller().send();
      expect(state().failedDoorIds, {'d1'});
      expect(state().failedMessage, 'Again');
    });
  });

  group('categories', () {
    // The penguin world's categories she may see.
    final penguins = CategoryTestUtils.createTestCategory(
      id: 'cat-penguins',
      name: 'Penguin Operations',
    );
    final habitat = CategoryTestUtils.createTestCategory(
      id: 'cat-habitat',
      name: 'Habitat Engineering',
    );

    late ProviderContainer scoped;

    /// `c-1`'s scope as the index reads it now: a send can change it.
    var storedScope = const <String>{};

    /// A container whose open conversation `c-1` was last scoped to
    /// [stored], with [options] the categories she may see — still loading
    /// unless [catalogLoaded].
    Future<void> open({
      Set<String> stored = const {},
      List<CategoryDefinition>? options,
      bool catalogLoaded = true,
    }) async {
      storedScope = stored;
      final catalog = StreamController<List<CategoryDefinition>>();
      addTearDown(catalog.close);
      if (catalogLoaded) catalog.add(options ?? [penguins, habitat]);
      scoped = ProviderContainer(
        overrides: [
          frontAgentServiceProvider.overrideWithValue(agentService),
          frontChatServiceProvider.overrideWithValue(chatService),
          frontChatThreadBuilderProvider.overrideWithValue(threadBuilder),
          frontConversationServiceProvider.overrideWithValue(conversations),
          categoriesStreamProvider.overrideWith((ref) => catalog.stream),
          frontMentionCategoriesProvider.overrideWith(
            (ref) => ref.watch(categoriesStreamProvider).value ?? const [],
          ),
          frontConversationsProvider.overrideWith(
            (ref) async => FrontConversationIndex(
              conversations: [
                FrontConversation(
                  id: 'c-1',
                  title: 'Census',
                  lastActivity: clock.now(),
                  archived: false,
                  categoryIds: storedScope,
                ),
                FrontConversation(
                  id: 'c-2',
                  title: 'Heat pump',
                  lastActivity: clock.now().subtract(
                    const Duration(minutes: 1),
                  ),
                  archived: false,
                ),
              ],
            ),
          ),
          frontChatThreadProvider.overrideWith(
            (Ref ref) async => FrontChatThread.empty,
          ),
        ],
      );
      addTearDown(scoped.dispose);
      // Kept alive across the calls, as the surface keeps them.
      final subs = [
        scoped.listen(categoriesStreamProvider, (_, _) {}),
        scoped.listen(frontActiveConversationProvider, (_, _) {}),
        scoped.listen(frontConversationsProvider, (_, _) {}),
        scoped.listen(frontInboxFilterProvider, (_, _) {}),
      ];
      addTearDown(() {
        for (final sub in subs) {
          sub.close();
        }
      });
      await scoped.read(frontActiveConversationProvider.future);
      await pumpEventQueue();
    }

    FrontChatController composer() =>
        scoped.read(frontChatControllerProvider.notifier);
    FrontChatCategoryPicker picker() =>
        scoped.read(frontChatCategoryPickProvider.notifier);

    void stubSend() => when(
      () => chatService.sendMessage(
        text: any(named: 'text'),
        conversationId: any(named: 'conversationId'),
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer((_) async {});

    Set<String> sentWith(String text) =>
        verify(
              () => chatService.sendMessage(
                text: text,
                conversationId: any(named: 'conversationId'),
                categoryIds: captureAny(named: 'categoryIds'),
              ),
            ).captured.single
            as Set<String>;

    test('a send carries the category picked for its conversation', () async {
      await open();
      stubSend();
      picker().pick('c-1', 'cat-penguins');

      await composer().sendText('How many chicks?');

      verify(
        () => chatService.sendMessage(
          text: 'How many chicks?',
          conversationId: 'c-1',
          categoryIds: {'cat-penguins'},
        ),
      ).called(1);
    });

    test('with nothing picked, a send carries the scope of the '
        "conversation's newest turn", () async {
      await open(stored: {'cat-habitat'});
      stubSend();

      await composer().sendText('And the vents?');

      expect(sentWith('And the vents?'), {'cat-habitat'});
    });

    test('"Everything" picked over a stored scope carries none', () async {
      await open(stored: {'cat-habitat'});
      stubSend();
      picker().pick('c-1', null);

      await composer().sendText('Anything at all?');

      expect(sentWith('Anything at all?'), isEmpty);
    });

    test('a pick made in another conversation is not carried', () async {
      await open();
      stubSend();
      picker().pick('c-2', 'cat-penguins');

      await composer().sendText('Hello');

      expect(sentWith('Hello'), isEmpty);
    });

    test('a category she may no longer see is not carried', () async {
      await open(stored: {'cat-habitat'}, options: [penguins]);
      stubSend();

      await composer().sendText('Hello');

      expect(sentWith('Hello'), isEmpty);
    });

    test('a turn that failed keeps the scope it was typed under, and its '
        'retry carries it though the pick changed since', () async {
      await open();
      picker().pick('c-1', 'cat-penguins');
      when(
        () => chatService.sendMessage(
          text: 'Count them',
          conversationId: 'c-1',
          categoryIds: {'cat-penguins'},
        ),
      ).thenThrow(const FrontChatTurnException('offline'));

      await composer().sendText('Count them');
      expect(
        scoped.read(frontChatControllerProvider).failedCategoryIds,
        {'cat-penguins'},
      );

      picker().pick('c-1', 'cat-habitat');
      stubSend();
      await composer().retry();

      verify(
        () => chatService.sendMessage(
          text: 'Count them',
          conversationId: 'c-1',
          categoryIds: {'cat-penguins'},
        ),
      ).called(2);
      expect(scoped.read(frontChatControllerProvider).failedMessage, isNull);
    });

    test('a send that fails for another reason keeps its scope too', () async {
      await open();
      picker().pick('c-1', 'cat-habitat');
      when(
        () => chatService.sendMessage(
          text: any(named: 'text'),
          conversationId: any(named: 'conversationId'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenThrow(StateError('db closed'));

      await composer().sendText('Fix it');

      expect(
        scoped.read(frontChatControllerProvider).failedCategoryIds,
        {'cat-habitat'},
      );
    });

    test('a retry that fails again keeps the scope for the next one', () async {
      await open();
      picker().pick('c-1', 'cat-habitat');
      when(
        () => chatService.sendMessage(
          text: any(named: 'text'),
          conversationId: any(named: 'conversationId'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenThrow(const FrontChatTurnException('offline'));
      await composer().sendText('Fix it');

      await composer().retry();
      expect(
        scoped.read(frontChatControllerProvider).failedCategoryIds,
        {'cat-habitat'},
      );

      when(
        () => chatService.sendMessage(
          text: any(named: 'text'),
          conversationId: any(named: 'conversationId'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenThrow(StateError('db closed'));
      await composer().retry();
      expect(
        scoped.read(frontChatControllerProvider).failedCategoryIds,
        {'cat-habitat'},
      );
    });

    test('while the categories are still loading, a send carries the stored '
        'scope rather than dropping it', () async {
      await open(stored: {'cat-habitat'}, catalogLoaded: false);
      stubSend();

      await composer().sendText('And the vents?');

      expect(sentWith('And the vents?'), {'cat-habitat'});
    });

    test('a pick sent is dropped once the index shows the turn carrying it: '
        'the stored scope speaks from then on', () async {
      await open();
      picker().pick('c-1', 'cat-penguins');
      when(
        () => chatService.sendMessage(
          text: any(named: 'text'),
          conversationId: any(named: 'conversationId'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) async => storedScope = {'cat-penguins'});

      await composer().sendText('Count them');
      await scoped.read(frontConversationsProvider.future);
      await pumpEventQueue();

      expect(scoped.read(frontChatCategoryPickProvider), isNull);
      expect(scoped.read(frontChatCategoryProvider), penguins);
    });

    test('a pick made while the turn was on its way is kept', () async {
      await open();
      picker().pick('c-1', 'cat-penguins');
      when(
        () => chatService.sendMessage(
          text: any(named: 'text'),
          conversationId: any(named: 'conversationId'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) async {
        storedScope = {'cat-penguins'};
        picker().pick('c-1', 'cat-habitat');
      });

      await composer().sendText('Count them');
      await scoped.read(frontConversationsProvider.future);
      await pumpEventQueue();

      expect(
        scoped.read(frontChatCategoryPickProvider)?.categoryId,
        'cat-habitat',
      );
    });

    test('a newer turn from another device, in another category, wins over '
        'the pick sent: the next send carries its scope', () async {
      await open();
      picker().pick('c-1', 'cat-penguins');
      when(
        () => chatService.sendMessage(
          text: any(named: 'text'),
          conversationId: any(named: 'conversationId'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) async => storedScope = {'cat-habitat'});

      await composer().sendText('Count them');
      await scoped.read(frontConversationsProvider.future);
      await pumpEventQueue();

      expect(scoped.read(frontChatCategoryPickProvider), isNull);
      expect(scoped.read(frontChatCategoryProvider), habitat);
      await composer().sendText('And the vents?');
      expect(sentWith('And the vents?'), {'cat-habitat'});
    });

    test('switching conversation drops a pick not yet sent; opening the one '
        'already open keeps it', () async {
      await open();
      picker().pick('c-1', 'cat-penguins');

      composer().openConversation('c-1');
      expect(scoped.read(frontChatCategoryPickProvider), isNotNull);

      composer().openConversation('c-2');
      expect(scoped.read(frontChatCategoryPickProvider), isNull);
    });

    test('a new chat drops the pick of the one left', () async {
      await open();
      picker().pick('c-1', 'cat-penguins');

      composer().startConversation();

      expect(scoped.read(frontChatCategoryPickProvider), isNull);
    });
  });
}
