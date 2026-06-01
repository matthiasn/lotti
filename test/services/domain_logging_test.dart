import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart' as platform_utils;
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

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

  // ---------------------------------------------------------------------------
  // _writeLine — non-test-env file-sink path (covers lines 36, 185-197)
  // ---------------------------------------------------------------------------
  group('DomainLogger file sink (non-test-env)', () {
    late Directory tempDocs;
    late MockLoggingService mockLoggingService;
    late DomainLogger logger;

    File? findLogFile(String prefix) {
      final logDir = Directory(p.join(tempDocs.path, 'logs'));
      if (!logDir.existsSync()) return null;
      final matches = logDir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith(prefix))
          .toList();
      return matches.isEmpty ? null : matches.first;
    }

    setUp(() async {
      platform_utils.isTestEnv = false;
      tempDocs = Directory.systemTemp.createTempSync('domain_log_sink_test_');
      addTearDown(() {
        platform_utils.isTestEnv = true;
        if (tempDocs.existsSync()) {
          tempDocs.deleteSync(recursive: true);
        }
      });

      await getIt.reset();
      getIt.registerSingleton<Directory>(tempDocs);

      mockLoggingService = MockLoggingService();
      stubLoggingService(mockLoggingService);
      logger = DomainLogger(loggingService: mockLoggingService);
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('log writes message to domain log file when domain is enabled', () {
      logger.enabledDomains.add(LogDomain.agentRuntime);

      logger.log(LogDomain.agentRuntime, 'file sink message');

      final logFile = findLogFile('agentRuntime-');
      expect(
        logFile,
        isNotNull,
        reason: 'Domain log file should have been created',
      );
      final content = logFile!.readAsStringSync();
      expect(content, contains('[INFO]'));
      expect(content, contains('file sink message'));
    });

    test('log writes subDomain and custom level to domain log file', () {
      logger.enabledDomains.add(LogDomain.agentWorkflow);

      logger.log(
        LogDomain.agentWorkflow,
        'sub-domain log',
        subDomain: 'step-1',
        level: InsightLevel.warn,
      );

      final logFile = findLogFile('agentWorkflow-');
      expect(
        logFile,
        isNotNull,
        reason: 'Domain log file should have been created',
      );
      final content = logFile!.readAsStringSync();
      expect(content, contains('[WARN]'));
      expect(content, contains('step-1'));
      expect(content, contains('sub-domain log'));
    });

    test('error writes full description to domain log file', () {
      final exception = Exception('disk full');
      logger.error(
        LogDomain.agentRuntime,
        exception,
        message: 'write failed',
      );

      final domainFile = findLogFile('agentRuntime-');
      expect(
        domainFile,
        isNotNull,
        reason: 'Domain error log file should have been created',
      );
      final content = domainFile!.readAsStringSync();
      expect(content, contains('[ERROR]'));
      expect(content, contains('write failed'));
      expect(content, contains('disk full'));
    });

    test('error appends stackTrace lines to domain log file', () {
      final stackTrace = StackTrace.fromString(
        '#0  fake_frame (package:lotti/fake.dart:1:1)',
      );
      logger.error(
        LogDomain.agentRuntime,
        'stack error',
        stackTrace: stackTrace,
      );

      final logFile = findLogFile('agentRuntime-');
      expect(logFile, isNotNull);
      final content = logFile!.readAsStringSync();
      expect(content, contains('stack error'));
      expect(content, contains('fake_frame'));
    });

    test('error writes PII-safe line to error-safe log file', () {
      final exception = Exception('secret user content');
      logger.error(
        LogDomain.agentRuntime,
        exception,
        message: 'load failed',
      );

      final safeFile = findLogFile('error-safe-');
      expect(
        safeFile,
        isNotNull,
        reason: 'PII-safe error log file should have been created',
      );
      final content = safeFile!.readAsStringSync();
      expect(content, contains('[ERROR]'));
      expect(content, contains('agentRuntime'));
      expect(content, contains('load failed'));
      expect(content, contains('errorType='));
      expect(content, isNot(contains('secret user content')));
    });

    test('error for sync domain skips domain log file but writes safe log', () {
      logger.error(
        LogDomain.sync,
        'sync error',
      );

      // sync domain routes to the shared sync file, not a domain log file
      final domainFile = findLogFile('sync-');
      // There is no per-domain file written for sync (routesToSyncFile == true)
      // The PII-safe log should still be created.
      final safeFile = findLogFile('error-safe-');
      expect(safeFile, isNotNull, reason: 'PII-safe error log always written');
      final safeContent = safeFile!.readAsStringSync();
      expect(safeContent, contains('sync'));
      // domain log file should not exist (no _appendToDomainFile call for sync)
      expect(domainFile, isNull, reason: 'sync domain skips per-domain file');
    });

    test('_writeLine swallows file-sink errors gracefully', () {
      // Point getIt at a path that cannot be created (a file used as dir).
      File(p.join(tempDocs.path, 'logs')).createSync();

      // The log call must not throw even though log directory cannot be created.
      expect(
        () {
          logger.enabledDomains.add(LogDomain.agentRuntime);
          logger.log(LogDomain.agentRuntime, 'should not throw');
        },
        returnsNormally,
      );
    });
  });
}
