import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ratings/ui/rating_utils.dart';

void main() {
  group('findOptionLabel', () {
    group('with stored optionValues (non-linear scales)', () {
      test('matches exact value at index 0', () {
        expect(
          findOptionLabel(
            0,
            ['Mild', 'Moderate', 'Severe'],
            values: [0.0, 0.2, 1.0],
          ),
          equals('Mild'),
        );
      });

      test('matches exact value at middle index', () {
        expect(
          findOptionLabel(
            0.2,
            ['Mild', 'Moderate', 'Severe'],
            values: [0.0, 0.2, 1.0],
          ),
          equals('Moderate'),
        );
      });

      test('matches exact value at last index', () {
        expect(
          findOptionLabel(
            1,
            ['Mild', 'Moderate', 'Severe'],
            values: [0.0, 0.2, 1.0],
          ),
          equals('Severe'),
        );
      });

      test('matches within tolerance of 0.01', () {
        expect(
          findOptionLabel(
            0.205,
            ['Mild', 'Moderate', 'Severe'],
            values: [0.0, 0.2, 1.0],
          ),
          equals('Moderate'),
        );
      });

      test('falls back to percentage when no value matches', () {
        expect(
          findOptionLabel(
            0.6,
            ['Mild', 'Moderate', 'Severe'],
            values: [0.0, 0.2, 1.0],
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
            values: [0.0, 0.5],
          ),
          equals('C'),
        );
      });
    });
  });
}
