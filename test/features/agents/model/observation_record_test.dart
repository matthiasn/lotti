import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';

void main() {
  group('ObservationRecord', () {
    group('default values', () {
      test('priority defaults to routine', () {
        const record = ObservationRecord(text: 'some observation');
        expect(record.priority, equals(ObservationPriority.routine));
      });

      test('category defaults to operational', () {
        const record = ObservationRecord(text: 'some observation');
        expect(record.category, equals(ObservationCategory.operational));
      });

      test('text is preserved verbatim', () {
        const text = 'Agent encountered a timeout on the third retry.';
        const record = ObservationRecord(text: text);
        expect(record.text, equals(text));
      });
    });

    group('explicit values', () {
      test('accepts custom priority', () {
        const record = ObservationRecord(
          text: 'Critical failure',
          priority: ObservationPriority.critical,
        );
        expect(record.priority, equals(ObservationPriority.critical));
      });

      test('accepts notable priority', () {
        const record = ObservationRecord(
          text: 'Worth reviewing',
          priority: ObservationPriority.notable,
        );
        expect(record.priority, equals(ObservationPriority.notable));
      });

      test('accepts non-operational category', () {
        const record = ObservationRecord(
          text: 'Template suggestion',
          category: ObservationCategory.templateImprovement,
        );
        expect(
          record.category,
          equals(ObservationCategory.templateImprovement),
        );
      });

      test('accepts grievance category', () {
        const record = ObservationRecord(
          text: 'User unhappy with response',
          category: ObservationCategory.grievance,
        );
        expect(record.category, equals(ObservationCategory.grievance));
      });

      test('all fields set explicitly', () {
        const record = ObservationRecord(
          text: 'Excellence note',
          priority: ObservationPriority.critical,
          category: ObservationCategory.excellence,
        );
        expect(record.text, equals('Excellence note'));
        expect(record.priority, equals(ObservationPriority.critical));
        expect(record.category, equals(ObservationCategory.excellence));
      });
    });
  });
}
