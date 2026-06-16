import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';

/// Outcome of validating a downloaded descriptor's vector clock against the
/// clock the timeline announced: [accept] it, [retryAfterPurge] (cache served
/// a stale copy — purge and re-download), [staleAfterRefresh] (still stale on a
/// later attempt), [circuitBreaker] (too many stale hits for this path — give
/// up), or [missingVectorClock] (the candidate carries no clock to compare).
enum VectorClockDecision {
  accept,
  retryAfterPurge,
  staleAfterRefresh,
  circuitBreaker,
  missingVectorClock,
}

/// Decides whether a freshly downloaded descriptor is current enough to apply,
/// based on its vector clock versus the clock the timeline signalled.
///
/// Tracks consecutive stale hits per `jsonPath` and trips a circuit breaker at
/// [maxStaleDescriptorFailures] so a permanently-behind cache cannot loop the
/// downloader forever. State is keyed by path and cleared by [reset] (and on an
/// accept), so unrelated descriptors do not share a failure budget.
class VectorClockValidator {
  VectorClockValidator({required DomainLogger loggingService})
    : _logging = loggingService;

  static const int maxStaleDescriptorFailures = 5;

  final DomainLogger _logging;
  final Map<String, int> _staleDescriptorFailures = <String, int>{};

  /// Classifies the [candidate] descriptor for [jsonPath] by comparing its
  /// vector clock with [incomingVectorClock]. A clock that dominates the
  /// expected one is accepted; a strictly-older clock counts as a stale hit and
  /// returns a retry/breaker decision depending on [attempt] and the running
  /// failure count for this path.
  VectorClockDecision evaluate({
    required String jsonPath,
    required VectorClock incomingVectorClock,
    required JournalEntity candidate,
    required int attempt,
  }) {
    final candidateVc = candidate.meta.vectorClock;
    if (candidateVc == null) {
      _logging.log(
        LogDomain.sync,
        'smart.fetch.missing_vc path=$jsonPath expected=$incomingVectorClock',
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
        _logging.log(
          LogDomain.sync,
          'smart.fetch.stale_vc.breaker path=$jsonPath retries=$failures limit=$maxStaleDescriptorFailures',
          subDomain: 'SmartLoader.fetch',
        );
        return VectorClockDecision.circuitBreaker;
      }
      if (attempt == 0) {
        _logging.log(
          LogDomain.sync,
          'smart.fetch.stale_vc path=$jsonPath expected=$incomingVectorClock got=$candidateVc',
          subDomain: 'SmartLoader.fetch',
        );
        return VectorClockDecision.retryAfterPurge;
      }
      _logging.log(
        LogDomain.sync,
        'smart.fetch.stale_vc.pending path=$jsonPath expected=$incomingVectorClock got=$candidateVc',
        subDomain: 'SmartLoader.fetch',
      );
      return VectorClockDecision.staleAfterRefresh;
    }

    reset(jsonPath);
    return VectorClockDecision.accept;
  }

  /// Clears the stale-hit counter for [jsonPath] (called on accept, on a
  /// missing clock, and by the downloader after a successful round-trip).
  void reset(String jsonPath) {
    _staleDescriptorFailures.remove(jsonPath);
  }
}
