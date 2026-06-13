import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart' show PersistenceLogic;
import 'package:lotti/logic/persistence_logic_contract.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:uuid/uuid.dart';

/// Shared dependencies for the [PersistenceLogic] collaborators.
///
/// Each collaborator resolves its singletons lazily from `getIt` (matching
/// the original mixin layout) and holds a [logic] back-reference to the
/// facade for cross-group calls that must remain virtually overridable.
abstract class PersistenceCollaboratorBase {
  PersistenceCollaboratorBase(this.logic);

  /// Facade back-reference for cross-collaborator calls.
  final PersistenceLogicContract logic;

  JournalDb get journalDb => getIt<JournalDb>();
  MetadataService get metadataService => getIt<MetadataService>();
  VectorClockService get vectorClockService => getIt<VectorClockService>();
  GeolocationService get geolocationService => getIt<GeolocationService>();
  DomainLogger get loggingService => getIt<DomainLogger>();
  UpdateNotifications get updateNotifications => getIt<UpdateNotifications>();
  OutboxService get outboxService => getIt<OutboxService>();
  SyncSequenceLogService? get sequenceLogService =>
      getIt.isRegistered<SyncSequenceLogService>()
      ? getIt<SyncSequenceLogService>()
      : null;
  final Uuid uuid = const Uuid();

  /// Records that [entity] was sent, so the sync sequence log can detect gaps.
  ///
  /// No-op when the sequence log service is unregistered or the entity has no
  /// vector clock. Shared by the create and update DB writers.
  Future<void> recordJournalSequence(
    JournalEntity entity, {
    required String subDomain,
  }) async {
    final vectorClock = entity.meta.vectorClock;
    final service = sequenceLogService;
    if (service == null || vectorClock == null) return;
    try {
      await service.recordSentEntry(
        entryId: entity.meta.id,
        vectorClock: vectorClock,
      );
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        exception,
        stackTrace: stackTrace,
        subDomain: subDomain,
      );
    }
  }
}
