import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// Stubs [MockSyncDatabase.getDailyOutboxVolume] with the given [volumes].
void hStubDailyVolumes(
  MockSyncDatabase mock, {
  required List<OutboxDailyVolume> volumes,
}) {
  when(
    () => mock.getDailyOutboxVolume(days: kOutboxVolumeDays),
  ).thenAnswer((_) async => volumes);
}

class MockQueueCoordinator extends Mock implements QueuePipelineCoordinator {}
