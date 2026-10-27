import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_thread_builder.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
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
  late MockFrontFilingService filing;
  late _CountingBuilder threadBuilder;
  late ProviderContainer container;

  setUp(() {
    agentService = MockFrontAgentService();
    chatService = MockFrontChatService();
    filing = MockFrontFilingService();
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
      () => chatService.sendMessage(text: 'Hello'),
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

  group('send', () {
    test('creates the identity on first use, sends the trimmed draft, '
        'refreshes the thread, clears the composer and leaves the inbox '
        'filter', () async {
      when(
        () => chatService.sendMessage(text: 'Hello'),
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

    test('a retry that fails for an unexpected reason keeps the id it '
        'already had', () async {
      when(() => chatService.sendMessage(text: 'Hello')).thenThrow(
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
      verifyNever(() => chatService.sendMessage(text: any(named: 'text')));
    });
  });

  group('a door action', () {
    test('runs the filing service, keeps the door busy meanwhile, and '
        're-projects the thread after', () async {
      final gate = Completer<void>();
      when(() => filing.fileUnderTask('d1')).thenAnswer((_) => gate.future);
      final before = threadBuilder.builds;

      final action = controller().fileUnderTask('d1');
      expect(state().busyDoorIds, {'d1'});
      // A second tap while busy is a no-op.
      await controller().fileUnderTask('d1');
      gate.complete();
      await action;

      verify(() => filing.fileUnderTask('d1')).called(1);
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
      await controller().undoDecline('d');
      await controller().takeBack('d');
      await controller().makeTask('d');
      await controller().saveAsNote('d');
      verifyInOrder([
        () => filing.undoDecline('d'),
        () => filing.takeBack('d'),
        () => filing.makeTask('d'),
        () => filing.saveAsNote('d'),
      ]);
    });

    test("the doors' state survives a send settling either way", () async {
      when(() => filing.decline('d1')).thenThrow(StateError('gone'));
      await controller().decline('d1');
      when(
        () => chatService.sendMessage(text: 'Hello'),
      ).thenAnswer((_) async {});
      controller().updateDraft('Hello');
      await controller().send();
      expect(state().failedDoorIds, {'d1'});
      when(
        () => chatService.sendMessage(text: 'Again'),
      ).thenThrow(StateError('x'));
      controller().updateDraft('Again');
      await controller().send();
      expect(state().failedDoorIds, {'d1'});
      expect(state().failedMessage, 'Again');
    });
  });
}
