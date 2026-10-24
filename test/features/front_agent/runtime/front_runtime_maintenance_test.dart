import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/runtime/front_runtime_maintenance.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

class _MockFrontChatService extends Mock implements FrontChatService {}

void main() {
  setUpAll(registerAllFallbackValues);

  late _MockFrontChatService chatService;
  late MockDomainLogger logger;
  late FrontRuntimeMaintenance maintenance;

  setUp(() {
    chatService = _MockFrontChatService();
    logger = MockDomainLogger();
    maintenance = FrontRuntimeMaintenance(
      chatService: chatService,
      domainLogger: logger,
    );
    when(
      () => chatService.restoreOldestPendingMessage(),
    ).thenAnswer((_) async => true);
  });

  test('every hook restores the oldest pending turn', () async {
    await maintenance.beforeWakeScan();
    await maintenance.restoreSubscriptions();
    await maintenance.onIdentityReceived(
      makeTestIdentity(
        id: frontAgentId,
        agentId: frontAgentId,
        kind: AgentKinds.frontAgent,
      ),
    );
    verify(() => chatService.restoreOldestPendingMessage()).called(3);
  });

  test("another kind's identity is not the front agent's business", () async {
    await maintenance.onIdentityReceived(
      makeTestIdentity(kind: AgentKinds.goalAgent),
    );
    verifyNever(() => chatService.restoreOldestPendingMessage());
  });

  test(
    'a failing restore is logged and contained, so the scan goes on',
    () async {
      when(
        () => chatService.restoreOldestPendingMessage(),
      ).thenThrow(StateError('database closed'));

      await expectLater(maintenance.beforeWakeScan(), completes);

      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'FrontRuntimeMaintenance',
          message:
              'beforeWakeScan: restoring the oldest pending front turn failed',
        ),
      ).called(1);
    },
  );
}
