import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/sync/consumption_sync_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Thin, safe facade that AI call sites use to record one consumption event.
///
/// It **never throws**: recording is a diagnostics side-effect and must never
/// fail an inference, so the whole body is guarded and failures are logged.
/// Call sites can therefore `await recorder.record(event)` without their own
/// try/catch.
class AiConsumptionRecorder {
  AiConsumptionRecorder({
    required this._syncService,
    required this._logger,
  });

  final ConsumptionSyncService _syncService;
  final DomainLogger _logger;

  Future<void> record(AiConsumptionEvent event) async {
    try {
      await _syncService.recordEvent(event);
    } on Object catch (exception, stackTrace) {
      _logger.error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: 'aiConsumptionRecorder.record',
      );
    }
  }
}
