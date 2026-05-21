// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_inbox_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reactive count of unseen notifications that should pulse the bell badge.
///
/// Refreshes whenever an entry in `UpdateNotifications.updateStream` contains
/// [inboxNotification] — every notification create / state change / sync apply
/// path already emits that constant via `NotificationRepository._notify` and
/// the matrix sync handlers, so the bell stays in step with the database.
///
/// `_refresh` guards against two failure modes that bit a previous revision:
/// 1. **Unhandled async errors** — wrapped in try/catch and surfaced as
///    `AsyncError` so the consumer (the bell) can render a neutral fallback
///    instead of crashing the listener.
/// 2. **Stale completion order** — concurrent stream events can fan out
///    multiple `_refresh()` calls. An epoch counter discards results from any
///    refresh that finishes after a newer one started, so the latest fetch
///    always wins regardless of database latency.

@ProviderFor(UnseenNotificationCount)
final unseenNotificationCountProvider = UnseenNotificationCountProvider._();

/// Reactive count of unseen notifications that should pulse the bell badge.
///
/// Refreshes whenever an entry in `UpdateNotifications.updateStream` contains
/// [inboxNotification] — every notification create / state change / sync apply
/// path already emits that constant via `NotificationRepository._notify` and
/// the matrix sync handlers, so the bell stays in step with the database.
///
/// `_refresh` guards against two failure modes that bit a previous revision:
/// 1. **Unhandled async errors** — wrapped in try/catch and surfaced as
///    `AsyncError` so the consumer (the bell) can render a neutral fallback
///    instead of crashing the listener.
/// 2. **Stale completion order** — concurrent stream events can fan out
///    multiple `_refresh()` calls. An epoch counter discards results from any
///    refresh that finishes after a newer one started, so the latest fetch
///    always wins regardless of database latency.
final class UnseenNotificationCountProvider
    extends $AsyncNotifierProvider<UnseenNotificationCount, int> {
  /// Reactive count of unseen notifications that should pulse the bell badge.
  ///
  /// Refreshes whenever an entry in `UpdateNotifications.updateStream` contains
  /// [inboxNotification] — every notification create / state change / sync apply
  /// path already emits that constant via `NotificationRepository._notify` and
  /// the matrix sync handlers, so the bell stays in step with the database.
  ///
  /// `_refresh` guards against two failure modes that bit a previous revision:
  /// 1. **Unhandled async errors** — wrapped in try/catch and surfaced as
  ///    `AsyncError` so the consumer (the bell) can render a neutral fallback
  ///    instead of crashing the listener.
  /// 2. **Stale completion order** — concurrent stream events can fan out
  ///    multiple `_refresh()` calls. An epoch counter discards results from any
  ///    refresh that finishes after a newer one started, so the latest fetch
  ///    always wins regardless of database latency.
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
    r'f16cc9183b1f70ca5b9cdd3c2719157cb43641ae';

/// Reactive count of unseen notifications that should pulse the bell badge.
///
/// Refreshes whenever an entry in `UpdateNotifications.updateStream` contains
/// [inboxNotification] — every notification create / state change / sync apply
/// path already emits that constant via `NotificationRepository._notify` and
/// the matrix sync handlers, so the bell stays in step with the database.
///
/// `_refresh` guards against two failure modes that bit a previous revision:
/// 1. **Unhandled async errors** — wrapped in try/catch and surfaced as
///    `AsyncError` so the consumer (the bell) can render a neutral fallback
///    instead of crashing the listener.
/// 2. **Stale completion order** — concurrent stream events can fan out
///    multiple `_refresh()` calls. An epoch counter discards results from any
///    refresh that finishes after a newer one started, so the latest fetch
///    always wins regardless of database latency.

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
///
/// `_refresh` uses the same epoch + try/catch guard as
/// [UnseenNotificationCount] — see that class's doc comment for the reasoning.

@ProviderFor(InboxNotifications)
final inboxNotificationsProvider = InboxNotificationsProvider._();

/// Sorted list of notifications that belong in the inbox popover.
///
/// "Inbox-worthy" means the same predicate `dueNotificationRows` /
/// `upcomingNotificationRows` apply at the SQL layer: still unseen, unacted,
/// and not deleted. The two streams are concatenated due-first then upcoming,
/// matching the visual ordering users expect (overdue alerts on top).
///
/// `_refresh` uses the same epoch + try/catch guard as
/// [UnseenNotificationCount] — see that class's doc comment for the reasoning.
final class InboxNotificationsProvider
    extends
        $AsyncNotifierProvider<InboxNotifications, List<NotificationEntity>> {
  /// Sorted list of notifications that belong in the inbox popover.
  ///
  /// "Inbox-worthy" means the same predicate `dueNotificationRows` /
  /// `upcomingNotificationRows` apply at the SQL layer: still unseen, unacted,
  /// and not deleted. The two streams are concatenated due-first then upcoming,
  /// matching the visual ordering users expect (overdue alerts on top).
  ///
  /// `_refresh` uses the same epoch + try/catch guard as
  /// [UnseenNotificationCount] — see that class's doc comment for the reasoning.
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
    r'0a446eb06a5c3fce1341e590927346364d25471e';

/// Sorted list of notifications that belong in the inbox popover.
///
/// "Inbox-worthy" means the same predicate `dueNotificationRows` /
/// `upcomingNotificationRows` apply at the SQL layer: still unseen, unacted,
/// and not deleted. The two streams are concatenated due-first then upcoming,
/// matching the visual ordering users expect (overdue alerts on top).
///
/// `_refresh` uses the same epoch + try/catch guard as
/// [UnseenNotificationCount] — see that class's doc comment for the reasoning.

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
