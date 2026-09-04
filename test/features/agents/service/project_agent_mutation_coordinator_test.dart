import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/service/project_agent_mutation_coordinator.dart';

void main() {
  test('serializes one project while allowing another to progress', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final coordinator = container.read(projectAgentMutationCoordinatorProvider);
    final entered = Completer<void>();
    final release = Completer<void>();
    final events = <String>[];
    final first = coordinator.run('project-a', () async {
      events.add('first');
      entered.complete();
      await release.future;
      events.add('released');
    });
    await entered.future;
    final second = coordinator.run(
      'project-a',
      () async => events.add('second'),
    );
    await coordinator.run('project-b', () async => events.add('independent'));
    expect(events, ['first', 'independent']);
    release.complete();
    await Future.wait([first, second]);
    expect(events, ['first', 'independent', 'released', 'second']);
  });

  test('nested operations reuse the held project scope', () async {
    final coordinator = ProjectAgentMutationCoordinator();
    final result = await coordinator.run('project', () async {
      return coordinator.run('project', () async => 'nested result');
    });
    expect(result, 'nested result');
  });

  test('a failing operation releases the next queued mutation', () async {
    final coordinator = ProjectAgentMutationCoordinator();
    final entered = Completer<void>();
    final release = Completer<void>();
    final first = coordinator.run<void>('project', () async {
      entered.complete();
      await release.future;
      throw StateError('mutation failed');
    });
    final failure = expectLater(first, throwsStateError);
    await entered.future;
    final second = coordinator.run('project', () async => 'recovered');
    release.complete();
    await failure;
    expect(await second, 'recovered');
  });
}
