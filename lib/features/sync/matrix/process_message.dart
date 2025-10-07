import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// TODO: Delete this function once all call sites are migrated to rely on
/// [SyncEventProcessor] directly.
Future<void> processMatrixMessage({
  required Event event,
  required MatrixService service,
  JournalDb? overriddenJournalDb,
  SyncEventProcessor? eventProcessor,
}) async {
  final processor = eventProcessor ??
      SyncEventProcessor(
        loggingService: getIt<LoggingService>(),
        updateNotifications: getIt<UpdateNotifications>(),
        aiConfigRepository: getIt<AiConfigRepository>(),
      );

  await processor.process(
    event: event,
    journalDb: overriddenJournalDb ?? getIt<JournalDb>(),
  );
}
