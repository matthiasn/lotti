import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'analyze_test_timings.dart';

void main() {
  Map<String, Object> start(int id, String name, int time) => {
    'type': 'testStart',
    'time': time,
    'test': {'id': id, 'name': name},
  };
  Map<String, Object> done(
    int id,
    int time, {
    String result = 'success',
    bool skipped = false,
    bool hidden = false,
  }) => {
    'type': 'testDone',
    'testID': id,
    'time': time,
    'result': result,
    'skipped': skipped,
    'hidden': hidden,
  };

  test(
    'concurrent completions use individual start times, including first test',
    () {
      final report = summarizeTestEvents(
        [
          start(1, 'slow', 0),
          start(2, 'fast', 1900),
          done(2, 2000),
          done(1, 2100),
          {'type': 'done'},
        ].map(jsonEncode),
      );
      expect(
        report,
        contains('Passed: 2; failed: 0; skipped: 0; incomplete: 0.'),
      );
      expect(report, contains('2100ms: slow'));
      expect(report, isNot(contains('ms: fast')));
      expect(report, contains('completion event: present'));
    },
  );

  test(
    'reports skips, loader failures and unfinished tests in truncated output',
    () {
      final report = summarizeTestEvents([
        ...[
          start(1, 'loading broken.dart', 0),
          done(1, 50, result: 'error', hidden: true),
          start(2, 'manual', 60),
          done(2, 60, skipped: true),
          start(3, 'hung', 70),
          start(4, 'loading valid.dart', 80),
          done(4, 100, hidden: true),
        ].map(jsonEncode),
        '{partial',
      ]);
      expect(
        report,
        contains('Passed: 0; failed: 1; skipped: 1; incomplete: 1.'),
      );
      expect(report, contains('FAIL: loading broken.dart'));
      expect(report, contains('SKIP: manual'));
      expect(report, contains('INCOMPLETE: hung'));
      expect(report, contains('Malformed/truncated records: 1.'));
      expect(report, contains('completion event: missing'));
      expect(report, isNot(contains('valid.dart')));
    },
  );

  test('slow tests sort by descending duration and honor the threshold', () {
    final report = summarizeTestEvents(
      [
        start(1, 'shorter', 100),
        start(2, 'longer', 110),
        done(1, 200),
        done(2, 310),
      ].map(jsonEncode),
      thresholdMs: 100,
    );
    expect(report, endsWith('200ms: longer\n100ms: shorter\n'));
  });
}
