import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:timezone/timezone.dart';

abstract final class NotificationConstants {
  static const int badgeNotificationId = 1;
  static const int taskThreshold = 5;
  static const String defaultActionName = 'Open notification';
  static const String taskSingular = 'task';
  static const String taskPlural = 'tasks';
  static const String inProgressSuffix = ' in progress';
  static const String encouragementLow = 'Nice';
  static const String encouragementHigh = "Let's get that number down";
}

final JournalDb _db = getIt<JournalDb>();

bool get _skipNotificationsOnCurrentPlatform =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Darwin initialization settings that ask the OS for **nothing**.
///
/// [DarwinInitializationSettings] defaults `requestAlertPermission`,
/// `requestBadgePermission` and `requestSoundPermission` to `true`, and the
/// native `initialize` passes whatever it is handed straight to
/// `UNUserNotificationCenter.requestAuthorization`. Constructing the plugin
/// with the defaults therefore raises the system "…would like to send you
/// notifications" dialog as a side effect of construction.
///
/// [NotificationService] is registered lazily, so construction happens on the
/// first `getIt<NotificationService>()` — which is `updateBadge()` during the
/// first entry write. A fresh install got the prompt while creating its first
/// task, before it had ever asked for a notification and with
/// [enableNotificationsFlag] still off.
///
/// With every option false the native `requestPermissionsImpl` returns early
/// without calling `requestAuthorization` at all, so this makes `initialize`
/// silent rather than merely quieter. Permission is instead requested later
/// and explicitly, by [NotificationService._requestPermissions], and only once
/// [NotificationService._notificationsAllowed] has confirmed the user wants
/// notifications.
const _silentDarwinInitialization = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestBadgePermission: false,
  requestSoundPermission: false,
);

/// Resolves notification timezones while suppressing duplicate diagnostics for
/// persistent invalid zone strings.
class NotificationLocationResolver {
  final Set<String> _loggedUnresolvedTimezones = {};

  Location resolve(String timezone) {
    try {
      return getLocation(timezone);
    } catch (exception, stackTrace) {
      if (_loggedUnresolvedTimezones.add(timezone)) {
        getIt<DomainLogger>().error(
          LogDomain.notifications,
          exception,
          stackTrace: stackTrace,
          subDomain: 'resolveLocation',
        );
      }
      return local;
    }
  }
}

class NotificationService {
  NotificationService() {
    initialized = _initializePlugin();
  }

  int badgeCount = 0;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final NotificationLocationResolver _locationResolver =
      NotificationLocationResolver();

  /// Completes when the constructor's fire-and-forget plugin initialization
  /// has finished.
  ///
  /// A test seam. Construction cannot be `async`, so `initialize` is started
  /// and left to run; nothing in the app waits for it. A test asserting on what
  /// `initialize` handed to the platform does need to know when it got there.
  ///
  /// It is deliberately *not* what handles failure — [_initializePlugin]
  /// catches around its own `await` for that, which is the part a `try`/`catch`
  /// around the bare call used to miss.
  @visibleForTesting
  late final Future<void> initialized;

  /// Memoized permission request — see [_requestPermissions].
  Future<void>? _permissionRequest;

  /// Whether the number on the app icon is known to read zero.
  ///
  /// Starts **false**, and that is the point: the icon badge outlives the
  /// process that set it, so a fresh run cannot assume it is clean. A user who
  /// quits with three tasks showing and comes back with notifications switched
  /// off would otherwise keep that number forever, because nothing would ever
  /// post over it.
  bool _badgeCleared = false;

  /// Initializes the plugin, degrading to a silent no-op on failure.
  ///
  /// A sandboxed build (flatpak) can fail to register the platform plugin
  /// entirely. That must not take start-up down: notifications are ancillary,
  /// and every method here already degrades to a no-op when the platform
  /// implementation is missing.
  Future<void> _initializePlugin() async {
    try {
      await flutterLocalNotificationsPlugin.initialize(
        settings: const InitializationSettings(
          linux: LinuxInitializationSettings(
            defaultActionName: NotificationConstants.defaultActionName,
          ),
          macOS: _silentDarwinInitialization,
          iOS: _silentDarwinInitialization,
        ),
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.notifications,
        exception,
        stackTrace: stackTrace,
        subDomain: 'initialization',
      );
    }
  }

  /// Resolves the local [Location] for scheduling, degrading to [local]
  /// rather than throwing.
  ///
  /// [getLocalTimezone] can still return a zone *abbreviation* when no IANA
  /// name is resolvable, and `getLocation` rejects those — `Location with the
  /// name "CEST" doesn't exist`. A reminder that cannot be scheduled in the
  /// user's exact zone is still worth scheduling in the process-local zone; it
  /// is never worth throwing, because this runs inside entry creation and the
  /// entry has already been written by the time it would.
  ///
  /// [local] is only a sane fallback because `configureLocalTimezone()` points
  /// it at the device's zone during start-up. The `timezone` package defaults
  /// it to **UTC**, and falling back to that would move a 09:00 reminder by
  /// the device's whole offset rather than degrade gracefully.
  Location _resolveLocation(String timezone) =>
      _locationResolver.resolve(timezone);

  /// Whether Lotti may hand anything at all to the OS notification system.
  ///
  /// Two conditions, checked in the order they are cheapest to evaluate:
  ///
  /// 1. The platform must have a notification surface Lotti drives. Linux and
  ///    Windows do not, so nothing there is worth a database read either.
  /// 2. [enableNotificationsFlag] must be on. It ships **off**.
  ///
  /// Every path that can reach [_requestPermissions] goes through here first,
  /// and that ordering is the whole point. Requesting permission is what
  /// raises the OS dialog, so asking before the flag has been consulted
  /// prompts users who have deliberately switched notifications off.
  Future<bool> _notificationsAllowed() async {
    if (_skipNotificationsOnCurrentPlatform) {
      return false;
    }
    return _db.getConfigFlag(enableNotificationsFlag);
  }

  /// Requests alert + badge permission from the OS, at most once per process.
  ///
  /// Reached only after [_notificationsAllowed] has returned true, so a user
  /// with notifications switched off is never asked.
  ///
  /// The result is memoized because the OS shows its dialog for the *first*
  /// request only; every later call is a channel round trip that returns a
  /// decision already on file. Caching the future rather than a boolean also
  /// collapses concurrent callers into a single request.
  ///
  /// A failure is logged and swallowed, and the memo is dropped so the next
  /// call tries again. Both halves matter. Asking is best-effort, but the
  /// callers are not: `NotificationRepository` schedules inside a vector-clock
  /// scope that commits only when its body returns, so an error escaping here
  /// would abort notification creation and every lifecycle transition — and
  /// memoizing a *rejected* future would make that abort permanent for the
  /// life of the process rather than transient.
  Future<void> _requestPermissions() =>
      _permissionRequest ??= _requestPermissionsOnce();

  Future<void> _requestPermissionsOnce() async {
    try {
      await _requestDarwinPermissions();
    } catch (exception, stackTrace) {
      _permissionRequest = null;
      getIt<DomainLogger>().error(
        LogDomain.notifications,
        exception,
        stackTrace: stackTrace,
        subDomain: 'requestPermissions',
      );
    }
  }

  /// `resolvePlatformSpecificImplementation` returns null off its matching
  /// platform, so at most one of these two does anything on any given device,
  /// and neither does on Linux or Windows.
  Future<void> _requestDarwinPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true);
  }

  /// Badge presentation. iOS never alerts for the badge — the number on the
  /// icon is the whole message there — while macOS alerts for a non-zero count
  /// so the "N tasks in progress" text is actually delivered.
  NotificationDetails _badgeDetails({required bool presentAlertOnDesktop}) =>
      NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          badgeNumber: badgeCount,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: presentAlertOnDesktop,
          presentBadge: true,
          badgeNumber: badgeCount,
        ),
      );

  /// Presentation shared by the three entry points that raise a real alert.
  ///
  /// A platform the caller did not opt into gets null details, which is what
  /// keeps a mobile-only reminder off the desktop and vice versa.
  NotificationDetails _alertDetails({
    required String title,
    required bool showOnMobile,
    required bool showOnDesktop,
  }) => NotificationDetails(
    iOS: showOnMobile
        ? const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBanner: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          )
        : null,
    macOS: showOnDesktop
        ? DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            subtitle: title,
            interruptionLevel: InterruptionLevel.timeSensitive,
          )
        : null,
  );

  /// Reflects the number of tasks in progress on the app icon.
  ///
  /// Runs after every entry write, which makes it the first thing to resolve
  /// the lazily registered service — and therefore the first thing that could
  /// prompt for permission. It must not, while notifications are off.
  Future<void> updateBadge() async {
    if (!await _notificationsAllowed()) {
      await _clearBadge();
      return;
    }

    await _requestPermissions();

    final count = await _db.getWipCount();

    if (count == badgeCount) {
      return;
    }

    if (count == 0) {
      await _zeroBadge();
      return;
    }

    badgeCount = count;
    _badgeCleared = false;

    await flutterLocalNotificationsPlugin.cancel(
      id: NotificationConstants.badgeNotificationId,
    );

    final label = badgeCount == 1
        ? NotificationConstants.taskSingular
        : NotificationConstants.taskPlural;

    await flutterLocalNotificationsPlugin.show(
      id: NotificationConstants.badgeNotificationId,
      title: '$badgeCount $label${NotificationConstants.inProgressSuffix}',
      body: badgeCount < NotificationConstants.taskThreshold
          ? NotificationConstants.encouragementLow
          : NotificationConstants.encouragementHigh,
      notificationDetails: _badgeDetails(presentAlertOnDesktop: true),
    );
  }

  /// Takes the badge down when notifications are off.
  ///
  /// Switching the flag off has to take the badge with it: the number on the
  /// icon is an OS-level artefact, and leaving it alive for someone who just
  /// said they did not want notifications is the same defect as prompting
  /// them.
  ///
  /// Guarded on [_badgeCleared] so the ordinary case — notifications off, with
  /// [updateBadge] running after every entry write — costs at most one pair of
  /// platform calls per process rather than one per write. It cannot be
  /// guarded on [badgeCount], which starts at zero on a run that inherited a
  /// badge from the previous one.
  ///
  /// The platform check is repeated because [_notificationsAllowed] folds
  /// "unsupported platform" and "user said no" into one answer, and only the
  /// second is a reason to clear. A platform Lotti does not badge has no badge
  /// to take down.
  Future<void> _clearBadge() async {
    if (_badgeCleared || _skipNotificationsOnCurrentPlatform) {
      return;
    }
    await _zeroBadge();
  }

  /// Replaces the badge notification with one carrying `badgeNumber: 0`.
  ///
  /// Both calls are load-bearing, and cancelling alone is not enough.
  /// `cancel` removes the delivered record — the "3 tasks in progress" entry
  /// sitting in Notification Center — but on Darwin the number on the icon is
  /// carried by a notification's `badge` field (`content.badge` natively), and
  /// `removeDeliveredNotifications` does not reset it. Only a post of zero
  /// actually clears the icon.
  ///
  /// Posting this while notifications are off is not a notification in any
  /// sense the user sees: it is empty, `presentAlert: false`, and exists only
  /// to zero the number. It also cannot prompt — the dialog comes from
  /// `requestAuthorization`, never from posting — and without authorization it
  /// silently does nothing, which is correct, because then there is no badge.
  Future<void> _zeroBadge() async {
    badgeCount = 0;
    _badgeCleared = true;

    await flutterLocalNotificationsPlugin.cancel(
      id: NotificationConstants.badgeNotificationId,
    );
    await flutterLocalNotificationsPlugin.show(
      id: NotificationConstants.badgeNotificationId,
      title: '',
      body: '',
      notificationDetails: _badgeDetails(presentAlertOnDesktop: false),
    );
  }

  Future<void> scheduleHabitNotification(
    HabitDefinition habitDefinition, {
    int daysToAdd = 0,
  }) async {
    final alertAtTime = habitDefinition.habitSchedule.maybeMap(
      daily: (d) => d.alertAtTime,
      orElse: () => null,
    );

    if (alertAtTime != null) {
      final notifyAt = DateTime.now()
          .add(Duration(days: daysToAdd))
          .copyWith(
            hour: alertAtTime.hour,
            minute: alertAtTime.minute,
            second: alertAtTime.second,
          );

      await getIt<NotificationService>().scheduleNotification(
        title: habitDefinition.name,
        body: habitDefinition.description,
        showOnMobile: true,
        showOnDesktop: false,
        notifyAt: notifyAt,
        notificationId: habitDefinition.id.hashCode,
      );
    }
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime notifyAt,
    required int notificationId,
    required bool showOnMobile,
    required bool showOnDesktop,
    bool repeat = false,
    String? deepLink,
  }) async {
    if (!await _notificationsAllowed()) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);
    final now = DateTime.now();
    final location = _resolveLocation(await getLocalTimezone());

    final scheduledDate = TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      notifyAt.hour,
      notifyAt.minute,
      notifyAt.second,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _alertDetails(
        title: title,
        showOnMobile: showOnMobile,
        showOnDesktop: showOnDesktop,
      ),
      matchDateTimeComponents: repeat ? DateTimeComponents.time : null,
      payload: deepLink,
      androidScheduleMode: AndroidScheduleMode.exact,
    );
  }

  Future<void> scheduleNotificationAt({
    required String title,
    required String body,
    required DateTime notifyAt,
    required int notificationId,
    required bool showOnMobile,
    required bool showOnDesktop,
    String? deepLink,
  }) async {
    if (!await _notificationsAllowed()) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);
    final location = _resolveLocation(await getLocalTimezone());
    final scheduledDate = TZDateTime.from(notifyAt, location);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _alertDetails(
        title: title,
        showOnMobile: showOnMobile,
        showOnDesktop: showOnDesktop,
      ),
      payload: deepLink,
      androidScheduleMode: AndroidScheduleMode.exact,
    );
  }

  Future<void> showNotificationNow({
    required String title,
    required String body,
    required int notificationId,
    required bool showOnMobile,
    required bool showOnDesktop,
    String? deepLink,
  }) async {
    if (!await _notificationsAllowed()) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);

    await flutterLocalNotificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: _alertDetails(
        title: title,
        showOnMobile: showOnMobile,
        showOnDesktop: showOnDesktop,
      ),
      payload: deepLink,
    );
  }

  Future<void> cancelNotification(int notificationId) async {
    if (_skipNotificationsOnCurrentPlatform) {
      return;
    }

    await flutterLocalNotificationsPlugin.cancel(id: notificationId);
  }
}
