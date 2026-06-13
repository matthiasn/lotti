import 'package:lotti/services/domain_logging.dart';

/// Routes sync-sequence trace lines into the `sync` log domain.
///
/// Shared by every sync-sequence collaborator so the file-routing behaviour
/// (sequence sub-domains land in the sync file) is defined in exactly one
/// place. When a [DomainLogger] is injected it is preferred; otherwise the
/// general logging service is used directly so tests that omit the domain
/// logger still land their lines under the `sync` domain.
class SyncSequenceTracer {
  SyncSequenceTracer({
    required this._loggingService,
    this._domainLogger,
  });

  final DomainLogger _loggingService;
  final DomainLogger? _domainLogger;

  void trace(String message, {String? subDomain}) {
    final sub = subDomain ?? 'sequence';
    final domainLogger = _domainLogger;
    if (domainLogger != null) {
      domainLogger.log(LogDomain.sync, message, subDomain: sub);
      return;
    }
    // Fallback for callers that did not inject a DomainLogger (e.g. tests).
    // Emitting directly under the `sync` domain keeps sync-file routing in
    // DomainLogger working so the log line still lands in the sync file.
    _loggingService.log(
      LogDomain.sync,
      message,
      subDomain: sub,
    );
  }

  void error(
    Object error,
    StackTrace stackTrace, {
    required String subDomain,
  }) {
    _loggingService.error(
      LogDomain.sync,
      error,
      stackTrace: stackTrace,
      subDomain: subDomain,
    );
  }
}
