import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_cost.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';

import '../../ai_consumption/test_utils.dart';

void main() {
  final at = DateTime(2026, 11, 11, 10);

  AgentChatMessage message(String id, AgentChatRole role, {String? runKey}) =>
      AgentChatMessage(
        id: id,
        role: role,
        text: id,
        createdAt: at,
        runKey: runKey,
      );

  /// Each run's recorded totals; a run missing here is still loading, and
  /// one in [live] delivers them as that stream does.
  ProviderContainer containerFor(
    FutureOr<FrontChatThread> Function() thread,
    Map<String, ConsumptionTotals> runs, {
    List<String>? asked,
    Map<String, Stream<ConsumptionTotals>> live = const {},
  }) {
    final container = ProviderContainer(
      overrides: [
        frontChatThreadProvider.overrideWith((ref) async => thread()),
        agentRunConsumptionTotalsProvider.overrideWith((ref, run) {
          asked?.add('${run.agentId}/${run.runKey}');
          final totals = runs[run.runKey];
          return live[run.runKey] ??
              (totals == null
                  ? const Stream<ConsumptionTotals>.empty()
                  : Stream.value(totals));
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ConsumptionTotals?> settled(ProviderContainer container) async {
    final sub = container.listen(frontConversationCostProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(frontChatThreadProvider.future);
    // Let each run's stream deliver.
    await pumpEventQueue();
    return sub.read();
  }

  test('is unknown until the thread is', () {
    final pending = Completer<FrontChatThread>();
    final container = containerFor(() => pending.future, const {});

    expect(container.read(frontConversationCostProvider), isNull);
    pending.complete(FrontChatThread.empty);
  });

  test('sums every run of the conversation, each once, as recorded on her '
      'own agent — those the window no longer shows included', () async {
    final asked = <String>[];
    final container = containerFor(
      () => FrontChatThread(
        // Only the newest reply is in view; the conversation ran twice.
        messages: [message('a3', AgentChatRole.agent, runKey: 'run-2')],
        runKeys: const {'run-1', 'run-2'},
      ),
      {
        'run-1': makeConsumptionTotals(callCount: 2, totalTokens: 900),
        'run-2': makeConsumptionTotals(callCount: 1, totalTokens: 100),
        'other': makeConsumptionTotals(callCount: 9, totalTokens: 9000),
      },
      asked: asked,
    );

    final cost = (await settled(container))!;

    expect(cost.callCount, 3);
    expect(cost.totalTokens, 1000);
    expect(asked.toSet(), {'$frontAgentId/run-1', '$frontAgentId/run-2'});
  });

  test('a run still loading is counted once it arrives: the total grows in '
      'place rather than blanking', () async {
    final arriving = StreamController<ConsumptionTotals>();
    addTearDown(arriving.close);
    final container = containerFor(
      () => FrontChatThread(
        messages: [
          message('a1', AgentChatRole.agent, runKey: 'run-1'),
          message('a2', AgentChatRole.agent, runKey: 'run-new'),
        ],
        runKeys: const {'run-1', 'run-new'},
      ),
      {'run-1': makeConsumptionTotals(callCount: 2, totalTokens: 900)},
      live: {'run-new': arriving.stream},
    );

    final partial = (await settled(container))!;
    expect(partial.callCount, 2);
    expect(partial.totalTokens, 900);

    arriving.add(makeConsumptionTotals(callCount: 1, totalTokens: 100));
    await pumpEventQueue();

    final whole = container.read(frontConversationCostProvider)!;
    expect(whole.callCount, 3);
    expect(whole.totalTokens, 1000);
  });

  test('is none in the inbox, and reads no run of the conversations it '
      'gathers', () async {
    final asked = <String>[];
    final container = containerFor(
      () => FrontChatThread(
        messages: [message('a1', AgentChatRole.agent, runKey: 'run-1')],
        runKeys: const {'run-1'},
      ),
      {'run-1': makeConsumptionTotals(callCount: 2, totalTokens: 900)},
      asked: asked,
    );
    container.read(frontInboxFilterProvider.notifier).toggle();

    expect(await settled(container), isNull);
    expect(asked, isEmpty);
  });

  test('a conversation with no reply yet has cost nothing', () async {
    final container = containerFor(
      () => FrontChatThread(messages: [message('u1', AgentChatRole.user)]),
      const {},
    );

    expect(await settled(container), ConsumptionTotals.empty);
  });
}
