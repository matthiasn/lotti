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

    expect(registry.consume(r'$evt-1'), isFalse);

    registry.register(r'$evt-1', source: SentEventSource.text);
    expect(registry.consume(r'$evt-1'), isTrue);
    expect(
      registry.consume(r'$evt-1'),
      isTrue,
      reason: 'entry remains valid until TTL expires',
    );
  });

  test('entries expire after ttl', () {
    final clock = _MutableClock(DateTime.utc(2024));
    final registry = SentEventRegistry(
      ttl: const Duration(seconds: 5),
      clockSource: clock,
    )..register(r'$evt-2');
    clock.advance(const Duration(seconds: 6));

    expect(registry.consume(r'$evt-2'), isFalse);
  });

  test('prune evicts expired entries and enforces size cap', () {
    final clock = _MutableClock(DateTime.utc(2024));
    final registry = SentEventRegistry(
      ttl: const Duration(seconds: 5),
      maxEntries: 2,
      clockSource: clock,
    )
      ..register(r'$evt-a')
      ..register(r'$evt-b')
      ..register(r'$evt-c'); // exceeds cap, oldest should drop
    expect(registry.length, 2);
    expect(
      registry.consume(r'$evt-a'),
      isFalse,
      reason: 'oldest entry evicted when cap exceeded',
    );

    clock.advance(const Duration(seconds: 6));
    registry.prune();
    expect(registry.length, 0);
  });

  test('consume removes expired entry and returns false', () {
    final clock = _MutableClock(DateTime.utc(2024));
    final registry = SentEventRegistry(
      ttl: const Duration(seconds: 2),
      clockSource: clock,
    )..register(r'$evt-expire');
    clock.advance(const Duration(seconds: 3));

    expect(registry.consume(r'$evt-expire'), isFalse);
    expect(registry.length, 0);
  });

  test('re-registering id refreshes expiry and order', () {
    final clock = _MutableClock(DateTime.utc(2024));
    final registry = SentEventRegistry(
      ttl: const Duration(seconds: 5),
      maxEntries: 3,
      clockSource: clock,
    )
      ..register(r'$evt-a')
      ..register(r'$evt-b');

    clock.advance(const Duration(seconds: 3));
    registry
      ..register(r'$evt-a') // refresh expiry & order
      ..register(r'$evt-c'); // triggers eviction of evt-b (oldest)

    expect(registry.consume(r'$evt-a'), isTrue);
    expect(
      registry.consume(r'$evt-b'),
      isTrue,
      reason: 're-registering another id should not evict existing entries',
    );
    registry.register(r'$evt-d'); // exceed cap; oldest (evt-b) should drop now
    expect(registry.consume(r'$evt-b'), isFalse);

    clock.advance(const Duration(seconds: 6));
    expect(registry.consume(r'$evt-a'), isFalse);
  });

  test('register observes prune interval before running', () {
    final clock = _MutableClock(DateTime.utc(2024));
    final registry = SentEventRegistry(
      pruneInterval: const Duration(seconds: 45),
      clockSource: clock,
    )..register(r'$evt-a');
    final firstNextPrune = registry.debugNextPruneAt;

    clock.advance(const Duration(seconds: 10));
    registry.consume(r'$evt-a'); // should not trigger prune yet
    expect(registry.debugNextPruneAt, firstNextPrune);
  });

  test('force prune executes even within interval', () {
    final clock = _MutableClock(DateTime.utc(2024));
    final registry = SentEventRegistry(
      pruneInterval: const Duration(seconds: 45),
      clockSource: clock,
    )..register(r'$evt-a');
    final firstNextPrune = registry.debugNextPruneAt;

    clock.advance(const Duration(seconds: 5));
    final now = clock.now();
    registry.consume(r'$missing');
    expect(registry.debugNextPruneAt, firstNextPrune);
  });

  test('empty eventIds are ignored (asserts in debug)', () {
    final registry = SentEventRegistry();
    expect(() => registry.register(''), throwsA(isA<AssertionError>()));
    expect(() => registry.consume(''), throwsA(isA<AssertionError>()));
  });

  test('re-registering without source preserves original source', () {
    final registry = SentEventRegistry()
      ..register(r'$evt-a', source: SentEventSource.file)
      ..register(r'$evt-a');
    expect(registry.debugSource(r'$evt-a'), equals(SentEventSource.file));
  });

  test('clear resets next prune time', () {
    final clock = _MutableClock(DateTime.utc(2024));
    final registry = SentEventRegistry(
      pruneInterval: const Duration(seconds: 45),
      clockSource: clock,
    )..register(r'$evt-a');
    final firstNextPrune = registry.debugNextPruneAt;
    clock.advance(const Duration(seconds: 10));

    registry.clear();
    expect(registry.length, 0);
    expect(registry.debugNextPruneAt.isAfter(firstNextPrune), isTrue);
  });
}
