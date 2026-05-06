import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show Any, CombinableAny, ExploreConfig, Generator, Glados, IntAnys, any;
import 'package:lotti/features/ratings/ui/rating_utils.dart';

class _GeneratedRatingLookup {
  const _GeneratedRatingLookup({
    required this.labelCount,
    required this.storedValueCount,
    required this.selectedIndex,
  });

  final int labelCount;
  final int storedValueCount;
  final int selectedIndex;

  List<String> get labels => [
    for (var index = 0; index < labelCount; index++) 'Label $index',
  ];

  List<double> get storedValues => [
    for (var index = 0; index < storedValueCount; index++)
      _storedValueFor(index),
  ];

  double get matchingValue => selectedIndex < storedValueCount
      ? _storedValueFor(selectedIndex)
      : _fallbackValueFor(selectedIndex);

  String get expectedLabel => labels[selectedIndex];

  double _storedValueFor(int index) => (index + 1) / (labelCount + 2);

  double _fallbackValueFor(int index) {
    return labelCount == 1 ? 0.5 : index / (labelCount - 1);
  }

  @override
  String toString() {
    return '_GeneratedRatingLookup('
        'labelCount: $labelCount, '
        'storedValueCount: $storedValueCount, '
        'selectedIndex: $selectedIndex)';
  }
}

extension _AnyRatingLookup on Any {
  Generator<_GeneratedRatingLookup> get ratingLookup => combine3(
    intInRange(1, 9),
    intInRange(0, 9),
    intInRange(0, 9),
    (int labelCount, int storedValueCount, int selectedIndex) {
      final normalizedStoredCount = storedValueCount.clamp(0, labelCount);
      return _GeneratedRatingLookup(
        labelCount: labelCount,
        storedValueCount: normalizedStoredCount,
        selectedIndex: selectedIndex % labelCount,
      );
    },
  );
}

void main() {
  group('findOptionLabel', () {
    group('with stored optionValues (non-linear scales)', () {
      test('matches exact value at index 0', () {
        expect(
          findOptionLabel(
            0,
            ['Mild', 'Moderate', 'Severe'],
            values: [0, 0.2, 1.0],
          ),
          equals('Mild'),
        );
      });

      test('matches exact value at middle index', () {
        expect(
          findOptionLabel(
            0.2,
            ['Mild', 'Moderate', 'Severe'],
            values: [0, 0.2, 1.0],
          ),
          equals('Moderate'),
        );
      });

      test('matches exact value at last index', () {
        expect(
          findOptionLabel(
            1,
            ['Mild', 'Moderate', 'Severe'],
            values: [0, 0.2, 1.0],
          ),
          equals('Severe'),
        );
      });

      test('matches within tolerance of 0.01', () {
        expect(
          findOptionLabel(
            0.205,
            ['Mild', 'Moderate', 'Severe'],
            values: [0, 0.2, 1.0],
          ),
          equals('Moderate'),
        );
      });

      test('falls back to percentage when no value matches', () {
        expect(
          findOptionLabel(
            0.6,
            ['Mild', 'Moderate', 'Severe'],
            values: [0, 0.2, 1.0],
          ),
          equals('60%'),
        );
      });
    });

    group('without optionValues (evenly spaced fallback)', () {
      test('matches first option at 0.0 for 3 options', () {
        expect(
          findOptionLabel(0, ['Too easy', 'Just right', 'Too challenging']),
          equals('Too easy'),
        );
      });

      test('matches middle option at 0.5 for 3 options', () {
        expect(
          findOptionLabel(0.5, ['Too easy', 'Just right', 'Too challenging']),
          equals('Just right'),
        );
      });

      test('matches last option at 1.0 for 3 options', () {
        expect(
          findOptionLabel(1, ['Too easy', 'Just right', 'Too challenging']),
          equals('Too challenging'),
        );
      });

      test('matches first option at 0.0 for 2 options', () {
        expect(
          findOptionLabel(0, ['No', 'Yes']),
          equals('No'),
        );
      });

      test('matches second option at 1.0 for 2 options', () {
        expect(
          findOptionLabel(1, ['No', 'Yes']),
          equals('Yes'),
        );
      });

      test('uses 0.5 for single option', () {
        expect(
          findOptionLabel(0.5, ['Only choice']),
          equals('Only choice'),
        );
      });

      test('falls back to percentage for unmatched value', () {
        expect(
          findOptionLabel(0.37, ['Low', 'Medium', 'High']),
          equals('37%'),
        );
      });

      test('rounds percentage correctly', () {
        expect(
          findOptionLabel(0.333, ['A', 'B', 'C']),
          equals('33%'),
        );
      });
    });

    group('edge cases', () {
      test('handles value near boundary within tolerance', () {
        // 0.499 is within 0.01 of 0.5
        expect(
          findOptionLabel(0.499, ['A', 'B', 'C']),
          equals('B'),
        );
      });

      test('does not match value outside tolerance', () {
        // 0.48 is NOT within 0.01 of 0.5
        expect(
          findOptionLabel(0.48, ['A', 'B', 'C']),
          equals('48%'),
        );
      });

      test('handles optionValues shorter than labels gracefully', () {
        // Falls back to evenly-spaced for indices beyond values list
        expect(
          findOptionLabel(
            1,
            ['A', 'B', 'C'],
            values: [0, 0.5],
          ),
          equals('C'),
        );
      });
    });

    Glados(any.ratingLookup, ExploreConfig(numRuns: 160)).test(
      'matches generated stored-value and fallback option positions',
      (lookup) {
        expect(
          findOptionLabel(
            lookup.matchingValue,
            lookup.labels,
            values: lookup.storedValues,
          ),
          lookup.expectedLabel,
          reason: 'Lookup should match modeled position for $lookup',
        );
      },
    );

    Glados(any.ratingLookup, ExploreConfig(numRuns: 160)).test(
      'matches generated evenly spaced positions without stored values',
      (lookup) {
        final value = lookup.labelCount == 1
            ? 0.5
            : lookup.selectedIndex / (lookup.labelCount - 1);

        expect(
          findOptionLabel(value, lookup.labels),
          lookup.expectedLabel,
          reason: 'Fallback lookup should match modeled position for $lookup',
        );
      },
    );
  });
}
