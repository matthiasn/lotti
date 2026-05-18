// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_inbox_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reactive count of unseen notifications that should pulse the bell badge.
///
/// Refreshes whenever an entry in [UpdateNotifications.updateStream] contains
/// [inboxNotification] — every notification create / state change / sync apply
/// path already emits that constant via [NotificationRepository._notify] and
/// the matrix sync handlers, so the bell stays in step with the database.

@ProviderFor(UnseenNotificationCount)
final unseenNotificationCountProvider = UnseenNotificationCountProvider._();

/// Reactive count of unseen notifications that should pulse the bell badge.
///
/// Refreshes whenever an entry in [UpdateNotifications.updateStream] contains
/// [inboxNotification] — every notification create / state change / sync apply
/// path already emits that constant via [NotificationRepository._notify] and
/// the matrix sync handlers, so the bell stays in step with the database.
final class UnseenNotificationCountProvider
    extends $AsyncNotifierProvider<UnseenNotificationCount, int> {
  /// Reactive count of unseen notifications that should pulse the bell badge.
  ///
  /// Refreshes whenever an entry in [UpdateNotifications.updateStream] contains
  /// [inboxNotification] — every notification create / state change / sync apply
  /// path already emits that constant via [NotificationRepository._notify] and
  /// the matrix sync handlers, so the bell stays in step with the database.
  UnseenNotificationCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unseenNotificationCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unseenNotificationCountHash();

  @$internal
  @override
  UnseenNotificationCount create() => UnseenNotificationCount();
}

String _$unseenNotificationCountHash() =>
    r'8dc0aae9028f48a30f37dcc76a6edbe1778fb7a9';

/// Reactive count of unseen notifications that should pulse the bell badge.
///
/// Refreshes whenever an entry in [UpdateNotifications.updateStream] contains
/// [inboxNotification] — every notification create / state change / sync apply
/// path already emits that constant via [NotificationRepository._notify] and
/// the matrix sync handlers, so the bell stays in step with the database.

abstract class _$UnseenNotificationCount extends $AsyncNotifier<int> {
  FutureOr<int> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Sorted list of notifications that belong in the inbox popover.
///
/// "Inbox-worthy" means the same predicate `dueNotificationRows` /
/// `upcomingNotificationRows` apply at the SQL layer: still unseen, unacted,
/// and not deleted. The two streams are concatenated due-first then upcoming,
/// matching the visual ordering users expect (overdue alerts on top).

@ProviderFor(InboxNotifications)
final inboxNotificationsProvider = InboxNotificationsProvider._();

/// Sorted list of notifications that belong in the inbox popover.
///
/// "Inbox-worthy" means the same predicate `dueNotificationRows` /
/// `upcomingNotificationRows` apply at the SQL layer: still unseen, unacted,
/// and not deleted. The two streams are concatenated due-first then upcoming,
/// matching the visual ordering users expect (overdue alerts on top).
final class InboxNotificationsProvider
    extends
        $AsyncNotifierProvider<InboxNotifications, List<NotificationEntity>> {
  /// Sorted list of notifications that belong in the inbox popover.
  ///
  /// "Inbox-worthy" means the same predicate `dueNotificationRows` /
  /// `upcomingNotificationRows` apply at the SQL layer: still unseen, unacted,
  /// and not deleted. The two streams are concatenated due-first then upcoming,
  /// matching the visual ordering users expect (overdue alerts on top).
  InboxNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inboxNotificationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inboxNotificationsHash();

  @$internal
  @override
  InboxNotifications create() => InboxNotifications();
}

String _$inboxNotificationsHash() =>
    r'16a74a352356fb03515724b6a2da148ff4677e83';

/// Sorted list of notifications that belong in the inbox popover.
///
/// "Inbox-worthy" means the same predicate `dueNotificationRows` /
/// `upcomingNotificationRows` apply at the SQL layer: still unseen, unacted,
/// and not deleted. The two streams are concatenated due-first then upcoming,
/// matching the visual ordering users expect (overdue alerts on top).

abstract class _$InboxNotifications
    extends $AsyncNotifier<List<NotificationEntity>> {
  FutureOr<List<NotificationEntity>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<NotificationEntity>>,
              List<NotificationEntity>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<NotificationEntity>>,
                List<NotificationEntity>
              >,
              AsyncValue<List<NotificationEntity>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
