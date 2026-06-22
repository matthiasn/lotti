// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';

void main() {
  late OnboardingMetricsDb db;
  var seq = 0;

  setUp(() {
    seq = 0;
    db = OnboardingMetricsDb(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insert(
    String name,
    DateTime ts,
    int day, {
    String? provider,
    String? reason,
    int? bucket,
  }) {
    return db.insertOnboardingEvent(
      id: 'id-${seq++}',
      eventName: name,
      createdAt: ts,
      dayBucket: day,
      provider: provider,
      reason: reason,
      valueBucket: bucket,
    );
  }

  test('getAllEvents returns rows in chronological order', () async {
    await insert('later', DateTime.utc(2026, 1, 2), 2);
    await insert('earlier', DateTime.utc(2026, 1, 1), 1);
    final rows = await db.getAllEvents();
    expect(rows.map((r) => r.eventName).toList(), ['earlier', 'later']);
  });

  test('eventCounts aggregates occurrences per name', () async {
    await insert('x', DateTime.utc(2026, 1, 1), 1);
    await insert('x', DateTime.utc(2026, 1, 1), 1);
    await insert('y', DateTime.utc(2026, 1, 1), 1);
    expect(await db.eventCounts(), {'x': 2, 'y': 1});
  });

  test('firstSeen returns earliest timestamp, null when absent', () async {
    expect(await db.firstSeen('x'), isNull);
    await insert('x', DateTime.utc(2026, 1, 5), 5);
    await insert('x', DateTime.utc(2026, 1, 3), 3);
    final first = await db.firstSeen('x');
    expect(first, isNotNull);
    expect(first!.isAtSameMomentAs(DateTime.utc(2026, 1, 3)), isTrue);
  });

  test('activeDayBuckets returns sorted, de-duplicated days', () async {
    await insert('a', DateTime.utc(2026, 1, 3), 3);
    await insert('b', DateTime.utc(2026, 1, 1), 1);
    await insert('c', DateTime.utc(2026, 1, 3), 3);
    expect(await db.activeDayBuckets(), [1, 3]);
  });

  test('typed dimensions round-trip', () async {
    await insert(
      'providerConnected',
      DateTime.utc(2026, 1, 1),
      1,
      provider: 'gemini',
      reason: 'ok',
      bucket: 3,
    );
    final row = (await db.getAllEvents()).single;
    expect(row.provider, 'gemini');
    expect(row.reason, 'ok');
    expect(row.valueBucket, 3);
  });

  test('clearAll removes every event and returns the deleted count', () async {
    await insert('x', DateTime.utc(2026, 1, 1), 1);
    await insert('y', DateTime.utc(2026, 1, 2), 2);
    expect(await db.clearAll(), 2);
    expect(await db.getAllEvents(), isEmpty);
  });
}
