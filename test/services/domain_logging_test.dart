import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

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
    registerFallbackValue(StackTrace.empty);
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

  group('LogDomain', () {
    test('wireName equals the enum name', () {
      expect(LogDomain.agentRuntime.wireName, 'agentRuntime');
      expect(LogDomain.sync.wireName, 'sync');
    });

    test('only sync routes to the shared sync file and defaults off', () {
      for (final domain in LogDomain.values) {
        expect(
          domain.routesToSyncFile,
          domain == LogDomain.sync,
          reason: '${domain.name} routesToSyncFile',
        );
        expect(
          domain.defaultEnabled,
          domain != LogDomain.sync,
          reason: '${domain.name} defaultEnabled',
        );
      }
    });

    test('every domain has a log_ flag name and a non-empty label', () {
      for (final domain in LogDomain.values) {
        expect(domain.flagName, startsWith('log_'), reason: domain.name);
        expect(domain.label.trim(), isNotEmpty, reason: domain.name);
      }
    });

    test('historical flag names are preserved', () {
      expect(LogDomain.sync.flagName, 'log_sync');
      expect(LogDomain.agentRuntime.flagName, 'log_agent_runtime');
      expect(LogDomain.agentWorkflow.flagName, 'log_agent_workflow');
    });
  });

  group('DomainLogger error description builders', () {
    test('full description includes the raw error and message', () {
      final exception = Exception('secret user content');
      expect(
        DomainLogger.fullErrorDescription(exception, 'wake failed'),
        'wake failed: Exception: secret user content',
      );
      expect(
        DomainLogger.fullErrorDescription(exception, null),
        'Exception: secret user content',
      );
    });

    test(
      'safe description records only the error type, never the raw text',
      () {
        final exception = Exception('secret user content');
        final safe = DomainLogger.safeErrorDescription(
          exception,
          'wake failed',
        );
        expect(safe, contains('wake failed'));
        expect(safe, contains('errorType='));
        expect(safe, isNot(contains('secret user content')));

        expect(
          DomainLogger.safeErrorDescription(exception, null),
          isNot(contains('secret user content')),
        );
      },
    );
  });

  group('DomainLogger.log', () {
    late MockLoggingService mockLoggingService;
    late DomainLogger logger;

    setUp(() {
      mockLoggingService = MockLoggingService();
      stubLoggingService(mockLoggingService);
      logger = DomainLogger(loggingService: mockLoggingService);
    });

    test('delegates to LoggingService when domain is enabled', () {
      logger.enabledDomains.add(LogDomain.agentRuntime);

      logger.log(LogDomain.agentRuntime, 'test message');

      verify(
        () => mockLoggingService.captureEvent(
          'test message',
          domain: 'agentRuntime',
        ),
      ).called(1);
    });

    test('is a no-op when domain is not enabled', () {
      logger.log(LogDomain.agentRuntime, 'should not log');

      verifyNever(
        () => mockLoggingService.captureEvent(
          any<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          level: any(named: 'level'),
          type: any(named: 'type'),
        ),
      );
    });

    test('isEnabled / setEnabledDomains reflect the enabled set', () {
      expect(logger.isEnabled(LogDomain.ai), isFalse);
      logger.setEnabledDomains([LogDomain.ai, LogDomain.chat]);
      expect(logger.isEnabled(LogDomain.ai), isTrue);
      expect(logger.isEnabled(LogDomain.chat), isTrue);
      expect(logger.isEnabled(LogDomain.sync), isFalse);
      logger.setEnabledDomains(const []);
      expect(logger.enabledDomains, isEmpty);
    });

    test('passes subDomain and level through', () {
      logger.enabledDomains.add(LogDomain.agentWorkflow);

      logger.log(
        LogDomain.agentWorkflow,
        'wake started',
        subDomain: 'execute',
        level: InsightLevel.warn,
      );

      verify(
        () => mockLoggingService.captureEvent(
          'wake started',
          domain: 'agentWorkflow',
          subDomain: 'execute',
          level: InsightLevel.warn,
        ),
      ).called(1);
    });

    test('only enabled domains pass through', () {
      logger.enabledDomains.add(LogDomain.agentRuntime);

      logger
        ..log(LogDomain.agentWorkflow, 'disabled domain')
        ..log(LogDomain.agentRuntime, 'enabled domain');

      verify(
        () => mockLoggingService.captureEvent(
          'enabled domain',
          domain: 'agentRuntime',
        ),
      ).called(1);
      verifyNever(
        () => mockLoggingService.captureEvent(
          'disabled domain',
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          level: any(named: 'level'),
        ),
      );
    });
  });

  group('DomainLogger.error', () {
    late MockLoggingService mockLoggingService;
    late DomainLogger logger;

    setUp(() {
      mockLoggingService = MockLoggingService();
      stubLoggingService(mockLoggingService);
      logger = DomainLogger(loggingService: mockLoggingService);
    });

    test('always logs regardless of enabledDomains', () {
      logger.error(LogDomain.agentRuntime, 'something broke');

      verify(
        () => mockLoggingService.captureException(
          'something broke',
          domain: 'agentRuntime',
        ),
      ).called(1);
    });

    test('combines message and full error for the full error log', () {
      final exception = Exception('boom');
      logger.error(
        LogDomain.agentRuntime,
        exception,
        message: 'wake failed',
      );

      verify(
        () => mockLoggingService.captureException(
          'wake failed: Exception: boom',
          domain: 'agentRuntime',
        ),
      ).called(1);
    });

    test('passes stackTrace and subDomain through', () {
      final stackTrace = StackTrace.current;
      logger.error(
        LogDomain.agentWorkflow,
        'execution error',
        stackTrace: stackTrace,
        subDomain: 'execute',
      );

      verify(
        () => mockLoggingService.captureException(
          'execution error',
          domain: 'agentWorkflow',
          subDomain: 'execute',
          stackTrace: stackTrace,
        ),
      ).called(1);
    });
  });
}
