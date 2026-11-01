import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_thread_builder.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_category_scope.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

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

  test('a draft is kept and clears a previous failure', () async {
    when(
      () => chatService.sendMessage(text: 'Hello', conversationId: 'c-1'),
    ).thenThrow(StateError('db closed'));
    controller().updateDraft('Hello');
    await controller().send();
    expect(state().failedMessage, 'Hello');

    controller().updateDraft('Hel');

    expect(state().draft, 'Hel');
    expect(state().isSending, isFalse);
    expect(state().failedMessage, isNull);
    expect(state().failedMessageId, isNull);
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

  test("a send carries the open conversation's chips", () async {
    when(
      () => chatService.sendMessage(
        text: 'Hello',
        conversationId: 'c-1',
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer((_) async {});
    container.read(frontConversationCategoriesProvider.notifier)
      ..toggle('c-1', 'colony')
      ..toggle('c-2', 'nests');
    controller().updateDraft('Hello');

    await controller().send();

    verify(
      () => chatService.sendMessage(
        text: 'Hello',
        conversationId: 'c-1',
        categoryIds: {'colony'},
      ),
    ).called(1);
  });

  test("a retry of a turn that never persisted keeps its conversation's "
      'chips', () async {
    var calls = 0;
    when(
      () => chatService.sendMessage(
        text: 'Hello',
        conversationId: 'c-1',
        categoryIds: {'colony'},
      ),
    ).thenAnswer((_) async {
      if (calls++ == 0) throw StateError('first');
    });
    container
        .read(frontConversationCategoriesProvider.notifier)
        .toggle('c-1', 'colony');
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
      final day = DateTime(2026, 11);
      when(() => filing.markDayPlanned('d', day)).thenAnswer((_) async {});
      when(() => filing.markProjectCreated('d', 'p')).thenAnswer((_) async {});
      await controller().undoDecline('d');
      await controller().takeBack('d');
      await controller().makeTask('d');
      await controller().saveAsNote('d');
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
        () => filing.markDayPlanned('d', day),
        () => filing.markProjectCreated('d', 'p'),
      ]);
      verifyNoMoreInteractions(filing);
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
}
