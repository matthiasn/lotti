import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/platform.dart' as platform_utils;
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../mocks/mocks.dart';
import '../widget_test_utils.dart';

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

  group('DomainLogger.withoutSource', () {
    test('drops the source a jsonDecode failure quotes, keeping the rest', () {
      Object? caught;
      try {
        jsonDecode('{"title": "secret title" "x": 1}');
      } on FormatException catch (e) {
        caught = e;
      }
      final original = caught! as FormatException;
      expect(original.toString(), contains('secret title'));

      final stripped = DomainLogger.withoutSource(original) as FormatException;
      expect(stripped.source, isNull);
      expect(stripped.message, original.message);
      expect(stripped.offset, original.offset);
      expect(stripped.toString(), isNot(contains('secret title')));
    });

    test('returns any other error unchanged', () {
      final error = StateError('boom');
      expect(DomainLogger.withoutSource(error), same(error));
    });
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

  group('DomainLogger.listenToDomainFlags', () {
    late DomainLogger logger;
    late Map<String, StreamController<bool>> flags;

    Stream<bool> watchFlag(String flagName) => flags[flagName]!.stream;

    setUp(() {
      logger = DomainLogger(loggingService: MockLoggingService());
      flags = {
        for (final domain in LogDomain.values)
          domain.flagName: StreamController<bool>.broadcast(sync: true),
      };
    });
    tearDown(() async {
      await logger.dispose();
      for (final controller in flags.values) {
        await controller.close();
      }
    });

    test('each domain follows its own flag, on and off', () async {
      await logger.listenToDomainFlags(watchFlag);
      expect(logger.enabledDomains, isEmpty);

      flags[LogDomain.agentRuntime.flagName]!.add(true);
      flags[LogDomain.sync.flagName]!.add(true);
      flags[LogDomain.agentWorkflow.flagName]!.add(false);
      expect(logger.enabledDomains, {LogDomain.agentRuntime, LogDomain.sync});

      flags[LogDomain.agentRuntime.flagName]!.add(false);
      expect(logger.enabledDomains, {LogDomain.sync});
    });

    test('a repeat call replaces the previous subscriptions', () async {
      await logger.listenToDomainFlags(watchFlag);
      final previous = flags;
      flags = {
        for (final domain in LogDomain.values)
          domain.flagName: StreamController<bool>.broadcast(sync: true),
      };
      addTearDown(() async {
        for (final controller in previous.values) {
          await controller.close();
        }
      });

      await logger.listenToDomainFlags(watchFlag);

      expect(previous.values.any((c) => c.hasListener), isFalse);
      previous[LogDomain.sync.flagName]!.add(true);
      expect(logger.enabledDomains, isEmpty);
      flags[LogDomain.sync.flagName]!.add(true);
      expect(logger.enabledDomains, {LogDomain.sync});
    });

    test('dispose stops following the flags', () async {
      await logger.listenToDomainFlags(watchFlag);
      await logger.dispose();

      expect(flags.values.any((c) => c.hasListener), isFalse);
    });

    test('a flag stream that errors leaves its domain as it was', () async {
      await logger.listenToDomainFlags(watchFlag);
      flags[LogDomain.ai.flagName]!
        ..add(true)
        ..addError(StateError('db closed'));

      expect(logger.enabledDomains, {LogDomain.ai});
    });
  });

  group('DomainLogger.logSampled', () {
    late MockLoggingService mockLoggingService;
    late DomainLogger logger;
    late DateTime now;

    setUp(() {
      mockLoggingService = MockLoggingService();
      stubLoggingService(mockLoggingService);
      logger = DomainLogger(loggingService: mockLoggingService)
        ..enabledDomains.add(LogDomain.sync);
      now = DateTime.utc(2026, 8);
    });

    test('emits the first event and a counted threshold summary', () {
      withClock(Clock(() => now), () {
        for (var i = 0; i < 4; i++) {
          logger.logSampled(
            LogDomain.sync,
            'hot operation index=$i',
            sampleKey: 'sync.hot.operation',
            subDomain: 'hot',
            every: 3,
          );
        }
      });

      final messages = verify(
        () => mockLoggingService.captureEvent(
          captureAny<Object>(),
          domain: 'sync',
          subDomain: 'hot',
        ),
      ).captured.cast<String>();
      expect(messages, hasLength(2));
      expect(messages.first, contains('observed=1 suppressed=0 total=1'));
      expect(messages.last, contains('observed=3 suppressed=2 total=4'));
    });

    test('emits pending observations after the maximum interval', () {
      withClock(Clock(() => now), () {
        logger.logSampled(
          LogDomain.sync,
          'first',
          sampleKey: 'sync.interval',
        );
        now = now.add(const Duration(minutes: 6));
        logger.logSampled(
          LogDomain.sync,
          'next',
          sampleKey: 'sync.interval',
        );
      });

      final messages = verify(
        () => mockLoggingService.captureEvent(
          captureAny<Object>(),
          domain: 'sync',
        ),
      ).captured.cast<String>();
      expect(messages, hasLength(2));
      expect(messages.last, contains('observed=1 suppressed=0 total=2'));
    });

    test('bounds the per-key sample state, forgetting the least recently '
        'used key so it starts a fresh count', () {
      withClock(Clock(() => now), () {
        void sample(String key) => logger.logSampled(
          LogDomain.sync,
          'op',
          sampleKey: key,
          subDomain: 'bounded',
        );

        sample('key-0');
        sample('key-0'); // Suppressed: total=2 for a tracked key.
        // 256 other keys push key-0 past the state capacity.
        for (var i = 1; i <= 256; i++) {
          sample('key-$i');
        }
        // key-0 was evicted, so it is treated as a first observation again.
        sample('key-0');
      });

      final messages = verify(
        () => mockLoggingService.captureEvent(
          captureAny<Object>(),
          domain: 'sync',
          subDomain: 'bounded',
        ),
      ).captured.cast<String>();
      final key0 = messages
          .where((m) => m.contains('sampleKey=key-0 '))
          .toList();
      expect(key0, hasLength(2));
      expect(key0.last, contains('observed=1 suppressed=0 total=1'));
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
      logger.errorWithDiagnostics(
        LogDomain.agentRuntime,
        exception,
        message: 'wake failed',
        diagnostics: 'widget: SettingsPage',
      );

      verify(
        () => mockLoggingService.captureException(
          'wake failed: Exception: boom\nwidget: SettingsPage',
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

  group('DomainLogger.error stack-trace repeats', () {
    late MockLoggingService mockLoggingService;
    late DomainLogger logger;
    late DateTime now;
    final trace = StackTrace.fromString('#0  retry (package:lotti/x.dart:1)');

    setUp(() {
      mockLoggingService = MockLoggingService();
      stubLoggingService(mockLoggingService);
      logger = DomainLogger(loggingService: mockLoggingService);
      now = DateTime(2026, 10, 2, 10);
    });

    void logAt(
      DateTime at, {
      Object error = 'M_NOT_FOUND',
      String? subDomain = 'descriptorFetch',
      StackTrace? stackTrace,
    }) {
      withClock(Clock.fixed(at), () {
        logger.error(
          LogDomain.sync,
          error,
          subDomain: subDomain,
          stackTrace: stackTrace ?? trace,
        );
      });
    }

    List<(String, Object?)> captured() {
      final values = verify(
        () => mockLoggingService.captureException(
          captureAny<Object>(),
          domain: 'sync',
          subDomain: any(named: 'subDomain'),
          stackTrace: captureAny<Object?>(named: 'stackTrace'),
        ),
      ).captured;
      return [
        for (var i = 0; i < values.length; i += 2)
          (values[i] as String, values[i + 1]),
      ];
    }

    test('an identical repeat keeps its line but omits the trace', () {
      logAt(now);
      logAt(now.add(const Duration(seconds: 30)));
      logAt(now.add(const Duration(minutes: 1)));

      final calls = captured();
      expect(calls[0], ('M_NOT_FOUND', trace));
      expect(calls[1], (
        'M_NOT_FOUND [stack trace omitted: repeat 1 of the trace logged at '
            '2026-10-02T10:00:00.000]',
        null,
      ));
      expect(calls[2].$1, contains('repeat 2 of the trace logged at'));
      expect(calls[2].$2, isNull);
    });

    test('distinct errors, subDomains and stacks each log their trace', () {
      final otherTrace = StackTrace.fromString('#0  other (package:lotti/y:1)');
      logAt(now);
      logAt(now, error: 'M_LIMIT_EXCEEDED');
      logAt(now, subDomain: 'queue.apply');
      logAt(now, stackTrace: otherTrace);

      final calls = captured();
      expect(calls.map((c) => c.$2), [trace, trace, trace, otherTrace]);
      expect(calls.map((c) => c.$1), everyElement(isNot(contains('omitted'))));
    });

    test('the trace is logged again once the repeat window has passed', () {
      logAt(now);
      logAt(
        now
            .add(DomainLogger.errorTraceRepeatWindow)
            .subtract(
              const Duration(seconds: 1),
            ),
      );
      logAt(now.add(DomainLogger.errorTraceRepeatWindow));
      logAt(now.add(DomainLogger.errorTraceRepeatWindow * 1.5));

      expect(captured().map((c) => c.$2), [trace, null, trace, null]);
    });

    test('a new calendar day logs the trace again inside the window', () {
      logAt(DateTime(2026, 10, 2, 23, 59));
      logAt(DateTime(2026, 10, 3, 0, 1));

      expect(captured().map((c) => c.$2), [trace, trace]);
    });

    test('errors without a stack trace are never annotated', () {
      withClock(Clock.fixed(now), () {
        logger
          ..error(LogDomain.sync, 'plain', subDomain: 'x')
          ..error(LogDomain.sync, 'plain', subDomain: 'x');
      });

      final calls = captured();
      expect(calls, [('plain', null), ('plain', null)]);
    });

    test('an evicted fingerprint logs its trace again', () {
      logAt(now);
      for (var i = 0; i < 256; i++) {
        logAt(now, error: 'error $i');
      }
      logAt(now);

      final calls = captured();
      expect(calls.first.$2, trace);
      expect(calls.last, ('M_NOT_FOUND', trace));
    });

    test('a recently repeated error is not the one evicted', () {
      logAt(now);
      for (var i = 0; i < 255; i++) {
        logAt(now, error: 'error $i');
      }
      logAt(now);
      logAt(now, error: 'one more');
      logAt(now);

      final calls = captured();
      expect(calls.last.$2, isNull);
      expect(calls.last.$1, contains('repeat 2'));
    });
  });

  // ---------------------------------------------------------------------------
  // _writeLine — non-test-env file-sink path (covers lines 36, 185-197)
  // ---------------------------------------------------------------------------
  group('DomainLogger file sink (non-test-env)', () {
    late Directory tempDocs;
    late LoggingService loggingService;
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

      await setUpTestGetIt(
        additionalSetup: () => getIt.registerSingleton<Directory>(tempDocs),
      );
      loggingService = getIt<LoggingService>();
      logger = getIt<DomainLogger>();
    });

    tearDown(() async {
      await loggingService.flush();
      await tearDownTestGetIt();
    });

    test('routine domain lines wait for the shared shutdown flush', () async {
      logger.enabledDomains.add(LogDomain.agentRuntime);
      logger
        ..log(LogDomain.agentRuntime, 'first buffered event')
        ..log(LogDomain.agentRuntime, 'second buffered event');
      expect(findLogFile('agentRuntime-'), isNull);
      await loggingService.flush();
      final lines = findLogFile('agentRuntime-')!.readAsLinesSync();
      expect(lines, hasLength(2));
      expect(lines[0], contains('first buffered event'));
      expect(lines[1], contains('second buffered event'));
    });

    test(
      'log writes message to domain log file when domain is enabled',
      () async {
        logger.enabledDomains.add(LogDomain.agentRuntime);

        logger.log(LogDomain.agentRuntime, 'file sink message');

        await loggingService.flush();
        final logFile = findLogFile('agentRuntime-');
        expect(
          logFile,
          isNotNull,
          reason: 'Domain log file should have been created',
        );
        final content = logFile!.readAsStringSync();
        expect(content, contains('[INFO]'));
        expect(content, contains('file sink message'));
      },
    );

    test('log writes subDomain and custom level to domain log file', () async {
      logger.enabledDomains.add(LogDomain.agentWorkflow);

      logger.log(
        LogDomain.agentWorkflow,
        'sub-domain log',
        subDomain: 'step-1',
        level: InsightLevel.warn,
      );

      await loggingService.flush();
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

    test('error writes full description to domain log file', () async {
      final exception = Exception('disk full');
      logger.error(
        LogDomain.agentRuntime,
        exception,
        message: 'write failed',
      );

      await loggingService.flush();
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

    test('identical repeats write each trace to each file once', () async {
      final stackTrace = StackTrace.fromString(
        '#0  repeated_frame (package:lotti/fake.dart:1:1)',
      );
      for (var i = 0; i < 3; i++) {
        logger
          ..error(LogDomain.agentRuntime, 'loop error', stackTrace: stackTrace)
          ..error(LogDomain.sync, 'sync loop error', stackTrace: stackTrace);
      }

      await loggingService.flush();
      // The general log and the full error mirror receive both domains.
      const tracesPerFile = {
        'agentRuntime-': 1,
        'sync-': 1,
        'error-2': 2,
        'lotti-': 2,
      };
      for (final MapEntry(key: stem, value: traces) in tracesPerFile.entries) {
        final content = findLogFile(stem)!.readAsStringSync();
        expect(
          'repeated_frame'.allMatches(content).length,
          traces,
          reason: stem,
        );
        expect(content, contains('[stack trace omitted: repeat 2'));
      }
    });

    test('error appends stackTrace lines to domain log file', () async {
      final stackTrace = StackTrace.fromString(
        '#0  fake_frame (package:lotti/fake.dart:1:1)',
      );
      logger.error(
        LogDomain.agentRuntime,
        'stack error',
        stackTrace: stackTrace,
      );

      await loggingService.flush();
      final logFile = findLogFile('agentRuntime-');
      expect(logFile, isNotNull);
      final content = logFile!.readAsStringSync();
      expect(content, contains('stack error'));
      expect(content, contains('fake_frame'));
    });

    test('sanitized errors preserve classification in the safe file', () async {
      final error = StateError('secret source content');
      logger.error(
        LogDomain.chat,
        error.runtimeType.toString(),
        errorType: error.runtimeType,
        subDomain: 'query.send',
        message: 'Query failed during setup',
      );
      await loggingService.flush();
      final safe = findLogFile('error-safe-')!.readAsStringSync();
      expect(
        safe,
        contains('Query failed during setup (errorType=StateError)'),
      );
      expect(safe, isNot(contains('errorType=String')));
      for (final stem in ['error-safe-', 'error-', 'chat-', 'lotti-']) {
        expect(
          findLogFile(stem)!.readAsStringSync(),
          isNot(contains('secret source content')),
        );
      }
    });

    test('error keeps diagnostics out of the PII-safe log file', () async {
      final exception = Exception('secret user content');
      logger.errorWithDiagnostics(
        LogDomain.agentRuntime,
        exception,
        message: 'load failed',
        diagnostics: 'widget: private journal title',
      );

      await loggingService.flush();
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
      expect(content, isNot(contains('private journal title')));

      final domainFile = findLogFile('agentRuntime-');
      expect(domainFile, isNotNull);
      expect(
        domainFile!.readAsStringSync(),
        contains('widget: private journal title'),
      );
    });

    test('sync error is written once alongside its safe mirror', () async {
      logger.error(
        LogDomain.sync,
        'sync error',
      );

      await loggingService.flush();
      final domainFile = findLogFile('sync-');
      // The PII-safe log should still be created.
      final safeFile = findLogFile('error-safe-');
      expect(safeFile, isNotNull, reason: 'PII-safe error log always written');
      final safeContent = safeFile!.readAsStringSync();
      expect(safeContent, contains('sync'));
      expect(
        domainFile!.readAsLinesSync().where(
          (line) => line.contains('sync error'),
        ),
        hasLength(1),
      );
    });

    test('_writeLine swallows file-sink errors gracefully', () async {
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
