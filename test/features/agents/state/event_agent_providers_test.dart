import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('eventAgentServiceProvider', () {
    test('creates EventAgentService with the wired dependencies', () {
      final mockAgentService = MockAgentService();
      final mockRepository = MockAgentRepository();
      final wakeQueue = WakeQueue();
      final wakeRunner = WakeRunner();
      final orchestrator = WakeOrchestrator(
        repository: mockRepository,
        queue: wakeQueue,
        runner: wakeRunner,
      );
      final mockSyncService = MockAgentSyncService();
      final notifications = UpdateNotifications();
      addTearDown(notifications.dispose);

      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          wakeOrchestratorProvider.overrideWithValue(orchestrator),
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          updateNotificationsProvider.overrideWithValue(notifications),
          domainLoggerProvider.overrideWithValue(
            DomainLogger(loggingService: LoggingService()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(eventAgentServiceProvider);

      expect(service, isNotNull);
      expect(service.agentService, same(mockAgentService));
      expect(service.repository, same(mockRepository));
      expect(service.orchestrator, same(orchestrator));
      expect(service.syncService, same(mockSyncService));
    });
  });

  group('eventAgentProvider', () {
    test('returns the identity when an agent exists for the event', () async {
      final mockService = MockEventAgentService();
      const eventId = 'event-123';
      final identity = makeTestIdentity(id: 'agent-for-event');

      when(
        () => mockService.getEventAgentForEvent(eventId),
      ).thenAnswer((_) async => identity);

      final container = ProviderContainer(
        overrides: [
          eventAgentServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(eventAgentProvider(eventId).future);

      expect(result, equals(identity));
      verify(() => mockService.getEventAgentForEvent(eventId)).called(1);
    });

    test('returns null when no agent exists for the event', () async {
      final mockService = MockEventAgentService();
      const eventId = 'event-no-agent';

      when(
        () => mockService.getEventAgentForEvent(eventId),
      ).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          eventAgentServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(eventAgentProvider(eventId).future);

      expect(result, isNull);
    });

    test('propagates an error from the service', () async {
      final mockService = MockEventAgentService();
      const eventId = 'event-error';

      when(
        () => mockService.getEventAgentForEvent(eventId),
      ).thenAnswer((_) async => throw Exception('DB error'));

      final container = ProviderContainer(
        overrides: [
          eventAgentServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final completer = Completer<AsyncValue<AgentDomainEntity?>>();
      final sub = container.listen(
        eventAgentProvider(eventId),
        (_, next) {
          if (!completer.isCompleted && (next.hasValue || next.hasError)) {
            completer.complete(next);
          }
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final result = await completer.future;
      expect(result.hasError, isTrue);
      expect(result.error, isA<Exception>());
    });

    test('rebuilds when an update notification arrives for the eventId', () {
      fakeAsync((async) {
        final mockService = MockEventAgentService();
        const eventId = 'event-sync-refresh';
        final identity = makeTestIdentity(id: 'agent-sync');
        final notifications = UpdateNotifications();

        // null first (no agent yet), identity after the link syncs in.
        var callCount = 0;
        when(() => mockService.getEventAgentForEvent(eventId)).thenAnswer((
          _,
        ) async {
          callCount++;
          return callCount > 1 ? identity : null;
        });

        final container = ProviderContainer(
          overrides: [
            eventAgentServiceProvider.overrideWithValue(mockService),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );

        final sub = container.listen(
          eventAgentProvider(eventId),
          (_, _) {},
          fireImmediately: true,
        );

        async.flushMicrotasks();
        expect(container.read(eventAgentProvider(eventId)).value, isNull);

        // A sync notification carrying the eventId (as when an AgentEventLink
        // arrives from another device) must re-resolve the agent.
        notifications.notify({eventId, 'agentNotification'});
        async.elapse(const Duration(milliseconds: 150));

        verify(
          () => mockService.getEventAgentForEvent(eventId),
        ).called(greaterThanOrEqualTo(2));

        sub.close();
        container.dispose();
        notifications.dispose();
      });
    });
  });
}
