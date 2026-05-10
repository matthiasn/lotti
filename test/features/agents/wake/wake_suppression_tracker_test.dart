import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/wake/wake_suppression_tracker.dart';
import 'package:lotti/features/sync/vector_clock.dart';

enum _GeneratedSuppressionTokenSlot { first, second, third, unrelated }

const _generatedSuppressionAgentId = 'generated-suppression-agent';
const _generatedSuppressionOtherAgentId = 'generated-suppression-other-agent';
final _generatedSuppressionBase = DateTime(2026, 5, 17, 9);

String _generatedSuppressionToken(_GeneratedSuppressionTokenSlot slot) =>
    'generated-suppression-token-${slot.name}';

class _GeneratedSuppressionScenario {
  const _GeneratedSuppressionScenario({
    required this.confirmedTokens,
    required this.preRegisteredTokens,
    required this.matchedTokens,
    required this.queryRecordedAgent,
    required this.elapsedMilliseconds,
  });

  final List<_GeneratedSuppressionTokenSlot> confirmedTokens;
  final List<_GeneratedSuppressionTokenSlot> preRegisteredTokens;
  final List<_GeneratedSuppressionTokenSlot> matchedTokens;
  final bool queryRecordedAgent;
  final int elapsedMilliseconds;

  String get queryAgentId => queryRecordedAgent
      ? _generatedSuppressionAgentId
      : _generatedSuppressionOtherAgentId;

  Set<String> get confirmedTokenSet =>
      confirmedTokens.map(_generatedSuppressionToken).toSet();

  Set<String> get preRegisteredTokenSet =>
      preRegisteredTokens.map(_generatedSuppressionToken).toSet();

  Set<String> get matchedTokenSet =>
      matchedTokens.map(_generatedSuppressionToken).toSet();

  bool get expectedConfirmedSuppressed {
    if (!queryRecordedAgent || confirmedTokenSet.isEmpty) return false;
    if (elapsedMilliseconds >
        WakeSuppressionTracker.suppressionTtl.inMilliseconds) {
      return false;
    }
    return matchedTokenSet.every(confirmedTokenSet.contains);
  }

  bool get expectedPreRegisteredSuppressed {
    if (!queryRecordedAgent || preRegisteredTokenSet.isEmpty) return false;
    return matchedTokenSet.every(preRegisteredTokenSet.contains);
  }

  Map<String, VectorClock> get confirmedEntries => {
    for (final token in confirmedTokenSet) token: const VectorClock({}),
  };

  @override
  String toString() {
    return '_GeneratedSuppressionScenario('
        'confirmedTokens: $confirmedTokens, '
        'preRegisteredTokens: $preRegisteredTokens, '
        'matchedTokens: $matchedTokens, '
        'queryRecordedAgent: $queryRecordedAgent, '
        'elapsedMilliseconds: $elapsedMilliseconds)';
  }
}

extension _AnyGeneratedSuppressionScenario on glados.Any {
  glados.Generator<_GeneratedSuppressionTokenSlot> get suppressionTokenSlot =>
      glados.AnyUtils(this).choose(_GeneratedSuppressionTokenSlot.values);

  glados.Generator<List<_GeneratedSuppressionTokenSlot>>
  get suppressionTokenSlots =>
      glados.ListAnys(this).listWithLengthInRange(0, 5, suppressionTokenSlot);

  glados.Generator<_GeneratedSuppressionScenario> get suppressionScenario =>
      glados.CombinableAny(this).combine5(
        suppressionTokenSlots,
        suppressionTokenSlots,
        suppressionTokenSlots,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(
          0,
          WakeSuppressionTracker.suppressionTtl.inMilliseconds + 1000,
        ),
        (
          List<_GeneratedSuppressionTokenSlot> confirmedTokens,
          List<_GeneratedSuppressionTokenSlot> preRegisteredTokens,
          List<_GeneratedSuppressionTokenSlot> matchedTokens,
          bool queryRecordedAgent,
          int elapsedMilliseconds,
        ) => _GeneratedSuppressionScenario(
          confirmedTokens: confirmedTokens,
          preRegisteredTokens: preRegisteredTokens,
          matchedTokens: matchedTokens,
          queryRecordedAgent: queryRecordedAgent,
          elapsedMilliseconds: elapsedMilliseconds,
        ),
      );
}

void main() {
  group('WakeSuppressionTracker', () {
    test('confirmed suppression includes exact TTL boundary', () {
      final tracker = WakeSuppressionTracker();

      withClock(Clock.fixed(_generatedSuppressionBase), () {
        tracker.recordMutatedEntities(
          _generatedSuppressionAgentId,
          {'entity-1': const VectorClock({})},
        );
      });

      withClock(
        Clock.fixed(
          _generatedSuppressionBase.add(WakeSuppressionTracker.suppressionTtl),
        ),
        () {
          expect(
            tracker.isSuppressed(
              _generatedSuppressionAgentId,
              {'entity-1'},
            ),
            isTrue,
          );
        },
      );

      withClock(
        Clock.fixed(
          _generatedSuppressionBase
              .add(WakeSuppressionTracker.suppressionTtl)
              .add(const Duration(milliseconds: 1)),
        ),
        () {
          expect(
            tracker.isSuppressed(
              _generatedSuppressionAgentId,
              {'entity-1'},
            ),
            isFalse,
          );
        },
      );
    });

    glados.Glados(
      glados.any.suppressionScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'matches generated confirmed and pre-registered suppression semantics',
      (scenario) {
        final tracker = WakeSuppressionTracker();

        withClock(Clock.fixed(_generatedSuppressionBase), () {
          tracker
            ..recordMutatedEntities(
              _generatedSuppressionAgentId,
              scenario.confirmedEntries,
            )
            ..preRegisterSuppression(
              _generatedSuppressionAgentId,
              scenario.preRegisteredTokenSet,
            );
        });

        withClock(
          Clock.fixed(
            _generatedSuppressionBase.add(
              Duration(milliseconds: scenario.elapsedMilliseconds),
            ),
          ),
          () {
            expect(
              tracker.isSuppressed(
                scenario.queryAgentId,
                scenario.matchedTokenSet,
              ),
              scenario.expectedConfirmedSuppressed,
              reason: '$scenario',
            );
            expect(
              tracker.isPreRegisteredSuppressed(
                scenario.queryAgentId,
                scenario.matchedTokenSet,
              ),
              scenario.expectedPreRegisteredSuppressed,
              reason: '$scenario',
            );

            tracker.clearAgent(_generatedSuppressionAgentId);

            expect(
              tracker.isSuppressed(
                _generatedSuppressionAgentId,
                scenario.matchedTokenSet,
              ),
              isFalse,
              reason: '$scenario',
            );
            expect(
              tracker.isPreRegisteredSuppressed(
                _generatedSuppressionAgentId,
                scenario.matchedTokenSet,
              ),
              isFalse,
              reason: '$scenario',
            );
          },
        );
      },
      tags: 'glados',
    );
  });
}
