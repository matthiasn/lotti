import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/logic/config_flag_effects.dart';
import 'package:lotti/logic/persistence_logic.dart' show PersistenceLogic;
import 'package:lotti/logic/persistence_logic_contract.dart';
import 'package:lotti/logic/persistence_services.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Shared dependencies for the [PersistenceLogic] collaborators.
///
/// Each collaborator reaches its services through [services], resolved on
/// use, and holds a [logic] back-reference to the facade for cross-group
/// calls that must remain virtually overridable.
abstract class PersistenceCollaboratorBase {
  PersistenceCollaboratorBase(this.logic, this.services);

  /// Facade back-reference for cross-collaborator calls.
  final PersistenceLogicContract logic;

  /// The services this collaborator uses.
  final PersistenceServices services;

  JournalDb get journalDb => services.journalDb();
  MetadataService get metadataService => services.metadataService();
  VectorClockService get vectorClockService => services.vectorClockService();
  GeolocationService get geolocationService => services.geolocationService();
  DomainLogger get loggingService => services.domainLogger();
  UpdateNotifications get updateNotifications => services.updateNotifications();
  OutboxService get outboxService => services.outboxService();
  Fts5Db get fts5Db => services.fts5Db();
  NotificationService get notificationService => services.notificationService();
  ConfigFlagEffects get configFlagEffects => services.configFlagEffects();
}
