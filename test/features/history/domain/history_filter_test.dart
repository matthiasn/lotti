// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/history/domain/history_filter.dart';

void main() {
  group('matchesTitle', () {
    test('an empty or blank query matches everything', () {
      expect(const HistoryFilter().matchesTitle(''), isTrue);
      expect(const HistoryFilter(query: '   ').matchesTitle('x'), isTrue);
      expect(const HistoryFilter(query: '  ').hasQuery, isFalse);
    });

    test('every term must occur, in any order, ignoring case', () {
      const filter = HistoryFilter(query: 'FIX  bug');
      expect(filter.terms, ['fix', 'bug']);
      expect(filter.matchesTitle('Bug fix for login'), isTrue);
      expect(filter.matchesTitle('Fix the build'), isFalse);
    });

    test('folds non-ASCII letters too', () {
      expect(
        const HistoryFilter(query: 'über').matchesTitle('ÜBERSICHT'),
        isTrue,
      );
    });
  });

  group('bounds', () {
    final now = DateTime(2026, 3, 15, 18, 30);

    test('the last-N-days windows count today and start at midnight', () {
      expect(
        const HistoryFilter(range: HistoryTimeRange.last7Days).bounds(now),
        (from: DateTime(2026, 3, 9), to: null),
      );
      expect(
        const HistoryFilter(range: HistoryTimeRange.last30Days).bounds(now),
        (from: DateTime(2026, 2, 14), to: null),
      );
      expect(
        const HistoryFilter(range: HistoryTimeRange.last90Days).bounds(now),
        (from: DateTime(2025, 12, 16), to: null),
      );
    });

    test('all time is open at both ends', () {
      expect(const HistoryFilter().bounds(now), (from: null, to: null));
    });

    test('a custom range includes both of its days', () {
      final filter = HistoryFilter(
        range: HistoryTimeRange.custom,
        customStart: DateTime(2026, 3, 1, 14),
        customEnd: DateTime(2026, 3, 3, 9),
      );
      expect(
        filter.bounds(now),
        (from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 4)),
      );
    });

    test('custom dates are ignored by the preset ranges', () {
      final filter = HistoryFilter(
        range: HistoryTimeRange.allTime,
        customStart: DateTime(2026, 3),
        customEnd: DateTime(2026, 3, 3),
      );
      expect(filter.bounds(now), (from: null, to: null));
    });
  });

  test('equal filters hash alike; any field tells two apart', () {
    // Two separately built but equal filters must collapse into one.
    final filters = {
      HistoryFilter(customStart: DateTime(2026), customEnd: DateTime(2027)),
      HistoryFilter(customStart: DateTime(2026), customEnd: DateTime(2027)),
      const HistoryFilter(query: 'a'),
      const HistoryFilter(range: HistoryTimeRange.last7Days),
      HistoryFilter(customStart: DateTime(2026)),
      HistoryFilter(customEnd: DateTime(2026)),
    };
    expect(filters, hasLength(5));
    expect(
      const HistoryFilter().copyWith(range: HistoryTimeRange.last90Days).range,
      HistoryTimeRange.last90Days,
    );
  });

  test('copyWith keeps what it is not given', () {
    final filter = HistoryFilter(
      query: 'a',
      range: HistoryTimeRange.custom,
      customStart: DateTime(2026),
      customEnd: DateTime(2026, 2),
    );
    expect(
      filter.copyWith(query: 'b'),
      HistoryFilter(
        query: 'b',
        range: HistoryTimeRange.custom,
        customStart: DateTime(2026),
        customEnd: DateTime(2026, 2),
      ),
    );
  });

  glados.Glados2<String, String>(
    glados.any.letterOrDigits,
    glados.any.letterOrDigits,
  ).test(
    'a title always matches a query made of its own words',
    (left, right) {
      final title = '$left $right';
      expect(HistoryFilter(query: '$right $left').matchesTitle(title), isTrue);
      expect(
        HistoryFilter(query: title.toUpperCase()).matchesTitle(title),
        isTrue,
      );
    },
    tags: 'glados',
  );
}
