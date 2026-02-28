import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  setUpAll(() {
    registerFallbackValue(InsightLevel.info);
    registerFallbackValue(InsightType.log);
  });

  group('DomainLogger.sanitizeId', () {
    test('replaces full UUID with first 6 characters', () {
      expect(
        DomainLogger.sanitizeId('a1b2c3d4-e5f6-7890-abcd-ef1234567890'),
        '[id:a1b2c3]',
      );
    });

    test('handles short IDs gracefully', () {
      expect(DomainLogger.sanitizeId('abc'), '[id:abc]');
    });

    test('handles empty string', () {
      expect(DomainLogger.sanitizeId(''), '[id:]');
    });

    test('handles exactly 6-character ID', () {
      expect(DomainLogger.sanitizeId('abcdef'), '[id:abcdef]');
    });
  });

  group('DomainLogger.sanitizeContent', () {
    test('replaces content with length placeholder', () {
      expect(
        DomainLogger.sanitizeContent('Hello world, this is a secret'),
        '[content: 29 chars]',
      );
    });

    test('handles empty content', () {
      expect(DomainLogger.sanitizeContent(''), '[content: 0 chars]');
    });

    test('handles multi-line content', () {
      const content = 'line 1\nline 2\nline 3';
      expect(
        DomainLogger.sanitizeContent(content),
        '[content: ${content.length} chars]',
      );
    });
  });

  group('DomainLogger.log', () {
    late MockLoggingService mockLoggingService;
    late DomainLogger logger;

    setUp(() {
      mockLoggingService = MockLoggingService();
      logger = DomainLogger(loggingService: mockLoggingService);
    });

    test('delegates to LoggingService when domain is enabled', () {
      logger.enabledDomains.add(LogDomains.agentRuntime);

      logger.log(LogDomains.agentRuntime, 'test message');

      verify(
        () => mockLoggingService.captureEvent(
          'test message',
          domain: LogDomains.agentRuntime,
        ),
      ).called(1);
    });

    test('is a no-op when domain is not enabled', () {
      logger.log(LogDomains.agentRuntime, 'should not log');

      verifyZeroInteractions(mockLoggingService);
    });

    test('passes subDomain and level through', () {
      logger.enabledDomains.add(LogDomains.agentWorkflow);

      logger.log(
        LogDomains.agentWorkflow,
        'wake started',
        subDomain: 'execute',
        level: InsightLevel.trace,
      );

      verify(
        () => mockLoggingService.captureEvent(
          'wake started',
          domain: LogDomains.agentWorkflow,
          subDomain: 'execute',
          level: InsightLevel.trace,
        ),
      ).called(1);
    });

    test('only enabled domains pass through', () {
      logger.enabledDomains.add(LogDomains.agentRuntime);

      logger
        ..log(LogDomains.agentWorkflow, 'disabled domain')
        ..log(LogDomains.agentRuntime, 'enabled domain');

      verify(
        () => mockLoggingService.captureEvent(
          'enabled domain',
          domain: LogDomains.agentRuntime,
        ),
      ).called(1);
      verifyNoMoreInteractions(mockLoggingService);
    });
  });

  group('DomainLogger.error', () {
    late MockLoggingService mockLoggingService;
    late DomainLogger logger;

    setUp(() {
      mockLoggingService = MockLoggingService();
      logger = DomainLogger(loggingService: mockLoggingService);
    });

    test('always logs regardless of enabledDomains', () {
      logger.error(LogDomains.agentRuntime, 'something broke');

      verify(
        () => mockLoggingService.captureException(
          'something broke',
          domain: LogDomains.agentRuntime,
        ),
      ).called(1);
    });

    test('includes error object in message', () {
      final exception = Exception('test error');
      logger.error(
        LogDomains.agentRuntime,
        'wake failed',
        error: exception,
      );

      verify(
        () => mockLoggingService.captureException(
          'wake failed: $exception',
          domain: LogDomains.agentRuntime,
        ),
      ).called(1);
    });

    test('passes stackTrace and subDomain through', () {
      final stackTrace = StackTrace.current;
      logger.error(
        LogDomains.agentWorkflow,
        'execution error',
        stackTrace: stackTrace,
        subDomain: 'execute',
      );

      verify(
        () => mockLoggingService.captureException(
          'execution error',
          domain: LogDomains.agentWorkflow,
          subDomain: 'execute',
          stackTrace: stackTrace,
        ),
      ).called(1);
    });
  });
}
