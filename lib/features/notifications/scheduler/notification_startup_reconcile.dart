import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/services/domain_logging.dart';

/// Re-arms OS alerts for still-schedulable notification rows during startup.
///
/// Extracted from the composition root rather than inlined there so the
/// swallow-and-log contract below is testable: `registerSingletons` cannot be
/// exercised without standing up the whole DI graph.
///
/// **Never throws.** Startup calls this fire-and-forget, and a notification
/// database that cannot be read is not a reason to fail a launch — the app
/// works fine without re-armed alarms, and the next write re-schedules the row
/// anyway. An error escaping a fire-and-forget call would instead surface as
/// an unhandled async error during boot.
Future<void> reconcileScheduledNotifications({
  required NotificationScheduler scheduler,
  required DomainLogger logger,
}) async {
  try {
    await scheduler.reconcile();
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.notifications,
      error,
      stackTrace: stackTrace,
      subDomain: 'reconcile',
    );
  }
}
