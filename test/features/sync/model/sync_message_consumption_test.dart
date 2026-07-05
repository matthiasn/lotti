import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../../ai_consumption/test_utils.dart';

void main() {
  test('SyncMessage.consumptionEvent round-trips through JSON', () {
    final message = SyncMessage.consumptionEvent(
      event: makeConsumptionEvent(
        id: 'evt-42',
        vectorClock: const VectorClock({'host-a': 7}),
        taskId: 'task-9',
        categoryId: 'cat-9',
      ),
      status: SyncEntryStatus.update,
      originatingHostId: 'host-a',
      coveredVectorClocks: const [
        VectorClock({'host-a': 7}),
      ],
    );

    // Round-trip through a real JSON string, exactly as the outbox/Matrix
    // pipeline does (nested objects are serialized by jsonEncode, not by the
    // union's own toJson — matching every other SyncMessage variant).
    final decoded = SyncMessage.fromJson(
      jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>,
    );

    expect(decoded, isA<SyncConsumptionEvent>());
    final typed = decoded as SyncConsumptionEvent;
    expect(typed.event.id, 'evt-42');
    expect(typed.event.taskId, 'task-9');
    expect(typed.event.categoryId, 'cat-9');
    expect(typed.event.vectorClock, const VectorClock({'host-a': 7}));
    expect(typed.status, SyncEntryStatus.update);
    expect(typed.originatingHostId, 'host-a');
    expect(typed.coveredVectorClocks, const [
      VectorClock({'host-a': 7}),
    ]);
    // Whole-message structural equality survives the round trip.
    expect(decoded, message);
  });
}
