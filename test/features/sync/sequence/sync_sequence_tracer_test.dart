import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(LogDomain.sync);
    registerFallbackValue(StackTrace.empty);
  });

  late MockDomainLogger loggingService;
  late MockDomainLogger domainLogger;

  setUp(() {
    loggingService = MockDomainLogger();
    domainLogger = MockDomainLogger();
    when(
      () => loggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => domainLogger.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => loggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
  });

  test('routes through the injected DomainLogger when present', () {
    SyncSequenceTracer(
      loggingService: loggingService,
      domainLogger: domainLogger,
    ).trace('hello', subDomain: 'sequence.test');

    verify(
      () =>
          domainLogger.log(LogDomain.sync, 'hello', subDomain: 'sequence.test'),
    ).called(1);
    verifyNever(
      () =>
          loggingService.log(any(), any(), subDomain: any(named: 'subDomain')),
    );
  });

  test(
    'falls back to the logging service when no DomainLogger is injected',
    () {
      SyncSequenceTracer(loggingService: loggingService).trace('msg');

      // Default sub-domain applied when none is supplied.
      verify(
        () => loggingService.log(LogDomain.sync, 'msg', subDomain: 'sequence'),
      ).called(1);
    },
  );

  test('error always routes to the logging service error sink', () {
    final st = StackTrace.current;
    final boom = Exception('boom');

    SyncSequenceTracer(
      loggingService: loggingService,
      domainLogger: domainLogger,
    ).error(boom, st, subDomain: 'missingEntriesDetected');

    verify(
      () => loggingService.error(
        LogDomain.sync,
        boom,
        stackTrace: st,
        subDomain: 'missingEntriesDetected',
      ),
    ).called(1);
  });
}
