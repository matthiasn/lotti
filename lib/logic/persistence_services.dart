import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/logic/config_flag_effects.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// The services the persistence collaborators reach, each resolved on use.
///
/// Resolved per call rather than captured: the composition root builds the
/// persistence facade before some of these exist (the notification service
/// is lazy), and a test may register a service after building the facade.
class PersistenceServices {
  const PersistenceServices({
    required this.journalDb,
    required this.metadataService,
    required this.vectorClockService,
    required this.geolocationService,
    required this.domainLogger,
    required this.updateNotifications,
    required this.outboxService,
    required this.fts5Db,
    required this.notificationService,
    required this.configFlagEffects,
  });

  final JournalDb Function() journalDb;

  final MetadataService Function() metadataService;

  final VectorClockService Function() vectorClockService;

  final GeolocationService Function() geolocationService;

  final DomainLogger Function() domainLogger;

  final UpdateNotifications Function() updateNotifications;

  final OutboxService Function() outboxService;

  final Fts5Db Function() fts5Db;

  final NotificationService Function() notificationService;

  final ConfigFlagEffects Function() configFlagEffects;
}
