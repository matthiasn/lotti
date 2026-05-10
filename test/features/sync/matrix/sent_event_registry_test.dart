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

enum _GeneratedRegistryOperationKind {
  registerWithoutSource,
  registerText,
  registerFile,
  consume,
  prune,
  clear,
  advance,
}

class _GeneratedRegistryOperation {
  const _GeneratedRegistryOperation({
    required this.kind,
    required this.eventSlot,
    required this.advanceSeconds,
  });

  final _GeneratedRegistryOperationKind kind;
  final int eventSlot;
  final int advanceSeconds;

  String get eventId =>
      r'$generated-'
      '$eventSlot';

  SentEventSource? get source {
    switch (kind) {
      case _GeneratedRegistryOperationKind.registerText:
        return SentEventSource.text;
      case _GeneratedRegistryOperationKind.registerFile:
        return SentEventSource.file;
      case _GeneratedRegistryOperationKind.registerWithoutSource:
      case _GeneratedRegistryOperationKind.consume:
      case _GeneratedRegistryOperationKind.prune:
      case _GeneratedRegistryOperationKind.clear:
      case _GeneratedRegistryOperationKind.advance:
        return null;
    }
  }

  @override
  String toString() {
    return '_GeneratedRegistryOperation('
        'kind: $kind, '
        'eventSlot: $eventSlot, '
        'advanceSeconds: $advanceSeconds'
        ')';
  }
}

class _GeneratedRegistryScenario {
  const _GeneratedRegistryScenario({
    required this.maxEntries,
    required this.operations,
  });

  final int maxEntries;
  final List<_GeneratedRegistryOperation> operations;

  @override
  String toString() {
    return '_GeneratedRegistryScenario('
        'maxEntries: $maxEntries, '
        'operations: $operations'
        ')';
  }
}

class _ExpectedRegistryEntry {
  _ExpectedRegistryEntry({
    required this.expirySecond,
    this.source,
  });

  int expirySecond;
  SentEventSource? source;
}

class _ExpectedSentRegistry {
  _ExpectedSentRegistry({
    required this.ttlSeconds,
    required this.maxEntries,
  });

  final int ttlSeconds;
  final int maxEntries;
  final LinkedHashMap<String, _ExpectedRegistryEntry> entries =
      LinkedHashMap<String, _ExpectedRegistryEntry>();
  int nowSecond = 0;

  void advance(int seconds) {
    nowSecond += seconds;
  }

  void register(String eventId, {SentEventSource? source}) {
    prune();
    final existing = entries.remove(eventId);
    entries[eventId] = _ExpectedRegistryEntry(
      expirySecond: nowSecond + ttlSeconds,
      source: source ?? existing?.source,
    );
    _enforceCapacity();
  }

  bool consume(String eventId) {
    prune();
    return entries.containsKey(eventId);
  }

  void prune() {
    entries.removeWhere((_, entry) => entry.expirySecond < nowSecond);
    _enforceCapacity();
  }

  void clear() {
    entries.clear();
  }

  void _enforceCapacity() {
    while (entries.length > maxEntries) {
      entries.remove(entries.keys.first);
    }
  }
}

extension _AnySentRegistryScenario on glados.Any {
  glados.Generator<_GeneratedRegistryOperationKind> get registryOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedRegistryOperationKind.values);

  glados.Generator<_GeneratedRegistryOperation> get registryOperation =>
      glados.CombinableAny(this).combine3(
        registryOperationKind,
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 7),
        (
          _GeneratedRegistryOperationKind kind,
          int eventSlot,
          int advanceSeconds,
        ) => _GeneratedRegistryOperation(
          kind: kind,
          eventSlot: eventSlot,
          advanceSeconds: advanceSeconds,
        ),
      );

  glados.Generator<_GeneratedRegistryScenario> get registryScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(1, 5),
        glados.ListAnys(this).listWithLengthInRange(1, 30, registryOperation),
        (
          int maxEntries,
          List<_GeneratedRegistryOperation> operations,
        ) => _GeneratedRegistryScenario(
          maxEntries: maxEntries,
          operations: operations,
        ),
      );
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
    final registry =
        SentEventRegistry(
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
    final registry =
        SentEventRegistry(
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
    // Observe that consume does not force pruning when there is no entry.
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

  glados.Glados(
    glados.any.registryScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test(
    'generated operation sequences preserve TTL, FIFO cap, and sources',
    (scenario) {
      const ttlSeconds = 5;
      final clock = _MutableClock(DateTime.utc(2024));
      final registry = SentEventRegistry(
        ttl: const Duration(seconds: ttlSeconds),
        maxEntries: scenario.maxEntries,
        pruneInterval: Duration.zero,
        clockSource: clock,
      );
      final expected = _ExpectedSentRegistry(
        ttlSeconds: ttlSeconds,
        maxEntries: scenario.maxEntries,
      );

      for (final operation in scenario.operations) {
        switch (operation.kind) {
          case _GeneratedRegistryOperationKind.registerWithoutSource:
          case _GeneratedRegistryOperationKind.registerText:
          case _GeneratedRegistryOperationKind.registerFile:
            registry.register(operation.eventId, source: operation.source);
            expected.register(operation.eventId, source: operation.source);
          case _GeneratedRegistryOperationKind.consume:
            expect(
              registry.consume(operation.eventId),
              expected.consume(
                operation.eventId,
              ),
            );
          case _GeneratedRegistryOperationKind.prune:
            registry.prune();
            expected.prune();
          case _GeneratedRegistryOperationKind.clear:
            registry.clear();
            expected.clear();
          case _GeneratedRegistryOperationKind.advance:
            final delta = Duration(seconds: operation.advanceSeconds);
            clock.advance(delta);
            expected.advance(operation.advanceSeconds);
        }

        expect(registry.length, expected.entries.length);
        for (var slot = 0; slot < 5; slot++) {
          final eventId =
              r'$generated-'
              '$slot';
          expect(
            registry.debugSource(eventId),
            expected.entries[eventId]?.source,
          );
        }
      }
    },
    tags: 'glados',
  );
}
