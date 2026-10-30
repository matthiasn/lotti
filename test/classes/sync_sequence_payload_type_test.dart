import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';

void main() {
  group('SyncSequencePayloadType', () {
    test('has expected values', () {
      expect(
        SyncSequencePayloadType.values,
        [
          SyncSequencePayloadType.journalEntity,
          SyncSequencePayloadType.entryLink,
          SyncSequencePayloadType.agentEntity,
          SyncSequencePayloadType.agentLink,
          SyncSequencePayloadType.notification,
          SyncSequencePayloadType.notificationStateUpdate,
          SyncSequencePayloadType.consumptionEvent,
          SyncSequencePayloadType.entityDefinition,
          SyncSequencePayloadType.aiConfig,
          SyncSequencePayloadType.embeddingVectors,
        ],
      );
    });

    test('keeps the ordinals the sequence log persists', () {
      // Stored by index: a value may only be appended, never moved.
      expect(SyncSequencePayloadType.entityDefinition.index, 7);
      expect(SyncSequencePayloadType.aiConfig.index, 8);
      expect(SyncSequencePayloadType.embeddingVectors.index, 9);
    });
  });
}
