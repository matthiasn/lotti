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

/// A workflow-shaped adopter: `agentWorkflow` domain.
class _Workflow with AgentErrorLogging {
  _Workflow(this.domainLogger);

  @override
  final DomainLogger domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentWorkflow;
}

/// A runtime-shaped adopter, to prove the domain is per-class and not baked in.
class _Runtime with AgentErrorLogging {
  _Runtime(this.domainLogger);

  @override
  final DomainLogger domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentRuntime;
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

  group('logError', () {
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

  group('logInfo', () {
    setUp(() {
      when(
        () => logger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
    });

    test('logs to the domain the adopting class declares', () {
      _Workflow(logger).logInfo('resolved template', subDomain: 'resolve');
      _Runtime(logger).logInfo('wake queued');

      verify(
        () => logger.log(
          LogDomain.agentWorkflow,
          'resolved template',
          subDomain: 'resolve',
        ),
      ).called(1);
      verify(
        () =>
            logger.log(LogDomain.agentRuntime, 'wake queued', subDomain: null),
      ).called(1);
      verifyNever(
        () => logger.error(
          any<LogDomain>(),
          any<Object>(),
          message: any<String?>(named: 'message'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      );
    });
  });
}
