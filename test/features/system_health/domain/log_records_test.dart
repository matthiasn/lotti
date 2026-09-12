import 'package:flutter_test/flutter_test.dart';

import '../system_health_test_fixtures.dart';

void main() {
  final at = DateTime(2026, 9, 12);

  test('isError and isWarning follow the written level exactly', () {
    expect(logRecord(timestamp: at).isError, isTrue);
    expect(logRecord(timestamp: at).isWarning, isFalse);
    expect(logRecord(timestamp: at, level: 'WARN').isWarning, isTrue);
    expect(logRecord(timestamp: at, level: 'WARN').isError, isFalse);
    expect(logRecord(timestamp: at, level: 'INFO').isError, isFalse);
    expect(logRecord(timestamp: at, level: 'INFO').isWarning, isFalse);
  });

  test('a slow query record keeps its plan and frames', () {
    final record = slowQuery(
      timestamp: at,
      isSuperSlow: true,
      planRows: const ['4|0|SCAN journal'],
      stackFrames: const ['#1 JournalDb.get (package:lotti/x.dart:1:1)'],
    );
    expect(record.isSuperSlow, isTrue);
    expect(record.planRows, ['4|0|SCAN journal']);
    expect(record.stackFrames, hasLength(1));
    expect(record.operation, 'select');
  });
}
