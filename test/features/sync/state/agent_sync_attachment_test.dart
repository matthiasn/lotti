import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/sync/state/agent_sync_attachment.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';

void main() {
  group('buildSyncLeaseGate', () {
    test('opens with sync off, and with sync on only while logged in with '
        'the inbox drained', () async {
      final matrixService = MockMatrixService();
      final coordinator = MockQueuePipelineCoordinator();
      final queue = MockInboundQueue();
      when(() => matrixService.queueCoordinator).thenReturn(coordinator);
      when(() => coordinator.queue).thenReturn(queue);
      when(
        () => queue.waitForDrainAtMostTo(0, timeout: any(named: 'timeout')),
      ).thenAnswer((_) async {});
      var loggedIn = false;
      when(matrixService.isLoggedIn).thenAnswer((_) => loggedIn);
      final journalDb = MockJournalDb();
      var syncEnabled = false;
      when(
        () => journalDb.getConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) async => syncEnabled);
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          journalDbProvider.overrideWithValue(journalDb),
          matrixServiceProvider.overrideWithValue(matrixService),
          syncLeaseGateProvider.overrideWith(buildSyncLeaseGate),
        ]),
      );
      addTearDown(container.dispose);

      final gate = container.read(syncLeaseGateProvider)!;

      expect(await gate.ready(), isTrue);
      syncEnabled = true;
      expect(await gate.ready(), isFalse);
      loggedIn = true;
      expect(await gate.ready(), isTrue);
      verify(
        () => queue.waitForDrainAtMostTo(0, timeout: gate.drainTimeout),
      ).called(1);
    });
  });
}
