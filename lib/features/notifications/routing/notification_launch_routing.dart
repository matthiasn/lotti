import 'package:flutter/foundation.dart';
import 'package:lotti/features/notifications/routing/notification_tap_router.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';

/// Whether this process has already asked what launched it.
bool _launchRouted = false;

/// Forgets that the launch was routed, so a test can run boot again.
@visibleForTesting
void resetNotificationLaunchRouting() => _launchRouted = false;

/// Opens the screen of the notification that launched the app, if one did.
///
/// A tap that arrives before the Dart side of the plugin is initialised is
/// never replayed to the response callback: Android answers from the
/// launching intent and iOS/macOS park the response natively, and both hand
/// it out only through `getNotificationAppLaunchDetails`. So a cold start has
/// to ask, once, after navigation has been restored — the tap then lands on
/// top of the restored position rather than under it.
///
/// Asking materialises the lazily registered [NotificationService], and that
/// is wanted on every platform Lotti notifies on: iOS parks *every* tap that
/// arrives before initialise, including one on a process alive in the
/// background, so an uninitialised plugin would swallow warm taps as well.
/// Linux and Windows are skipped before the service is touched, which keeps
/// the sandboxed-build guarantee the lazy registration exists for.
///
/// Once per process: `registerSingletons` runs again on a profile switch, and
/// the launch details describe the same tap every time they are read, so a
/// second read would replay a tap the user already acted on into the new
/// world.
///
/// **Never throws.** This runs during boot, awaited before `runApp`.
Future<void> routeNotificationLaunch({
  required NotificationService Function() notificationService,
  required NotificationTapRouter router,
  required DomainLogger logger,
}) async {
  if (_launchRouted || !NotificationService.notifiesOnCurrentPlatform) return;
  _launchRouted = true;
  try {
    final payload = await notificationService().launchNotificationPayload();
    if (payload == null) return;
    await router.handleTap(payload);
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.notifications,
      error,
      stackTrace: stackTrace,
      subDomain: 'launch',
    );
  }
}
