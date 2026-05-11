import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/logging_service.dart';

enum VectorClockDecision {
  accept,
  retryAfterPurge,
  staleAfterRefresh,
  circuitBreaker,
  missingVectorClock,
}

class VectorClockValidator {
  VectorClockValidator({required LoggingService loggingService})
    : _logging = loggingService;

  static const int maxStaleDescriptorFailures = 5;

  final LoggingService _logging;
  final Map<String, int> _staleDescriptorFailures = <String, int>{};

  VectorClockDecision evaluate({
    required String jsonPath,
    required VectorClock incomingVectorClock,
    required JournalEntity candidate,
    required int attempt,
  }) {
    final candidateVc = candidate.meta.vectorClock;
    if (candidateVc == null) {
      _logging.captureEvent(
        'smart.fetch.missing_vc path=$jsonPath expected=$incomingVectorClock',
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.fetch',
      );
      reset(jsonPath);
      return VectorClockDecision.missingVectorClock;
    }

    final status = VectorClock.compare(candidateVc, incomingVectorClock);
    if (status == VclockStatus.b_gt_a) {
      final failures = (_staleDescriptorFailures[jsonPath] ?? 0) + 1;
      _staleDescriptorFailures[jsonPath] = failures;
      if (failures >= maxStaleDescriptorFailures) {
        _logging.captureEvent(
          'smart.fetch.stale_vc.breaker path=$jsonPath retries=$failures limit=$maxStaleDescriptorFailures',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        );
        return VectorClockDecision.circuitBreaker;
      }
      if (attempt == 0) {
        _logging.captureEvent(
          'smart.fetch.stale_vc path=$jsonPath expected=$incomingVectorClock got=$candidateVc',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        );
        return VectorClockDecision.retryAfterPurge;
      }
      _logging.captureEvent(
        'smart.fetch.stale_vc.pending path=$jsonPath expected=$incomingVectorClock got=$candidateVc',
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.fetch',
      );
      return VectorClockDecision.staleAfterRefresh;
    }

    reset(jsonPath);
    return VectorClockDecision.accept;
  }

  void reset(String jsonPath) {
    _staleDescriptorFailures.remove(jsonPath);
  }
}
