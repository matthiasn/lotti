import 'dart:developer' as developer;

import 'package:lotti/services/domain_logging.dart';

/// Structured-with-fallback error logging for the agent runtime and workflow
/// classes.
///
/// Seven classes across `wake/`, `workflow/` and `service/` carried a
/// byte-identical copy of this method, differing only in the [LogDomain] and the
/// `developer.log` source name. A copy per class means a fix to one leaves the
/// other six behind, which is the only reason this mixin exists — the behaviour
/// is exactly what those copies did.
///
/// Deliberately **not** adopted by `DayAgentWorkflow`: its logger is
/// non-nullable and it has no fallback branch at all, so folding it in here
/// would add an unreachable-but-real code path to it. That contract difference
/// is intentional, not an eighth copy left behind.
mixin AgentErrorLogging {
  /// The structured logger, when one was injected.
  ///
  /// Every adopting class already exposes this as a field; the mixin only
  /// requires that it be readable.
  DomainLogger? get domainLogger;

  /// Which logging domain this class's failures belong to.
  ///
  /// `agentRuntime` for the wake machinery, `agentWorkflow` for the workflows.
  LogDomain get errorLogDomain;

  /// The `developer.log` source name used by the fallback path.
  ///
  /// Derived from the concrete type rather than restated per class, so renaming
  /// a class cannot leave its diagnostics naming a class that no longer exists.
  /// This yields the same strings the hand-written copies hard-coded, because
  /// nothing in this repository's build configuration passes `--obfuscate`.
  /// Override it if a class ever needs a name that is not its own.
  String get errorLogName => '$runtimeType';

  /// Reports [message], optionally caused by [error], to the structured logger —
  /// or to `developer.log` when no logger was injected.
  ///
  /// When [error] is present it becomes the logged object and [message] the
  /// accompanying context; with no [error], [message] *is* the logged object.
  /// That asymmetry is what the original copies did and what the log surfaces
  /// expect.
  ///
  /// The fallback path passes only `error.runtimeType`, never the error itself:
  /// these paths carry journal content, which must not reach a developer
  /// console verbatim.
  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    final logger = domainLogger;
    if (logger != null) {
      logger.error(
        errorLogDomain,
        error ?? message,
        message: error != null ? message : null,
        stackTrace: stackTrace,
      );
    } else {
      developer.log(
        '$message${error != null ? ' (errorType=${error.runtimeType})' : ''}',
        name: errorLogName,
        error: error?.runtimeType,
        stackTrace: stackTrace,
      );
    }
  }
}
