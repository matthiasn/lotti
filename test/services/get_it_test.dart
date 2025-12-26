import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class TestService {
  const TestService();
}

class ThrowingService {
  ThrowingService() {
    throw StateError('failed');
  }
}

void _logFallback() => safeLogForTesting('fallback', isError: false);
ThrowingService _resolveThrowingService() => getIt<ThrowingService>();

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() async {
    await getIt.reset();
    getIt.allowReassignment = true;
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('safeLogForTesting routes through logging service when available', () {
    final loggingService = MockLoggingService();
    when(
      () => loggingService.captureEvent(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).thenReturn(null);

    getIt.registerSingleton<LoggingService>(loggingService);
    safeLogForTesting('problem', isError: true);

    verify(
      () => loggingService.captureEvent(
        'problem',
        domain: 'SERVICE_REGISTRATION',
        subDomain: 'error',
      ),
    ).called(1);
  });

  test('safeLogForTesting uses DevLogger when logging service missing', () {
    DevLogger.clear();

    _logFallback();

    expect(DevLogger.capturedLogs, isNotEmpty);
    expect(
      DevLogger.capturedLogs.any((log) => log.contains('fallback')),
      isTrue,
    );
  });

  test('registerLazyServiceForTesting registers and logs success', () {
    final loggingService = MockLoggingService();
    when(
      () => loggingService.captureEvent(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).thenReturn(null);

    getIt.registerSingleton<LoggingService>(loggingService);

    registerLazyServiceForTesting<TestService>(
      TestService.new,
      'TestService',
    );

    final instance = getIt<TestService>();
    expect(instance, isA<TestService>());

    verify(
      () => loggingService.captureEvent(
        any<Object>(),
        domain: 'SERVICE_REGISTRATION',
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).called(2);
  });

  test('registerLazyServiceForTesting logs failure when factory throws', () {
    final loggingService = MockLoggingService();
    when(
      () => loggingService.captureEvent(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).thenReturn(null);

    getIt.registerSingleton<LoggingService>(loggingService);

    registerLazyServiceForTesting<ThrowingService>(
      ThrowingService.new,
      'ThrowingService',
    );

    // Suppress get_it package's internal debug printing during error
    runZoned(
      () => expect(_resolveThrowingService, throwsStateError),
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, ____) {}, // Suppress prints from get_it package
      ),
    );

    verify(
      () => loggingService.captureEvent(
        contains('Failed to create lazy instance of ThrowingService'),
        domain: 'SERVICE_REGISTRATION',
        subDomain: 'error',
      ),
    ).called(1);
  });
}
