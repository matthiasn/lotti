import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart' show PersistenceLogic;
import 'package:lotti/logic/persistence_logic_contract.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';

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
}
