import 'package:flutter/widgets.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';

/// Raises the ADR 0032 §5 "your plan is ready" OS notification when a durable
/// draft/refine job completes while the app is not in the foreground.
///
/// Wired as `DayProcessingOutboxProcessor.onJobFinished`: the processor fires
/// it once per terminal job, so the notification path is event-driven — no
/// polling, and a job that completes after the user backgrounded the app (or
/// closed the drafting modal) still surfaces its result.
class DayPlanReadyNotifier {
  DayPlanReadyNotifier({
    NotificationService? notificationService,
    AppLocalizations Function()? messages,
    bool Function()? isAppInForeground,
  }) : // Stored as-is (resolved lazily via `_notifications`); a private named
       // initializing formal isn't valid Dart.
       // ignore: prefer_initializing_formals
       _notificationService = notificationService,
       _messages = messages ?? _deviceMessages,
       _isAppInForeground = isAppInForeground ?? _lifecycleForeground;

  /// Resolves the user's locale for the OS banner copy, falling back to
  /// English for locales the app doesn't ship translations for.
  static AppLocalizations _deviceMessages() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return AppLocalizations.delegate.isSupported(locale)
        ? lookupAppLocalizations(locale)
        : AppLocalizationsEn();
  }

  /// Foreground check via the widgets binding: `resumed` means the UI is
  /// visible and the in-app Activity timeline is the completion surface, so
  /// no OS banner. A `null` lifecycle (before the first frame) is treated as
  /// foreground so startup drains never produce surprise banners.
  static bool _lifecycleForeground() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Stable notification id — a newer completion replaces the previous
  /// banner rather than stacking one per job.
  static const int notificationId = 0xDA9;

  /// Deep link payload pointing at the Daily OS day surface.
  static const String deepLink = '/calendar';

  final NotificationService? _notificationService;
  final AppLocalizations Function() _messages;
  final bool Function() _isAppInForeground;

  /// Resolved lazily so the lazily-registered [NotificationService] is not
  /// forced to instantiate during DI bootstrap.
  NotificationService get _notifications =>
      _notificationService ?? getIt<NotificationService>();

  /// Handles one terminal job from the outbox processor.
  ///
  /// Never throws: the hook is invoked fire-and-forget from the processor's
  /// completion path, so a delivery failure (service resolution, locale
  /// lookup, platform plugin) must stay a contained best-effort miss instead
  /// of surfacing as an unhandled async error on job completion.
  Future<void> onJobFinished(DayProcessingJob job) async {
    if (job.status != DayProcessingJobStatus.succeeded) return;
    final isPlanJob =
        job.kind == DayProcessingJobKind.draftPlan ||
        job.kind == DayProcessingJobKind.refinePlan;
    if (!isPlanJob) return;
    if (_isAppInForeground()) return;

    try {
      final messages = _messages();
      final isDraft = job.kind == DayProcessingJobKind.draftPlan;
      await _notifications.showNotificationNow(
        title: isDraft
            ? messages.dailyOsNextPlanReadyNotificationTitle
            : messages.dailyOsNextPlanChangesReadyNotificationTitle,
        body: isDraft
            ? messages.dailyOsNextPlanReadyNotificationBody
            : messages.dailyOsNextPlanChangesReadyNotificationBody,
        notificationId: notificationId,
        showOnMobile: true,
        showOnDesktop: true,
        deepLink: deepLink,
      );
    } catch (e, s) {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.agentWorkflow,
          e,
          message: 'failed to raise plan-ready notification',
          stackTrace: s,
        );
      }
    }
  }
}
