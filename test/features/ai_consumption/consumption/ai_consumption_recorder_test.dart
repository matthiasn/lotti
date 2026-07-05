import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/consumption/ai_consumption_recorder.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockConsumptionSyncService syncService;
  late MockDomainLogger logger;
  late AiConsumptionRecorder recorder;

  setUpAll(() {
    registerFallbackValue(fallbackAiConsumptionEvent);
  });

  setUp(() {
    syncService = MockConsumptionSyncService();
    logger = MockDomainLogger();
    recorder = AiConsumptionRecorder(syncService: syncService, logger: logger);
  });

  test('record delegates the exact event to the sync service', () async {
    final event = makeConsumptionEvent(id: 'evt-record-1');
    when(() => syncService.recordEvent(any())).thenAnswer((_) async {});

    await recorder.record(event);

    // The very same event instance is forwarded, unmodified.
    verify(() => syncService.recordEvent(event)).called(1);
    verifyNever(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
        message: any(named: 'message'),
      ),
    );
  });

  test('record never throws when the sync service fails — it logs', () async {
    final event = makeConsumptionEvent(id: 'evt-record-2');
    final failure = Exception('sync write exploded');
    when(() => syncService.recordEvent(any())).thenThrow(failure);

    // Recording is a diagnostics side-effect: the caller must never see the
    // failure.
    await expectLater(recorder.record(event), completes);

    final captured = verify(
      () => logger.error(
        LogDomain.ai,
        captureAny<Object>(),
        stackTrace: captureAny(named: 'stackTrace'),
        subDomain: 'aiConsumptionRecorder.record',
      ),
    ).captured;
    expect(captured[0], failure);
    expect(captured[1], isA<StackTrace>());
  });
}
