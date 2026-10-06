import 'package:lotti/services/domain_logging.dart';

/// A sink for content-free workflow errors, shaped like
/// [AgentErrorLogging.logError] so collaborators can take either.
typedef LogErrorCallback =
    void Function(String message, {Object? error, StackTrace? stackTrace});

/// Shared structured error and progress logging for the agent runtime and
/// workflow classes.
///
/// One implementation instead of a copy per class, so a fix lands everywhere.
/// The adopting class supplies the logger and the [LogDomain] its failures
/// belong to.
mixin AgentErrorLogging {
  /// The structured logger.
  ///
  /// Every adopting class exposes this as a required, injected field; the
  /// mixin only requires that it be readable.
  DomainLogger get domainLogger;

  /// Which logging domain this class's failures belong to.
  ///
  /// `agentRuntime` for the wake machinery, `agentWorkflow` for the workflows.
  LogDomain get errorLogDomain;

  /// Reports a progress [message] under [errorLogDomain]; gated by that
  /// domain's logging flag like any [DomainLogger.log] line.
  void logInfo(String message, {String? subDomain}) {
    domainLogger.log(errorLogDomain, message, subDomain: subDomain);
  }

  /// Reports [message], optionally caused by [error], to the structured
  /// logger under [errorLogDomain]. Errors are always logged.
  ///
  /// When [error] is present it becomes the logged object and [message] the
  /// accompanying context; with no [error], [message] *is* the logged object,
  /// so the log row never has an empty subject.
  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    domainLogger.error(
      errorLogDomain,
      error ?? message,
      message: error != null ? message : null,
      stackTrace: stackTrace,
    );
  }
}
