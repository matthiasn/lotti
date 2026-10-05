import 'dart:async';

/// One service or database that did not dispose cleanly: it threw, or it did
/// not finish within its deadline (a [TimeoutException]).
class ServiceDisposalFailure {
  const ServiceDisposalFailure({
    required this.service,
    required this.error,
    required this.stackTrace,
  });

  /// The registration that failed, e.g. `JournalDb`.
  final String service;
  final Object error;
  final StackTrace stackTrace;

  @override
  String toString() => '$service: $error';
}

/// Logs one service that failed to dispose, named by [service].
typedef DisposalErrorLogger =
    void Function(dynamic error, StackTrace stackTrace, String service);
