import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/relationship_cascade.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// The services [JournalRepository] reaches, each resolved on use.
///
/// Resolved per call rather than at construction: the composition root
/// builds a repository while it is still registering the services it uses,
/// and a profile switch replaces them under a repository that outlives it.
/// `journalRepositoryProvider` reads them from their providers; the
/// composition root, from the locator.
class JournalRepositoryServices {
  const JournalRepositoryServices({
    required this.journalDb,
    required this.persistenceLogic,
    required this.domainLogger,
    required this.timeService,
    required this.notificationService,
    required this.vectorClockService,
    required this.updateNotifications,
    required this.outboxService,
    required this.relationshipCascade,
  });

  final JournalDb Function() journalDb;

  final PersistenceLogic Function() persistenceLogic;

  final DomainLogger Function() domainLogger;

  final TimeService Function() timeService;

  final NotificationService Function() notificationService;

  final VectorClockService Function() vectorClockService;

  final UpdateNotifications Function() updateNotifications;

  final OutboxService Function() outboxService;

  /// Builds the writes to a person that a delete cascades into.
  final RelationshipCascadeFactory Function() relationshipCascade;
}
