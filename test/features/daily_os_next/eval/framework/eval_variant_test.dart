import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';

import 'eval_variant.dart';

/// The variant dimension only means anything if the control is guaranteed and
/// a variant's transform actually reaches the config the model is told about.
void main() {
  // ignore: avoid_redundant_argument_values
  const base = DayAgentConfig(capacityMinutes: 480);

  group('EvalVariant.apply', () {
    test('the baseline leaves the scenario contract untouched', () {
      final applied = evalBaselineVariant.apply(base);

      expect(applied.capacityMinutes, base.capacityMinutes);
      expect(applied.workingHoursStart, base.workingHoursStart);
      expect(applied.workingHoursEnd, base.workingHoursEnd);
    });

    test('a configured variant transforms the contract it is given', () {
      const variant = EvalVariant(
        id: 'shortDay',
        rationale: 'Does a tighter budget change what gets dropped?',
        configure: _shortDay,
      );

      final applied = variant.apply(base);

      expect(applied.capacityMinutes, 240);
      expect(applied.workingHoursEnd, '13:00');
    });

    test(
      'the transform reads the scenario contract rather than the default',
      () {
        const variant = EvalVariant(
          id: 'shortDay',
          rationale: 'x',
          configure: _shortDay,
        );

        expect(
          variant
              .apply(const DayAgentConfig(capacityMinutes: 600))
              .capacityMinutes,
          300,
          reason:
              'A variant is a delta on the scenario, not a fixed replacement — '
              'a scenario with an unusual capacity must still be halved from '
              'its own number.',
        );
      },
    );
  });

  group('evalVariants', () {
    test('always contains the control', () {
      expect(
        evalVariants.where((v) => v.id == evalBaselineVariantId),
        hasLength(1),
      );
    });

    test('ids are unique', () {
      expect(
        evalVariants.map((v) => v.id).toSet(),
        hasLength(evalVariants.length),
        reason: 'Duplicate ids would collapse two cells into one report row.',
      );
    });

    test('every variant states what it is trying to find out', () {
      for (final variant in evalVariants) {
        expect(variant.rationale.trim(), isNotEmpty, reason: variant.id);
      }
    });
  });
}

DayAgentConfig _shortDay(DayAgentConfig base) => DayAgentConfig(
  capacityMinutes: base.capacityMinutes ~/ 2,
  workingHoursStart: base.workingHoursStart,
  workingHoursEnd: '13:00',
  energyBands: base.energyBands,
  maxRefinementRounds: base.maxRefinementRounds,
);
