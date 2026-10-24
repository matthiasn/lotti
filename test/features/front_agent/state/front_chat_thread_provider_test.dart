import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/service/front_chat_thread_builder.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _CountingBuilder extends FrontChatThreadBuilder {
  _CountingBuilder(this.specialists) : super(repository: MockAgentRepository());

  final Set<String> specialists;
  int builds = 0;

  @override
  Future<FrontChatThread> build() async {
    builds++;
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

  setUp(() {
    completions = StreamController<WakeRunCompletion>.broadcast();
    pings = StreamController<Set<String>>.broadcast();
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
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

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
    await Future<void>.delayed(Duration.zero);
    expect(builder.builds, 1);

    completions.add(
      const WakeRunCompletion(
        runKey: 'r2',
        status: WakeRunStatus.completed,
        agentId: 'goal-swim',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await container.read(frontChatThreadProvider.future);
    expect(builder.builds, 2);
  });

  test("re-projects on the front agent's own update ping", () async {
    final builder = _CountingBuilder(const {});
    final container = containerWith(builder)
      ..listen(frontChatThreadProvider, (_, _) {});
    await container.read(frontChatThreadProvider.future);

    pings.add({frontAgentId});
    await Future<void>.delayed(Duration.zero);
    await container.read(frontChatThreadProvider.future);

    expect(builder.builds, 2);
  });

  test(
    'keeps the shown thread while re-projecting (stay while reload)',
    () async {
      final builder = _CountingBuilder({'goal-swim'});
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
      await Future<void>.delayed(Duration.zero);

      final reloading = container.read(frontChatThreadProvider);
      expect(reloading.isLoading, isTrue);
      expect(reloading.value, same(first));
    },
  );

  test('stops listening when nobody looks at the thread', () async {
    final builder = _CountingBuilder({'goal-swim'});
    final container = containerWith(builder);
    final subscription = container.listen(frontChatThreadProvider, (_, _) {});
    await container.read(frontChatThreadProvider.future);
    expect(completions.hasListener, isTrue);

    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(completions.hasListener, isFalse);
  });
}
