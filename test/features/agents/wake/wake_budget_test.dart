import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/g_counter.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_budget.dart';

/// One step of a multi-device run: `host` either claims a wake on its own
/// replica (`from == null`) or receives replica `from`'s current row by sync.
typedef _Step = ({int host, int? from});

const _hosts = ['host-a', 'host-b', 'host-c'];
const _day = '2026-10-02';

extension on glados.Any {
  glados.Generator<List<_Step>> get steps => glados.ListAnys(this).list(
    glados.CombinableAny(this).combine2(
      glados.IntAnys(this).intInRange(0, _hosts.length),
      // _hosts.length means "claim"; anything else is the sender.
      glados.IntAnys(this).intInRange(0, _hosts.length + 1),
      (int host, int other) =>
          (host: host, from: other == _hosts.length ? null : other),
    ),
  );
}

void main() {
  group('effectiveMaxWakesPerDay', () {
    test('defaults a missing preference to ten', () {
      expect(effectiveMaxWakesPerDay(const AgentConfig()), 10);
      expect(WakeBudget.defaultMaxWakesPerDay, 10);
    });

    test('clamps a stored value a peer could have written out of range', () {
      expect(
        effectiveMaxWakesPerDay(const AgentConfig(maxWakesPerDay: 0)),
        WakeBudget.minMaxWakesPerDay,
      );
      expect(
        effectiveMaxWakesPerDay(const AgentConfig(maxWakesPerDay: 500)),
        WakeBudget.maxMaxWakesPerDay,
      );
      expect(effectiveMaxWakesPerDay(const AgentConfig(maxWakesPerDay: 5)), 5);
    });

    test('offers only choices inside the clamp range', () {
      for (final choice in WakeBudget.choices) {
        expect(
          choice,
          inInclusiveRange(
            WakeBudget.minMaxWakesPerDay,
            WakeBudget.maxMaxWakesPerDay,
          ),
        );
      }
      expect(WakeBudget.choices, contains(WakeBudget.defaultMaxWakesPerDay));
    });
  });

  group('evaluateWakeBudget', () {
    test('stops automatic work at the budget', () {
      expect(
        evaluateWakeBudget(
          used: 9,
          maxPerDay: 10,
          initiator: WakeInitiator.automation,
        ),
        WakeBudgetVerdict.allowed,
      );
      expect(
        evaluateWakeBudget(
          used: 10,
          maxPerDay: 10,
          initiator: WakeInitiator.automation,
        ),
        WakeBudgetVerdict.automaticBudgetExhausted,
      );
    });

    test('lets an explicit request past the budget up to twice it', () {
      expect(
        evaluateWakeBudget(
          used: 10,
          maxPerDay: 10,
          initiator: WakeInitiator.user,
        ),
        WakeBudgetVerdict.allowed,
      );
      expect(
        evaluateWakeBudget(
          used: 19,
          maxPerDay: 10,
          initiator: WakeInitiator.user,
        ),
        WakeBudgetVerdict.allowed,
      );
      for (final initiator in WakeInitiator.values) {
        expect(
          evaluateWakeBudget(used: 20, maxPerDay: 10, initiator: initiator),
          WakeBudgetVerdict.hardCeilingReached,
        );
      }
    });

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(0, 60),
      glados.IntAnys(glados.any).intInRange(1, 25),
    ).test('never allows automatic work at or past the budget, nor any work '
        'at or past the hard ceiling', (used, maxPerDay) {
      final automatic = evaluateWakeBudget(
        used: used,
        maxPerDay: maxPerDay,
        initiator: WakeInitiator.automation,
      );
      final user = evaluateWakeBudget(
        used: used,
        maxPerDay: maxPerDay,
        initiator: WakeInitiator.user,
      );
      expect(automatic.isAllowed, used < maxPerDay);
      expect(user.isAllowed, used < WakeBudget.hardCeilingFor(maxPerDay));
    }, tags: 'glados');
  });

  group('wakeBudgetDay', () {
    test('formats the local calendar day with zero padding', () {
      expect(wakeBudgetDay(DateTime(2026, 3, 4, 23, 59)), '2026-03-04');
      expect(wakeBudgetDay(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('the daily ledger', () {
    test('counts only the asked day across every host', () {
      var ledger = const GCounter.empty();
      ledger = recordWake(ledger, day: '2026-10-01', host: 'host-a');
      ledger = recordWake(ledger, day: _day, host: 'host-a');
      ledger = recordWake(ledger, day: _day, host: 'host-b');
      ledger = recordWake(ledger, day: _day, host: 'host-b');

      expect(wakesUsedOn(ledger, _day), 3);
      expect(wakesUsedOn(ledger, '2026-10-01'), 1);
      expect(wakesUsedOn(ledger, '2026-10-03'), 0);
    });

    test('prunes days older than yesterday when recording', () {
      var ledger = const GCounter({
        '2026-09-29|host-a': 4,
        '2026-09-30|host-b': 2,
        '2026-10-01|host-a': 1,
      });
      ledger = recordWake(ledger, day: _day, host: 'host-a');

      expect(ledger.byHost, {
        '2026-10-01|host-a': 1,
        '$_day|host-a': 1,
      });
    });

    test('prunes across a month boundary', () {
      final ledger = recordWake(
        const GCounter({'2026-09-29|host-a': 4, '2026-09-30|host-a': 2}),
        day: '2026-10-01',
        host: 'host-a',
      );

      expect(ledger.byHost.keys, ['2026-09-30|host-a', '2026-10-01|host-a']);
    });

    glados.Glados(
      glados.any.steps,
      glados.ExploreConfig(numRuns: 200),
    ).test('no claim is lost to any order of sync deliveries', (steps) {
      // One replica of the state row per device. A device claims on its own
      // replica only; a delivery is the concurrent resolver's join.
      final replicas = List.filled(_hosts.length, const GCounter.empty());
      final claimsBy = List.filled(_hosts.length, 0);
      for (final step in steps) {
        final from = step.from;
        if (from == null) {
          replicas[step.host] = recordWake(
            replicas[step.host],
            day: _day,
            host: _hosts[step.host],
          );
          claimsBy[step.host]++;
        } else {
          replicas[step.host] = replicas[step.host].merge(replicas[from]);
        }
        // A device always sees at least its own claims: no delivery can
        // reset them, which is what lets it bound its own wakes offline.
        for (var h = 0; h < _hosts.length; h++) {
          expect(
            replicas[h].byHost['$_day|${_hosts[h]}'] ?? 0,
            claimsBy[h],
          );
        }
      }
      final converged = replicas.reduce((a, b) => a.merge(b));
      expect(
        wakesUsedOn(converged, _day),
        claimsBy.fold<int>(0, (sum, n) => sum + n),
      );
    }, tags: 'glados');
  });
}
