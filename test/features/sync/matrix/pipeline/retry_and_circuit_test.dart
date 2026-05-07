import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/retry_and_circuit.dart';

class _GeneratedRetryEntry {
  const _GeneratedRetryEntry({
    required this.idSlot,
    required this.attempts,
  });

  final int idSlot;
  final int attempts;

  String get id => 'generated-$idSlot';

  DateTime nextDue(DateTime base) => base.add(Duration(milliseconds: idSlot));

  @override
  String toString() {
    return '_GeneratedRetryEntry('
        'idSlot: $idSlot, '
        'attempts: $attempts'
        ')';
  }
}

class _GeneratedRetryPruneScenario {
  const _GeneratedRetryPruneScenario({
    required this.ttlMs,
    required this.maxEntries,
    required this.nowOffsetMs,
    required this.entries,
  });

  final int ttlMs;
  final int maxEntries;
  final int nowOffsetMs;
  final List<_GeneratedRetryEntry> entries;

  DateTime now(DateTime base) => base.add(Duration(milliseconds: nowOffsetMs));

  Map<String, _GeneratedRetryEntry> latestById() {
    return {
      for (final entry in entries) entry.id: entry,
    };
  }

  Set<String> expectedRetainedIds(DateTime base) {
    final nowValue = now(base);
    final ttl = Duration(milliseconds: ttlMs);
    final retained = Map<String, _GeneratedRetryEntry>.of(latestById())
      ..removeWhere(
        (_, entry) => nowValue.difference(entry.nextDue(base)) > ttl,
      );

    if (retained.length <= maxEntries) return retained.keys.toSet();

    final sorted = retained.entries.toList()
      ..sort(
        (a, b) => a.value.nextDue(base).compareTo(b.value.nextDue(base)),
      );
    final idsToRemove = {
      for (var index = 0; index < retained.length - maxEntries; index++)
        sorted[index].key,
    };
    return {
      for (final id in retained.keys)
        if (!idsToRemove.contains(id)) id,
    };
  }

  @override
  String toString() {
    return '_GeneratedRetryPruneScenario('
        'ttlMs: $ttlMs, '
        'maxEntries: $maxEntries, '
        'nowOffsetMs: $nowOffsetMs, '
        'entries: $entries'
        ')';
  }
}

extension _AnyRetryAndCircuitScenario on glados.Any {
  glados.Generator<_GeneratedRetryEntry> get retryEntry =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 8),
        glados.IntAnys(this).intInRange(1, 5),
        (int idSlot, int attempts) => _GeneratedRetryEntry(
          idSlot: idSlot,
          attempts: attempts,
        ),
      );

  glados.Generator<_GeneratedRetryPruneScenario> get retryPruneScenario =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 8),
        glados.IntAnys(this).intInRange(1, 7),
        glados.IntAnys(this).intInRange(0, 12),
        glados.ListAnys(this).listWithLengthInRange(1, 14, retryEntry),
        (
          int ttlMs,
          int maxEntries,
          int nowOffsetMs,
          List<_GeneratedRetryEntry> entries,
        ) => _GeneratedRetryPruneScenario(
          ttlMs: ttlMs,
          maxEntries: maxEntries,
          nowOffsetMs: nowOffsetMs,
          entries: entries,
        ),
      );
}

void main() {
  group('RetryTracker', () {
    test('blocks until nextDue and schedules/clears/prunes', () {
      final tracker = RetryTracker(
        ttl: const Duration(seconds: 1),
        maxEntries: 2,
      );
      final now = DateTime.fromMillisecondsSinceEpoch(0);
      final due = now.add(const Duration(milliseconds: 500));

      expect(tracker.size(), 0);
      tracker.scheduleNext('a', 1, due);
      expect(tracker.size(), 1);
      expect(tracker.blockedUntil('a', now), due);
      expect(tracker.attempts('a'), 1);

      // After due passed, not blocked
      final later = now.add(const Duration(milliseconds: 600));
      expect(tracker.blockedUntil('a', later), isNull);

      // Prune based on ttl
      final beyondTtl = now.add(const Duration(seconds: 2));
      tracker.prune(beyondTtl);
      expect(tracker.size(), 0);

      // Enforce max entries by evicting oldest
      tracker
        ..scheduleNext('a', 1, now)
        ..scheduleNext('b', 1, now.add(const Duration(milliseconds: 1)))
        ..scheduleNext('c', 1, now.add(const Duration(milliseconds: 2)));
      // Enforce size cap via prune
      // ignore: cascade_invocations
      tracker.prune(now);
      expect(tracker.size(), 2);

      // mark all due now
      tracker.markAllDueNow(now);
      expect(tracker.blockedUntil('b', now), isNull);
      expect(tracker.blockedUntil('c', now), isNull);
    });

    glados.Glados(
      glados.any.retryPruneScenario,
    ).test(
      'generated prune keeps the non-expired newest schedule bounded by cap',
      (scenario) {
        final base = DateTime(2024, 3, 15);
        final now = scenario.now(base);
        final tracker = RetryTracker(
          ttl: Duration(milliseconds: scenario.ttlMs),
          maxEntries: scenario.maxEntries,
        );

        for (final entry in scenario.entries) {
          tracker.scheduleNext(entry.id, entry.attempts, entry.nextDue(base));
        }

        final latestById = scenario.latestById();
        for (final entry in latestById.values) {
          expect(tracker.attempts(entry.id), entry.attempts);
          expect(
            tracker.blockedUntil(entry.id, now),
            now.isBefore(entry.nextDue(base)) ? entry.nextDue(base) : null,
          );
        }

        tracker.prune(now);

        final retained = scenario.expectedRetainedIds(base);
        expect(tracker.size(), retained.length);
        for (var idSlot = 0; idSlot <= 8; idSlot++) {
          final id = 'generated-$idSlot';
          final entry = latestById[id];
          if (retained.contains(id)) {
            expect(tracker.attempts(id), entry?.attempts);
            expect(
              tracker.blockedUntil(id, now),
              now.isBefore(entry!.nextDue(base)) ? entry.nextDue(base) : null,
            );
          } else {
            expect(tracker.attempts(id), 0);
            expect(tracker.blockedUntil(id, now), isNull);
          }
        }
      },
    );
  });

  group('CircuitBreaker', () {
    test('opens after threshold and provides cooldown, resets on success', () {
      final cb = CircuitBreaker(
        failureThreshold: 3,
        cooldown: const Duration(seconds: 2),
      );
      final t0 = DateTime.fromMillisecondsSinceEpoch(0);
      expect(cb.remainingCooldown(t0), isNull);
      expect(cb.isOpen(t0), isFalse);

      // Record fewer than threshold -> still closed
      expect(cb.recordFailures(2, t0), isFalse);
      expect(cb.isOpen(t0), isFalse);

      // Cross threshold -> opens
      expect(cb.recordFailures(1, t0), isTrue);
      expect(cb.isOpen(t0), isTrue);
      expect(cb.remainingCooldown(t0), const Duration(seconds: 2));

      // After cooldown finished -> closed
      final t1 = t0.add(const Duration(seconds: 3));
      expect(cb.isOpen(t1), isFalse);

      // Reset clears failure counter
      cb.reset();
      expect(cb.isOpen(t1), isFalse);
    });
  });
}
