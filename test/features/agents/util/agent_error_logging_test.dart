// The explicit `message: null` / `stackTrace: null` / `errorSummary: null`
// arguments below sit inside `verify(...)` calls, where passing the default
// explicitly *is* the assertion — the point is that the mixin forwarded null
// rather than fabricating a value.
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// A workflow-shaped adopter: nullable logger, `agentWorkflow` domain.
class _Workflow with AgentErrorLogging {
  _Workflow(this.domainLogger);

  @override
  final DomainLogger? domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentWorkflow;
}

/// A runtime-shaped adopter, to prove the domain is per-class and not baked in.
class _Runtime with AgentErrorLogging {
  _Runtime(this.domainLogger);

  @override
  final DomainLogger? domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentRuntime;
}

/// An adopter that overrides the derived name.
class _Renamed with AgentErrorLogging {
  _Renamed(this.domainLogger);

  @override
  final DomainLogger? domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentRuntime;

  @override
  String get errorLogName => 'CustomName';
}

void main() {
  late MockDomainLogger logger;

  setUp(() {
    logger = MockDomainLogger();
    when(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        message: any<String?>(named: 'message'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) {});
  });

  group('with a structured logger', () {
    test('logs the error as the subject and the message as context', () {
      // The asymmetry matters to the log surfaces: when there is a cause, the
      // cause is the logged object and the human sentence is metadata.
      final error = StateError('boom');
      final trace = StackTrace.current;

      _Workflow(
        logger,
      ).logError('wake failed', error: error, stackTrace: trace);

      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          error,
          message: 'wake failed',
          stackTrace: trace,
        ),
      ).called(1);
    });

    test('logs the message as the subject when there is no cause', () {
      // With no error, the sentence *is* the subject and `message` stays null —
      // otherwise the log row would have an empty subject.
      _Workflow(logger).logError('nothing to do');

      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          'nothing to do',
          message: null,
          stackTrace: null,
        ),
      ).called(1);
    });

    test('routes to the domain the adopting class declares', () {
      _Runtime(logger).logError('scan failed');

      verify(
        () => logger.error(
          LogDomain.agentRuntime,
          'scan failed',
          message: null,
          stackTrace: null,
        ),
      ).called(1);
    });

    test('forwards a null stack trace rather than fabricating one', () {
      final error = StateError('boom');

      _Workflow(logger).logError('wake failed', error: error);

      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          error,
          message: 'wake failed',
          stackTrace: null,
        ),
      ).called(1);
    });
  });

  group('without a structured logger', () {
    // The fallback writes to `developer.log`, whose output is not observable
    // from a test binding. These assert the reachable contract — that the
    // fallback is taken silently and cannot throw — rather than pretending to
    // verify the console text.
    test('does not touch the logger and completes', () {
      expect(
        () => _Workflow(null).logError('wake failed', error: StateError('x')),
        returnsNormally,
      );
      verifyNever(
        () => logger.error(
          any<LogDomain>(),
          any<Object>(),
          message: any<String?>(named: 'message'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      );
    });

    test('completes with no cause and no stack trace', () {
      expect(() => _Runtime(null).logError('idle'), returnsNormally);
    });
  });

  group('errorLogName', () {
    test('defaults to the concrete type, so a rename cannot leave it stale', () {
      // This is why the name is derived rather than restated per class: the
      // seven hand-written copies each hard-coded a string that a rename would
      // silently orphan.
      expect(_Workflow(logger).errorLogName, '_Workflow');
      expect(_Runtime(logger).errorLogName, '_Runtime');
    });

    test('is overridable when a class needs a name that is not its own', () {
      expect(_Renamed(logger).errorLogName, 'CustomName');
    });
  });
}
