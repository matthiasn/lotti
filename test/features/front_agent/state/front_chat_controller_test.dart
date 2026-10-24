import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_thread_builder.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

/// Counts how often the thread was re-projected: the controller's
/// invalidation is what the surface relies on after an awaited turn.
class _CountingBuilder extends FrontChatThreadBuilder {
  _CountingBuilder() : super(repository: MockAgentRepository());

  int builds = 0;

  @override
  Future<FrontChatThread> build() async {
    builds++;
    return FrontChatThread.empty;
  }
}

void main() {
  late MockFrontAgentService agentService;
  late MockFrontChatService chatService;
  late _CountingBuilder threadBuilder;
  late ProviderContainer container;

  setUp(() {
    agentService = MockFrontAgentService();
    chatService = MockFrontChatService();
    threadBuilder = _CountingBuilder();
    when(
      () => agentService.getOrCreate(),
    ).thenAnswer((_) async => makeTestIdentity(id: 'front_agent'));
    container = ProviderContainer(
      overrides: [
        frontAgentServiceProvider.overrideWithValue(agentService),
        frontChatServiceProvider.overrideWithValue(chatService),
        frontChatThreadBuilderProvider.overrideWithValue(threadBuilder),
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

  test('a draft is kept and clears a previous failure', () {
    controller().updateDraft('Hel');
    expect(state().draft, 'Hel');
    expect(state().isSending, isFalse);
  });

  group('send', () {
    test('creates the identity on first use, sends the trimmed draft, '
        'refreshes the thread and clears the composer', () async {
      when(
        () => chatService.sendMessage(text: 'Hello'),
      ).thenAnswer((_) async {});
      controller().updateDraft('  Hello ');
      final before = threadBuilder.builds;

      await controller().send();

      verifyInOrder([
        () => agentService.getOrCreate(),
        () => chatService.sendMessage(text: 'Hello'),
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
      verifyNever(() => chatService.sendMessage(text: any(named: 'text')));
    });

    test('a chip tap sends its label as the next turn', () async {
      when(
        () => chatService.sendMessage(text: 'Swim 2 km'),
      ).thenAnswer((_) async {});
      await controller().sendText('Swim 2 km');
      verify(() => chatService.sendMessage(text: 'Swim 2 km')).called(1);
    });

    test(
      'a failed turn keeps the draft, offers the text for a retry and '
      'remembers the durable id so the retry re-wakes the same turn',
      () async {
        when(() => chatService.sendMessage(text: 'Hello')).thenThrow(
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
        () => chatService.sendMessage(text: 'Hello'),
      ).thenThrow(StateError('db closed'));
      controller().updateDraft('Hello');

      await controller().send();

      expect(state().failedMessage, 'Hello');
      expect(state().failedMessageId, isNull);
    });
  });

  group('retry', () {
    test(
      'with a durable id re-wakes that turn rather than sending again',
      () async {
        when(() => chatService.sendMessage(text: 'Hello')).thenThrow(
          const FrontChatTurnException('boom', messageId: 'm-1'),
        );
        when(
          () => chatService.retryMessage(messageId: 'm-1'),
        ).thenAnswer((_) async {});
        controller().updateDraft('Hello');
        await controller().send();

        await controller().retry();

        verify(() => chatService.retryMessage(messageId: 'm-1')).called(1);
        verify(() => chatService.sendMessage(text: 'Hello')).called(1);
        expect(state().failedMessage, isNull);
        expect(state().draft, isEmpty);
      },
    );

    test('without a durable id sends the text again', () async {
      var calls = 0;
      when(() => chatService.sendMessage(text: 'Hello')).thenAnswer((
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

    test('a retry that fails again keeps the failure, with the id it '
        'learned', () async {
      when(
        () => chatService.sendMessage(text: 'Hello'),
      ).thenThrow(StateError('first'));
      controller().updateDraft('Hello');
      await controller().send();
      when(() => chatService.sendMessage(text: 'Hello')).thenThrow(
        const FrontChatTurnException('second', messageId: 'm-2'),
      );

      await controller().retry();

      expect(state().failedMessage, 'Hello');
      expect(state().failedMessageId, 'm-2');
      expect(state().draft, 'Hello');
    });

    test('with nothing failed does nothing', () async {
      await controller().retry();
      verifyNever(() => chatService.sendMessage(text: any(named: 'text')));
    });
  });
}
