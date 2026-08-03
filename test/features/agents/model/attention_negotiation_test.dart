import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';

void main() {
  group('AttentionEvidenceRef', () {
    test('roundtrips known evidence kind to JSON', () {
      const ref = AttentionEvidenceRef(
        kind: AttentionEvidenceKind.report,
        id: 'report-001',
        label: 'Current report',
      );

      final json = ref.toJson();
      final roundtripped = AttentionEvidenceRef.fromJson(json);

      expect(roundtripped, equals(ref));
      expect(json, {
        'kind': 'report',
        'id': 'report-001',
        'label': 'Current report',
      });
    });

    test('falls back to custom for unknown evidence kinds', () {
      final ref = AttentionEvidenceRef.fromJson(const {
        'kind': 'futureSensorKind',
        'id': 'future-001',
        'label': 'Future sensor',
      });

      expect(ref.kind, AttentionEvidenceKind.custom);
      expect(ref.id, 'future-001');
      expect(ref.label, 'Future sensor');
    });

    test('uses value equality and stable hashCode', () {
      const a = AttentionEvidenceRef(
        kind: AttentionEvidenceKind.task,
        id: 'task-001',
        label: 'Task',
      );
      const b = AttentionEvidenceRef(
        kind: AttentionEvidenceKind.task,
        id: 'task-001',
        label: 'Task',
      );
      const different = AttentionEvidenceRef(
        kind: AttentionEvidenceKind.task,
        id: 'task-002',
        label: 'Task',
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == different, isFalse);
    });
  });
}
