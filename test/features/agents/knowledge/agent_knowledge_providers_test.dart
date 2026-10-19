import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/day_agent_identity.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';

PlannerKnowledgeEntity _entry({
  required String id,
  required String key,
  KnowledgeStatus status = KnowledgeStatus.confirmed,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  final at = updatedAt ?? DateTime(2026, 5, 25, 8);
  return AgentDomainEntity.plannerKnowledge(
        id: id,
        agentId: 'daily_os_planner',
        key: key,
        hook: 'hook',
        statementText: 'statement',
        source: KnowledgeSource.userStated,
        status: status,
        createdAt: at,
        updatedAt: at,
        vectorClock: null,
        deletedAt: deletedAt,
      )
      as PlannerKnowledgeEntity;
}

void main() {
  late MockUpdateNotifications notifications;
  late MockAgentKnowledgeService knowledgeService;

  setUp(() {
    notifications = MockUpdateNotifications();
    knowledgeService = MockAgentKnowledgeService();
    when(
      () => notifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
  });

  Future<AgentKnowledgeView> read(List<PlannerKnowledgeEntity> all) async {
    when(
      () => knowledgeService.allFor('daily_os_planner'),
    ).thenAnswer((_) async => all);
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        updateNotificationsProvider.overrideWithValue(notifications),
        agentKnowledgeServiceProvider.overrideWithValue(knowledgeService),
      ]),
    );
    addTearDown(container.dispose);
    return container.read(agentKnowledgeProvider(dailyOsPlannerAgentId).future);
  }

  test('the shared service writes through the app stores and announces '
      'each change for the agent it belongs to', () {
    final repository = MockAgentRepository();
    final syncService = MockAgentSyncService();
    final domainLogger = MockDomainLogger();
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        agentRepositoryProvider.overrideWithValue(repository),
        agentSyncServiceProvider.overrideWithValue(syncService),
        domainLoggerProvider.overrideWithValue(domainLogger),
        updateNotificationsProvider.overrideWithValue(notifications),
      ]),
    );
    addTearDown(container.dispose);

    final service = container.read(agentKnowledgeServiceProvider);

    expect(service.agentRepository, same(repository));
    expect(service.syncService, same(syncService));
    expect(service.domainLogger, same(domainLogger));
    // A change to a goal agent's knowledge refreshes that agent's panel —
    // the id the panel's provider listens on, any agent at all.
    service.onPersistedStateChanged!('goal-agent-7');
    verify(
      () => notifications.notifyUiOnly({'goal-agent-7', agentNotification}),
    ).called(1);
  });

  test('splits the active Head set from pending proposals', () async {
    final view = await read([
      _entry(id: 'c1', key: 'deep-work'),
      _entry(id: 'p1', key: 'gym', status: KnowledgeStatus.proposed),
      _entry(id: 'r1', key: 'old', status: KnowledgeStatus.retracted),
      _entry(
        id: 'd1',
        key: 'gone',
        deletedAt: DateTime(2026, 5, 26),
      ),
    ]);

    // Confirmed Head excludes proposed/retracted/deleted.
    expect(view.confirmed.map((e) => e.id), ['c1']);
    // Proposals surface separately; retracted/deleted never do.
    expect(view.proposed.map((e) => e.id), ['p1']);
    expect(view.isEmpty, isFalse);
  });

  test(
    'orders proposals newest-first and excludes deleted proposals',
    () async {
      final view = await read([
        _entry(
          id: 'old',
          key: 'a',
          status: KnowledgeStatus.proposed,
          updatedAt: DateTime(2026, 5, 20),
        ),
        _entry(
          id: 'new',
          key: 'b',
          status: KnowledgeStatus.proposed,
          updatedAt: DateTime(2026, 5, 24),
        ),
        _entry(
          id: 'deleted',
          key: 'c',
          status: KnowledgeStatus.proposed,
          deletedAt: DateTime(2026, 5, 25),
        ),
      ]);

      expect(view.proposed.map((e) => e.id), ['new', 'old']);
    },
  );

  test('reports empty when there is no knowledge', () async {
    final view = await read([]);
    expect(view.isEmpty, isTrue);
    expect(view.confirmed, isEmpty);
    expect(view.proposed, isEmpty);
  });
}
