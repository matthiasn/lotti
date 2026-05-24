import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {
  MockLoggingService() {
    when(
      () => captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
        type: any(named: 'type'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
  }
}

class _GeneratedId {
  const _GeneratedId({
    required this.length,
    required this.seed,
  });

  final int length;
  final int seed;

  String get value => String.fromCharCodes(
    List.generate(length, (index) => 33 + ((seed + index * 31) % 94)),
  );

  @override
  String toString() => '_GeneratedId(length: $length, seed: $seed)';
}

extension _AnyGeneratedId on glados.Any {
  glados.Generator<_GeneratedId> get generatedId =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 64),
        glados.IntAnys(this).intInRange(0, 10000),
        (int length, int seed) => _GeneratedId(
          length: length,
          seed: seed,
        ),
      );
}

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

    glados.Glados(
      glados.any.generatedId,
      glados.ExploreConfig(numRuns: 80),
    ).test('emits only the first six ID characters', (generated) {
      final id = generated.value;
      final sanitized = DomainLogger.sanitizeId(id);
      final expectedVisibleLength = id.length < 6 ? id.length : 6;

      expect(sanitized, startsWith('[id:'), reason: '$generated');
      expect(sanitized, endsWith(']'), reason: '$generated');
      expect(
        sanitized.substring(4, sanitized.length - 1),
        id.substring(0, expectedVisibleLength),
        reason: '$generated',
      );
    }, tags: 'glados');
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
        level: InsightLevel.warn,
      );

      verify(
        () => mockLoggingService.captureEvent(
          'wake started',
          domain: LogDomains.agentWorkflow,
          subDomain: 'execute',
          level: InsightLevel.warn,
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

    test('includes error type without raw exception message', () {
      final exception = Exception('secret user content');
      logger.error(
        LogDomains.agentRuntime,
        'wake failed',
        error: exception,
      );

      verify(
        () => mockLoggingService.captureException(
          any<String>(
            that: allOf(
              contains('wake failed'),
              contains('errorType='),
              isNot(contains('secret user content')),
            ),
          ),
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
