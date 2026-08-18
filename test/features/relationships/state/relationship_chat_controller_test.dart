import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/relationships/service/relationship_chat_service.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/state/relationship_chat_controller.dart';
import 'package:lotti/features/relationships/state/relationship_nudge_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  const agentId = 'relationship_agent:person-1';

  late MockRelationshipChatService service;

  ProviderContainer container({List<Override> extra = const []}) {
    final c = ProviderContainer(
      overrides: [
        relationshipChatServiceProvider.overrideWithValue(service),
        ...extra,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    service = MockRelationshipChatService();
  });

  test('composer copyWith retains a failure until explicitly cleared', () {
    final failed = const RelationshipChatComposerState().copyWith(
      failedMessage: 'How is Anna?',
      failedMessageId: 'message-1',
    );
    final retained = failed.copyWith(draft: 'Still here');
    final cleared = retained.copyWith(clearFailure: true);

    expect(retained.failedMessage, 'How is Anna?');
    expect(retained.failedMessageId, 'message-1');
    expect(cleared.failedMessage, isNull);
    expect(cleared.failedMessageId, isNull);
  });

  test('an unexpected send failure keeps the draft with no turn id', () async {
    when(
      () => service.sendMessage(agentId: agentId, text: 'Try this.'),
    ).thenThrow(StateError('database unavailable'));
    final c = container();
    final controller = c.read(
      relationshipChatControllerProvider(agentId).notifier,
    )..updateDraft('Try this.');

    await controller.send();

    final state = c.read(relationshipChatControllerProvider(agentId));
    expect(state.draft, 'Try this.');
    expect(state.failedMessage, 'Try this.');
    expect(state.failedMessageId, isNull);
  });

  test('retry without a durable id resends the original text', () async {
    var attempts = 0;
    when(
      () => service.sendMessage(agentId: agentId, text: 'Try this.'),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw StateError('database unavailable');
    });
    final c = container();
    final controller = c.read(
      relationshipChatControllerProvider(agentId).notifier,
    )..updateDraft('Try this.');

    await controller.send();
    await controller.retry();

    expect(attempts, 2);
    expect(
      c.read(relationshipChatControllerProvider(agentId)).failedMessage,
      isNull,
    );
  });

  test('retry preserves the durable turn id across typed and unknown '
      'errors — the turn is never re-persisted', () async {
    when(
      () => service.sendMessage(agentId: agentId, text: 'Keep trying.'),
    ).thenThrow(
      const RelationshipChatTurnException('offline', messageId: 'message-1'),
    );
    var retryAttempts = 0;
    when(
      () => service.retryMessage(agentId: agentId, messageId: 'message-1'),
    ).thenAnswer((_) async {
      retryAttempts++;
      if (retryAttempts == 1) {
        throw const RelationshipChatTurnException('still offline');
      }
      throw StateError('database unavailable');
    });
    final c = container();
    final controller = c.read(
      relationshipChatControllerProvider(agentId).notifier,
    )..updateDraft('Keep trying.');
    await controller.send();

    await controller.retry();
    var state = c.read(relationshipChatControllerProvider(agentId));
    expect(state.failedMessage, 'Keep trying.');
    expect(state.failedMessageId, 'message-1');

    await controller.retry();
    state = c.read(relationshipChatControllerProvider(agentId));
    expect(state.draft, 'Keep trying.');
    expect(state.failedMessage, 'Keep trying.');
    expect(state.failedMessageId, 'message-1');
    expect(retryAttempts, 2);
    verify(
      () => service.retryMessage(agentId: agentId, messageId: 'message-1'),
    ).called(2);
    verify(
      () => service.sendMessage(agentId: agentId, text: 'Keep trying.'),
    ).called(1);
  });

  test('a successful retry clears the failure and the draft', () async {
    when(
      () => service.sendMessage(agentId: agentId, text: 'Keep me honest.'),
    ).thenThrow(
      const RelationshipChatTurnException('offline', messageId: 'message-1'),
    );
    when(
      () => service.retryMessage(agentId: agentId, messageId: 'message-1'),
    ).thenAnswer((_) async {});
    final c = container();
    final controller = c.read(
      relationshipChatControllerProvider(agentId).notifier,
    )..updateDraft('Keep me honest.');

    await controller.send();
    await controller.retry();

    final state = c.read(relationshipChatControllerProvider(agentId));
    expect(state.draft, isEmpty);
    expect(state.failedMessage, isNull);
    expect(state.failedMessageId, isNull);
  });

  test('empty sends and retries are no-ops while editing clears the '
      'failure', () async {
    final c = container();
    final controller = c.read(
      relationshipChatControllerProvider(agentId).notifier,
    );

    await controller.send();
    await controller.retry();
    controller.updateDraft('Fresh thought');

    final state = c.read(relationshipChatControllerProvider(agentId));
    expect(state.draft, 'Fresh thought');
    expect(state.failedMessage, isNull);
    verifyNever(
      () => service.sendMessage(
        agentId: any(named: 'agentId'),
        text: any(named: 'text'),
      ),
    );
    verifyNever(
      () => service.retryMessage(
        agentId: any(named: 'agentId'),
        messageId: any(named: 'messageId'),
      ),
    );
  });

  test('a committed chat wake refreshes the chat projection and the '
      'relationship banner source', () async {
    when(
      () => service.sendMessage(agentId: agentId, text: 'New banner please.'),
    ).thenAnswer((_) async {});
    var bannerReads = 0;
    var chatReads = 0;
    final c = container(
      extra: [
        activeRelationshipNudgesProvider.overrideWith((ref) async {
          bannerReads++;
          return [];
        }),
        agentChatProjectionProvider(agentId).overrideWith((ref) async {
          chatReads++;
          return [];
        }),
      ],
    );
    await c.read(activeRelationshipNudgesProvider.future);
    await c.read(agentChatProjectionProvider(agentId).future);
    expect(bannerReads, 1);
    expect(chatReads, 1);

    final controller = c.read(
      relationshipChatControllerProvider(agentId).notifier,
    )..updateDraft('New banner please.');
    await controller.send();
    await c.read(activeRelationshipNudgesProvider.future);
    await c.read(agentChatProjectionProvider(agentId).future);

    expect(bannerReads, 2);
    expect(chatReads, 2);
  });
  test('a committed snooze immediately feeds the shared dock suppression '
      'map — a background refresh cannot flash the snoozed banner back '
      '(the GoalChatController pattern)', () async {
    final repository = MockAgentRepository();
    final now = DateTime.utc(2026, 8, 16, 12);
    final until = now.add(const Duration(hours: 3));
    when(
      () => service.sendMessage(agentId: agentId, text: 'Snooze this ad.'),
    ).thenAnswer((_) async {});
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.relationshipNudge,
      ),
    ).thenAnswer(
      (_) async => [
        _relationshipNudge(
          id: 'snoozed',
          provenance: {'snoozedUntil': until.toIso8601String()},
        ),
        _relationshipNudge(id: 'still-visible'),
      ],
    );
    final c = container(
      extra: [agentRepositoryProvider.overrideWithValue(repository)],
    );
    final controller = c.read(
      relationshipChatControllerProvider(agentId).notifier,
    )..updateDraft('Snooze this ad.');

    await withClock(Clock.fixed(now), controller.send);

    expect(c.read(locallySnoozedNudgeDeadlinesProvider), {
      'snoozed': (activation: 1, until: until),
    });
  });
}

RelationshipNudgeEntity _relationshipNudge({
  required String id,
  Map<String, String> provenance = const {},
}) =>
    AgentDomainEntity.relationshipNudge(
          id: id,
          agentId: 'relationship_agent:person-1',
          status: NudgeStatus.active,
          brief: const NudgeBrief(
            headline: 'Check in with Anna.',
            tone: NudgeTone.nudge,
            animation: NudgeBannerAnimation.steady,
          ),
          briefDigest: id,
          createdAt: DateTime(2026, 8, 11),
          updatedAt: DateTime(2026, 8, 11),
          vectorClock: null,
          provenance: provenance,
        )
        as RelationshipNudgeEntity;
