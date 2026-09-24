import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// A pair of genuinely-concurrent versions of one id, plus their timestamps.
///
/// Clocks are built so they are always concurrent and never equal — `local`
/// leads on `h0`, `incoming` leads on `h1` — which is exactly the situation in
/// which [resolveConcurrent] is consulted. By construction `localVc` is the
/// canonically-greater clock (it wins the `h0` comparison), so on equal
/// timestamps the local side is the deterministic winner.
class Scenario {
  const Scenario({
    required this.x,
    required this.y,
    required this.localSeconds,
    required this.incomingSeconds,
  });

  final int x;
  final int y;
  final int localSeconds;
  final int incomingSeconds;

  static final _base = DateTime(2024);

  VectorClock get localVc => VectorClock({'h0': x + 1, 'h1': y});
  VectorClock get incomingVc => VectorClock({'h0': x, 'h1': y + 1});
  DateTime get localUpdatedAt => _base.add(Duration(seconds: localSeconds));
  DateTime get incomingUpdatedAt =>
      _base.add(Duration(seconds: incomingSeconds));

  @override
  String toString() =>
      'Scenario(x:$x, y:$y, localSec:$localSeconds, incSec:$incomingSeconds)';
}

extension AnyResolver on glados.Any {
  glados.Generator<Scenario> get resolverScenario =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 1000),
        glados.IntAnys(this).intInRange(0, 1000),
        (x, y, localSeconds, incomingSeconds) => Scenario(
          x: x,
          y: y,
          localSeconds: localSeconds,
          incomingSeconds: incomingSeconds,
        ),
      );

  glados.Generator<VectorClock> get smallVectorClock =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 4),
        (a, b, c) => VectorClock({'h0': a, 'h1': b, 'h2': c}),
      );

  glados.Generator<GCounter> get gCounter => glados.ListAnys(this)
      .listWithLengthInRange(
        0,
        5,
        glados.CombinableAny(this).combine2(
          glados.IntAnys(this).intInRange(0, 3),
          glados.IntAnys(this).intInRange(0, 20),
          (int host, int count) => MapEntry('h$host', count),
        ),
      )
      .map((entries) {
        final byHost = <String, int>{};
        for (final entry in entries) {
          byHost[entry.key] = (byHost[entry.key] ?? 0) + entry.value;
        }
        return GCounter(byHost);
      });
}

ConcurrentWinner hResolve(Scenario s) => resolveConcurrent(
  localVc: s.localVc,
  incomingVc: s.incomingVc,
  localUpdatedAt: s.localUpdatedAt,
  incomingUpdatedAt: s.incomingUpdatedAt,
);
