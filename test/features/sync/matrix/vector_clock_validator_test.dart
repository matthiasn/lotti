import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/matrix/vector_clock_validator.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

enum _GeneratedVcValidatorOperationKind {
  staleFirstAttempt,
  staleRetryAttempt,
  localDominates,
  equal,
  missingVectorClock,
}

class _GeneratedVcValidatorOperation {
  const _GeneratedVcValidatorOperation({
    required this.kind,
    required this.pathSlot,
  });

  final _GeneratedVcValidatorOperationKind kind;
  final int pathSlot;

  String get jsonPath => '/generated-validator-$pathSlot.json';

  int get attempt {
    switch (kind) {
      case _GeneratedVcValidatorOperationKind.staleRetryAttempt:
        return 1;
      case _GeneratedVcValidatorOperationKind.staleFirstAttempt:
      case _GeneratedVcValidatorOperationKind.localDominates:
      case _GeneratedVcValidatorOperationKind.equal:
      case _GeneratedVcValidatorOperationKind.missingVectorClock:
        return 0;
    }
  }

  VectorClock? get candidateVectorClock {
    switch (kind) {
      case _GeneratedVcValidatorOperationKind.staleFirstAttempt:
      case _GeneratedVcValidatorOperationKind.staleRetryAttempt:
        return const VectorClock({'host': 1});
      case _GeneratedVcValidatorOperationKind.localDominates:
        return const VectorClock({'host': 4});
      case _GeneratedVcValidatorOperationKind.equal:
        return const VectorClock({'host': 3});
      case _GeneratedVcValidatorOperationKind.missingVectorClock:
        return null;
    }
  }

  VectorClockDecision expectedDecision(Map<String, int> failuresByPath) {
    switch (kind) {
      case _GeneratedVcValidatorOperationKind.staleFirstAttempt:
      case _GeneratedVcValidatorOperationKind.staleRetryAttempt:
        final failures = (failuresByPath[jsonPath] ?? 0) + 1;
        failuresByPath[jsonPath] = failures;
        if (failures >= VectorClockValidator.maxStaleDescriptorFailures) {
          return VectorClockDecision.circuitBreaker;
        }
        return attempt == 0
            ? VectorClockDecision.retryAfterPurge
            : VectorClockDecision.staleAfterRefresh;
      case _GeneratedVcValidatorOperationKind.localDominates:
      case _GeneratedVcValidatorOperationKind.equal:
        failuresByPath.remove(jsonPath);
        return VectorClockDecision.accept;
      case _GeneratedVcValidatorOperationKind.missingVectorClock:
        failuresByPath.remove(jsonPath);
        return VectorClockDecision.missingVectorClock;
    }
  }

  @override
  String toString() {
    return '_GeneratedVcValidatorOperation('
        'kind: $kind, '
        'pathSlot: $pathSlot'
        ')';
  }
}

class _GeneratedVcValidatorScenario {
  const _GeneratedVcValidatorScenario({required this.operations});

  final List<_GeneratedVcValidatorOperation> operations;

  List<VectorClockDecision> expectedDecisions() {
    final failuresByPath = <String, int>{};
    return [
      for (final operation in operations)
        operation.expectedDecision(failuresByPath),
    ];
  }

  @override
  String toString() {
    return '_GeneratedVcValidatorScenario(operations: $operations)';
  }
}

extension _AnyGeneratedVcValidatorScenario on glados.Any {
  glados.Generator<_GeneratedVcValidatorOperationKind>
  get vcValidatorOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedVcValidatorOperationKind.values);

  glados.Generator<_GeneratedVcValidatorOperation> get vcValidatorOperation =>
      glados.CombinableAny(this).combine2(
        vcValidatorOperationKind,
        glados.IntAnys(this).intInRange(0, 5),
        (
          _GeneratedVcValidatorOperationKind kind,
          int pathSlot,
        ) => _GeneratedVcValidatorOperation(
          kind: kind,
          pathSlot: pathSlot,
        ),
      );

  glados.Generator<_GeneratedVcValidatorScenario> get vcValidatorScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(1, 48, vcValidatorOperation)
          .map(
            (operations) =>
                _GeneratedVcValidatorScenario(operations: operations),
          );
}

void main() {
  group('VectorClockValidator', () {
    late MockDomainLogger logging;
    late VectorClockValidator validator;

    setUp(() {
      logging = MockDomainLogger();
      validator = VectorClockValidator(loggingService: logging);
    });

    JournalEntry buildEntry(VectorClock? vc) => JournalEntry(
      meta: Metadata(
        id: 'entry',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        vectorClock: vc,
      ),
      entryText: const EntryText(plainText: 'text'),
    );

    test('returns retryAfterPurge for stale first attempt', () {
      final decision = validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 2}),
        candidate: buildEntry(const VectorClock({'n': 1})),
        attempt: 0,
      );
      expect(decision, VectorClockDecision.retryAfterPurge);
      verify(
        () => logging.log(
          LogDomain.sync,
          any<String>(that: contains('smart.fetch.stale_vc path=/path.json')),
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('returns staleAfterRefresh on subsequent attempt', () {
      validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 3}),
        candidate: buildEntry(const VectorClock({'n': 1})),
        attempt: 0,
      );
      final decision = validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 3}),
        candidate: buildEntry(const VectorClock({'n': 1})),
        attempt: 1,
      );
      expect(decision, VectorClockDecision.staleAfterRefresh);
      verify(
        () => logging.log(
          LogDomain.sync,
          any<String>(
            that: contains('smart.fetch.stale_vc.pending path=/path.json'),
          ),
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('trips circuit breaker after repeated stale descriptors', () {
      for (
        var i = 0;
        i < VectorClockValidator.maxStaleDescriptorFailures - 1;
        i++
      ) {
        expect(
          validator.evaluate(
            jsonPath: '/path.json',
            incomingVectorClock: const VectorClock({'n': 5}),
            candidate: buildEntry(const VectorClock({'n': 1})),
            attempt: 0,
          ),
          VectorClockDecision.retryAfterPurge,
        );
      }
      final decision = validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 5}),
        candidate: buildEntry(const VectorClock({'n': 1})),
        attempt: 0,
      );
      expect(decision, VectorClockDecision.circuitBreaker);
      verify(
        () => logging.log(
          LogDomain.sync,
          any<String>(
            that: contains('smart.fetch.stale_vc.breaker path=/path.json'),
          ),
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('returns missingVectorClock when descriptor lacks vector clock', () {
      final decision = validator.evaluate(
        jsonPath: '/missing.json',
        incomingVectorClock: const VectorClock({'n': 1}),
        candidate: buildEntry(null),
        attempt: 0,
      );
      expect(decision, VectorClockDecision.missingVectorClock);
      verify(
        () => logging.log(
          LogDomain.sync,
          any<String>(
            that: contains('smart.fetch.missing_vc path=/missing.json'),
          ),
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('resets failure count when descriptor becomes fresh', () {
      validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 3}),
        candidate: buildEntry(const VectorClock({'n': 1})),
        attempt: 0,
      );
      final acceptDecision = validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 3}),
        candidate: buildEntry(const VectorClock({'n': 4})),
        attempt: 0,
      );
      expect(acceptDecision, VectorClockDecision.accept);

      final retryDecision = validator.evaluate(
        jsonPath: '/path.json',
        incomingVectorClock: const VectorClock({'n': 3}),
        candidate: buildEntry(const VectorClock({'n': 2})),
        attempt: 0,
      );
      expect(retryDecision, VectorClockDecision.retryAfterPurge);
    });

    glados.Glados(
      glados.any.vcValidatorScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'generated interleaved descriptor checks keep stale counters path-scoped',
      (scenario) {
        final localLogging = MockDomainLogger();
        final localValidator = VectorClockValidator(
          loggingService: localLogging,
        );
        final decisions = <VectorClockDecision>[];

        for (final operation in scenario.operations) {
          decisions.add(
            localValidator.evaluate(
              jsonPath: operation.jsonPath,
              incomingVectorClock: const VectorClock({'host': 3}),
              candidate: buildEntry(operation.candidateVectorClock),
              attempt: operation.attempt,
            ),
          );
        }

        expect(
          decisions,
          scenario.expectedDecisions(),
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });
}
