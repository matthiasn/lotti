import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/notifications/model/notification_tap_payload.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/nav_service.dart';

/// Turns a tapped OS notification into navigation.
///
/// Both ways a tap reaches Dart end here: the plugin's response callback
/// while the app is running, and the launch details read at boot when the tap
/// is what started the app. The payload says where to go; this opens it
/// through the same router the bell uses and, for an inbox row, marks the row
/// seen so the bell's badge clears and the alert leaves every other device.
///
/// **Never throws.** The callback path runs inside the plugin's channel
/// handler and the launch path runs inside bootstrap; neither is a place for
/// an exception to surface, so a tap that cannot be routed is a logged miss.
class NotificationTapRouter {
  NotificationTapRouter({
    required this._navService,
    required this._notificationRepository,
    required this._logger,
  });

  final NavService _navService;
  final NotificationRepository _notificationRepository;
  final DomainLogger _logger;

  /// Routes one tap carrying [rawPayload].
  ///
  /// The beam goes first and the row is marked afterwards: the screen is what
  /// the user tapped for, and marking seen is bookkeeping that must not delay
  /// it or, failing, prevent it. The beam waits for the config flags when
  /// they have not arrived yet — see [NavService.beamToNamedWhenReady] — so a
  /// cold-start tap into a flag-gated tab is not normalised away.
  Future<void> handleTap(String? rawPayload) async {
    final payload = NotificationTapPayload.decode(rawPayload);
    if (payload == null) {
      _logger.log(
        LogDomain.notifications,
        'dropped a notification tap with no routable payload: $rawPayload',
        subDomain: 'tap',
        level: InsightLevel.warn,
      );
      return;
    }

    _navService.beamToNamedWhenReady(payload.route);

    final inboxId = payload.inboxId;
    if (inboxId == null) return;
    try {
      await _notificationRepository.markSeen(inboxId);
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.notifications,
        error,
        stackTrace: stackTrace,
        subDomain: 'tap.markSeen',
      );
    }
  }
}
