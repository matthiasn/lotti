import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';

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
        ],
      );
    });

    test('has four values', () {
      expect(SyncSequencePayloadType.values, hasLength(4));
    });
  });
}
