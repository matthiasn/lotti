import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

enum _OperationKind { register, consume, advance }

class _Operation {
  const _Operation({
    required this.kind,
    required this.eventSlot,
    required this.advanceSeconds,
  });

  final _OperationKind kind;
  final int eventSlot;
  final int advanceSeconds;

  String get eventId =>
      r'$generated-'
      '$eventSlot';

  @override
  String toString() =>
      '_Operation(kind: $kind, eventSlot: $eventSlot, '
      'advanceSeconds: $advanceSeconds)';
}

class _Scenario {
  const _Scenario({required this.maxEntries, required this.operations});

  final int maxEntries;
  final List<_Operation> operations;

  @override
  String toString() =>
      '_Scenario(maxEntries: $maxEntries, operations: $operations)';
}

class _ExpectedRegistry {
  _ExpectedRegistry({required this.ttlSeconds, required this.maxEntries});

  final int ttlSeconds;
  final int maxEntries;
  final LinkedHashMap<String, int> entries = LinkedHashMap<String, int>();
  int nowSecond = 0;

  void advance(int seconds) {
    nowSecond += seconds;
  }

  void register(String eventId) {
    _prune();
    entries
      ..remove(eventId)
      ..[eventId] = nowSecond + ttlSeconds;
    while (entries.length > maxEntries) {
      entries.remove(entries.keys.first);
    }
  }

  bool contains(String eventId) {
    _prune();
    return entries.containsKey(eventId);
  }

  void _prune() {
    entries.removeWhere((_, expirySecond) => expirySecond < nowSecond);
  }
}

extension _AnySentRegistryScenario on glados.Any {
  glados.Generator<_OperationKind> get operationKind =>
      glados.AnyUtils(this).choose(_OperationKind.values);

  glados.Generator<_Operation> get operation =>
      glados.CombinableAny(this).combine3(
        operationKind,
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 7),
        (_OperationKind kind, int eventSlot, int advanceSeconds) => _Operation(
          kind: kind,
          eventSlot: eventSlot,
          advanceSeconds: advanceSeconds,
        ),
      );

  glados.Generator<_Scenario> get registryScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(1, 5),
        glados.ListAnys(this).listWithLengthInRange(1, 30, operation),
        (int maxEntries, List<_Operation> operations) => _Scenario(
          maxEntries: maxEntries,
          operations: operations,
        ),
      );
}

void main() {
  test('consume reports registered IDs until their TTL expires', () {
    final clock = _MutableClock(DateTime.utc(2024));
    final registry = SentEventRegistry(
      ttl: const Duration(seconds: 5),
      clockSource: clock,
    )..register(r'$evt');

    expect(registry.consume(r'$evt'), isTrue);
    clock.advance(const Duration(seconds: 5));
    expect(registry.consume(r'$evt'), isTrue);
    clock.advance(const Duration(seconds: 1));
    expect(registry.consume(r'$evt'), isFalse);
  });

  test('capacity evicts the oldest ID in FIFO order', () {
    final registry = SentEventRegistry(maxEntries: 2)
      ..register(r'$a')
      ..register(r'$b')
      ..register(r'$c');

    expect(registry.consume(r'$a'), isFalse);
    expect(registry.consume(r'$b'), isTrue);
    expect(registry.consume(r'$c'), isTrue);
  });

  test('re-registering refreshes expiry and FIFO order', () {
    final clock = _MutableClock(DateTime.utc(2024));
    final registry =
        SentEventRegistry(
            ttl: const Duration(seconds: 5),
            maxEntries: 2,
            clockSource: clock,
          )
          ..register(r'$a')
          ..register(r'$b');

    clock.advance(const Duration(seconds: 3));
    registry
      ..register(r'$a')
      ..register(r'$c');

    expect(registry.consume(r'$b'), isFalse);
    expect(registry.consume(r'$a'), isTrue);
    clock.advance(const Duration(seconds: 3));
    expect(registry.consume(r'$a'), isTrue);
  });

  test('empty event IDs assert', () {
    final registry = SentEventRegistry();

    expect(() => registry.register(''), throwsA(isA<AssertionError>()));
    expect(() => registry.consume(''), throwsA(isA<AssertionError>()));
  });

  glados.Glados(
    glados.any.registryScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'generated operation sequences preserve TTL and FIFO capacity',
    (scenario) {
      const ttlSeconds = 5;
      final clock = _MutableClock(DateTime.utc(2024));
      final registry = SentEventRegistry(
        ttl: const Duration(seconds: ttlSeconds),
        maxEntries: scenario.maxEntries,
        pruneInterval: Duration.zero,
        clockSource: clock,
      );
      final expected = _ExpectedRegistry(
        ttlSeconds: ttlSeconds,
        maxEntries: scenario.maxEntries,
      );

      for (final operation in scenario.operations) {
        switch (operation.kind) {
          case _OperationKind.register:
            registry.register(operation.eventId);
            expected.register(operation.eventId);
          case _OperationKind.consume:
            expect(
              registry.consume(operation.eventId),
              expected.contains(operation.eventId),
            );
          case _OperationKind.advance:
            final delta = Duration(seconds: operation.advanceSeconds);
            clock.advance(delta);
            expected.advance(operation.advanceSeconds);
        }

        for (var slot = 0; slot < 5; slot++) {
          final eventId =
              r'$generated-'
              '$slot';
          expect(registry.consume(eventId), expected.contains(eventId));
        }
      }
    },
    tags: 'glados',
  );
}
