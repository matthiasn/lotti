import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/service/front_agent_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentService agentService;
  late MockAgentSyncService syncService;
  late FrontAgentService service;

  final existing = makeTestIdentity(
    id: frontAgentId,
    agentId: frontAgentId,
    kind: AgentKinds.frontAgent,
  );

  setUp(() {
    agentService = MockAgentService();
    syncService = MockAgentSyncService();
    service = FrontAgentService(
      agentService: agentService,
      syncService: syncService,
    );
  });

  test('returns the existing front agent without creating one', () async {
    when(
      () => agentService.getAgent(frontAgentId),
    ).thenAnswer((_) async => existing);

    final identity = await service.getOrCreate();

    expect(identity, same(existing));
    verifyNever(
      () => agentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        agentId: any(named: 'agentId'),
      ),
    );
  });

  test('creates the one front agent under its fixed id and allow-list, '
      'inside a transaction', () async {
    when(
      () => agentService.getAgent(frontAgentId),
    ).thenAnswer((_) async => null);
    when(
      () => agentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        agentId: any(named: 'agentId'),
      ),
    ).thenAnswer((_) async => existing);
    var inTransaction = false;
    var createdInside = false;
    syncService.transactionDelegate = <T>(action) async {
      inTransaction = true;
      try {
        return await action();
      } finally {
        inTransaction = false;
      }
    };
    when(
      () => agentService.createAgent(
        kind: AgentKinds.frontAgent,
        displayName: any(named: 'displayName'),
        config: const AgentConfig(),
        allowedCategoryIds: {'work'},
        agentId: frontAgentId,
      ),
    ).thenAnswer((_) async {
      createdInside = inTransaction;
      return existing;
    });

    final identity = await service.getOrCreate(allowedCategoryIds: {'work'});

    expect(identity, same(existing));
    expect(createdInside, isTrue);
  });

  test('a peer that created the agent between the read and the transaction '
      'wins; nothing is created twice', () async {
    var reads = 0;
    when(() => agentService.getAgent(frontAgentId)).thenAnswer((_) async {
      reads++;
      return reads == 1 ? null : existing;
    });

    final identity = await service.getOrCreate();

    expect(identity, same(existing));
    expect(reads, 2);
    verifyNever(
      () => agentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        agentId: any(named: 'agentId'),
      ),
    );
  });
}
