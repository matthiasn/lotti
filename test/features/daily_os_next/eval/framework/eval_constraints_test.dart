import 'package:flutter_test/flutter_test.dart';

import 'eval_constraints.dart';
import 'eval_constraints_test_helpers.dart';

void main() {
  group('scoreAll', () {
    test('returns every constraint in report order', () {
      final results = scoreAll(outcome());

      expect(
        results.map((result) => result.id),
        EvalConstraintIds.all,
        reason:
            'a constraint dropped from scoreAll would silently stop being '
            'measured while the report still looked complete',
      );
    });

    test('marks inapplicable constraints rather than passing them', () {
      // An empty plan must not read as a clean sweep — that would make the
      // laziest possible model look like the best one.
      final results = scoreAll(outcome());

      expect(
        results.where((result) => result.isApplicable),
        isEmpty,
        reason:
            'an empty run demonstrates nothing at all — including about '
            'compliance, which it never attempted',
      );
    });
  });
}
