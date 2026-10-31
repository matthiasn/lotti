import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/service/front_chat_thread_builder.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _CountingBuilder extends FrontChatThreadBuilder {
  _CountingBuilder(this.specialists) : super(repository: MockAgentRepository());

  final Set<String> specialists;
  int builds = 0;

  /// What each build was asked for: the conversation and the excluded.
  final asked = <(String?, Set<String>)>[];

  /// When set, every build after the first waits on it — a re-projection
  /// still in flight.
  Completer<void>? gate;

  @override
  Future<FrontChatThread> build({
    String? conversationId,
    Set<String> excluded = const {},
  }) async {
    builds++;
    asked.add((conversationId, excluded));
    if (builds > 1 && gate != null) await gate!.future;
    return FrontChatThread(
      messages: const [],
      specialistAgentIds: specialists,
    );
  }
}

void main() {
  late StreamController<WakeRunCompletion> completions;
  late MockWakeOrchestrator orchestrator;
  late StreamController<Set<String>> pings;
  late StreamController<Set<String>> specialistPings;

  setUp(() {
    completions = StreamController<WakeRunCompletion>.broadcast();
    pings = StreamController<Set<String>>.broadcast();
    specialistPings = StreamController<Set<String>>.broadcast();
    addTearDown(specialistPings.close);
    orchestrator = MockWakeOrchestrator();
    when(() => orchestrator.runCompletions).thenAnswer(
      (_) => completions.stream,
    );
    addTearDown(completions.close);
    addTearDown(pings.close);
  });

  ProviderContainer containerWith(_CountingBuilder builder) {
    final container = ProviderContainer(
      overrides: [
        frontChatThreadBuilderProvider.overrideWithValue(builder),
        wakeOrchestratorProvider.overrideWithValue(orchestrator),
        agentUpdateStreamProvider(
          frontAgentId,
        ).overrideWith((ref) => pings.stream),
        agentUpdateStreamProvider(
          'goal-swim',
        ).overrideWith((ref) => specialistPings.stream),
        frontActiveConversationProvider.overrideWith((ref) async => 'c-1'),
        frontConversationsProvider.overrideWith(
          (ref) async => const FrontConversationIndex(
            conversations: [],
            deletedIds: {'c-gone'},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('shows the active conversation; with the inbox filter on, every '
      'conversation but the deleted', () async {
    final builder = _CountingBuilder(const {});
    final container = containerWith(builder);
    final filter = container.listen(frontInboxFilterProvider, (_, _) {});
    addTearDown(filter.close);
    final sub = container.listen(frontChatThreadProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(frontChatThreadProvider.future);
    expect(builder.asked.last.$1, 'c-1');
    expect(builder.asked.last.$2, isEmpty);

    container.read(frontInboxFilterProvider.notifier).toggle();
    await container.read(frontChatThreadProvider.future);
    expect(builder.asked.last.$1, isNull);
    expect(builder.asked.last.$2, {'c-gone'});
  });

  test('builds from the repository and wires the builder from its leaf', () {
    final container = ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(MockAgentRepository()),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(frontChatThreadBuilderProvider),
      isA<FrontChatThreadBuilder>(),
    );
  });

  test('re-projects when a specialist a door handed a turn to finishes a '
      'wake, and ignores every other completion', () async {
    final builder = _CountingBuilder({'goal-swim'});
    final container = containerWith(builder)
      ..listen(frontChatThreadProvider, (_, _) {});
    await container.read(frontChatThreadProvider.future);
    expect(builder.builds, 1);

    completions.add(
      const WakeRunCompletion(
        runKey: 'r1',
        status: WakeRunStatus.completed,
        agentId: 'someone-else',
      ),
    );
    await pumpEventQueue();
    expect(builder.builds, 1);

    completions.add(
      const WakeRunCompletion(
        runKey: 'r2',
        status: WakeRunStatus.completed,
        agentId: 'goal-swim',
      ),
    );
    await pumpEventQueue();
    await container.read(frontChatThreadProvider.future);
    expect(builder.builds, 2);
  });

  test("re-projects on the front agent's own update ping", () async {
    final builder = _CountingBuilder(const {});
    final container = containerWith(builder)
      ..listen(frontChatThreadProvider, (_, _) {});
    await container.read(frontChatThreadProvider.future);

    pings.add({frontAgentId});
    await pumpEventQueue();
    await container.read(frontChatThreadProvider.future);

    expect(builder.builds, 2);
  });

  test(
    'keeps the shown thread while re-projecting (stay while reload)',
    () async {
      final builder = _CountingBuilder({'goal-swim'})..gate = Completer<void>();
      final container = containerWith(builder)
        ..listen(frontChatThreadProvider, (_, _) {});
      final first = await container.read(frontChatThreadProvider.future);

      completions.add(
        const WakeRunCompletion(
          runKey: 'r2',
          status: WakeRunStatus.completed,
          agentId: 'goal-swim',
        ),
      );
      await pumpEventQueue();

      final reloading = container.read(frontChatThreadProvider);
      expect(reloading.isLoading, isTrue);
      expect(reloading.value, same(first));
      builder.gate!.complete();
      await container.read(frontChatThreadProvider.future);
      expect(builder.builds, 2);
    },
  );

  test("re-projects on a specialist's own update ping — a reply that "
      'arrived through sync from another device', () async {
    final builder = _CountingBuilder({'goal-swim'});
    final container = containerWith(builder)
      ..listen(frontChatThreadProvider, (_, _) {});
    await container.read(frontChatThreadProvider.future);

    specialistPings.add({'goal-swim'});
    await pumpEventQueue();
    await container.read(frontChatThreadProvider.future);

    expect(builder.builds, 2);
  });

  test('a specialist that finishes while the thread is being read is not '
      'missed: the thread is re-projected once it is known', () async {
    final builder = _CountingBuilder({'goal-swim'})..gate = Completer<void>();
    final container = containerWith(builder)
      ..listen(frontChatThreadProvider, (_, _) {});
    await container.read(frontChatThreadProvider.future);
    expect(builder.builds, 1);

    // Trigger a reload, which blocks on the gate...
    pings.add({frontAgentId});
    await pumpEventQueue();
    expect(builder.builds, 2);
    // ...and let the specialist finish while that read is in flight.
    completions.add(
      const WakeRunCompletion(
        runKey: 'r2',
        status: WakeRunStatus.completed,
        agentId: 'goal-swim',
      ),
    );
    await pumpEventQueue();
    builder.gate!.complete();
    await pumpEventQueue();
    await container.read(frontChatThreadProvider.future);

    expect(builder.builds, 3);
  });

  test('stops listening when nobody looks at the thread', () async {
    final builder = _CountingBuilder({'goal-swim'});
    final container = containerWith(builder);
    final subscription = container.listen(frontChatThreadProvider, (_, _) {});
    await container.read(frontChatThreadProvider.future);
    expect(completions.hasListener, isTrue);

    subscription.close();
    await pumpEventQueue();

    expect(completions.hasListener, isFalse);
  });
}
