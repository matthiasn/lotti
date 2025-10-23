import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';

class _MutableClock extends Clock {
  _MutableClock(DateTime seed) : _now = seed;

  DateTime _now;

  void advance(Duration delta) {
    _now = _now.add(delta);
  }

  @override
  DateTime now() => _now;
}

void main() {
  test('consume returns true only after registering id', () {
    final registry = SentEventRegistry(ttl: const Duration(seconds: 10));

    expect(registry.consume('evt-1'), isFalse);

    registry.register('evt-1', source: SentEventSource.text);
    expect(registry.consume('evt-1'), isTrue);
    expect(registry.consume('evt-1'), isFalse,
        reason: 'entry removed after consume');
  });

  test('entries expire after ttl', () {
    final clock = _MutableClock(DateTime.utc(2024));
    final registry = SentEventRegistry(
      ttl: const Duration(seconds: 5),
      clockSource: clock,
    )..register('evt-2');
    clock.advance(const Duration(seconds: 6));

    expect(registry.consume('evt-2'), isFalse);
  });

  test('prune evicts expired entries and enforces size cap', () {
    final clock = _MutableClock(DateTime.utc(2024));
    final registry = SentEventRegistry(
      ttl: const Duration(seconds: 5),
      maxEntries: 2,
      clockSource: clock,
    )
      ..register('evt-a')
      ..register('evt-b')
      ..register('evt-c'); // exceeds cap, oldest should drop
    expect(registry.length, 2);
    expect(registry.consume('evt-a'), isFalse);

    clock.advance(const Duration(seconds: 6));
    registry.prune();
    expect(registry.length, 0);
  });
}
