import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void hStubRecordReceived(MockSyncSequenceLogService log) {
  when(
    () => log.recordReceivedEntry(
      entryId: any(named: 'entryId'),
      vectorClock: any(named: 'vectorClock'),
      originatingHostId: any(named: 'originatingHostId'),
      coveredVectorClocks: any(named: 'coveredVectorClocks'),
      payloadType: any(named: 'payloadType'),
      jsonPath: any(named: 'jsonPath'),
    ),
  ).thenAnswer((_) async => const <({int counter, String hostId})>[]);
  when(
    () => log.recordReceivedEntry(
      entryId: any(named: 'entryId'),
      vectorClock: any(named: 'vectorClock'),
      originatingHostId: any(named: 'originatingHostId'),
      payloadType: any(named: 'payloadType'),
    ),
  ).thenAnswer((_) async => const <({int counter, String hostId})>[]);
}

NotificationEntity hNotification({
  required String id,
  required String linkedTaskId,
}) {
  final timestamp = DateTime.utc(2026, 5, 17, 10);
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      scheduledFor: timestamp,
      vectorClock: const VectorClock({'local-host': 1}),
      originatingHostId: 'local-host',
    ),
    linkedTaskId: linkedTaskId,
    suggestionCount: 2,
    title: 'Review suggestions',
    body: 'Two tasks need review',
  );
}
