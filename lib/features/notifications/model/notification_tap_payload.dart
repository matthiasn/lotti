import 'dart:convert';

import 'package:meta/meta.dart';

/// What an OS notification carries so that a tap can land somewhere.
///
/// The plugin hands the string back verbatim when the user taps, whether the
/// app is running or the tap is what launches it, so everything a tap needs
/// has to be in here: the [route] to open, and — for a synced inbox row — the
/// row's [inboxId], so the tap can mark the row seen the way a tap in the
/// bell does.
///
/// Two wire forms decode. The JSON object is what [encode] writes. A bare
/// route (`/calendar`) is what the producers without an inbox row pass — the
/// Daily OS plan-ready alert, the sync-conflict alert, habit reminders — and
/// what every alarm armed before tap routing existed still carries in the OS
/// queue, so it has to stay decodable rather than become a dead tap on
/// upgrade.
@immutable
final class NotificationTapPayload {
  const NotificationTapPayload({required this.route, this.inboxId});

  /// The app route a tap opens, always starting with `/`.
  final String route;

  /// The synced inbox row the notification projects, when there is one.
  final String? inboxId;

  static const String _routeKey = 'route';
  static const String _inboxIdKey = 'inboxId';

  /// Whether [value] has the shape of an app route.
  static bool isRoute(String value) => value.startsWith('/');

  /// The wire form handed to the plugin as the notification's payload.
  String encode() =>
      jsonEncode(<String, String>{_routeKey: route, _inboxIdKey: ?inboxId});

  /// Reads a payload back, or null when nothing routable is in [raw].
  ///
  /// Lenient about the row and strict about the route: a malformed
  /// [inboxId] is dropped and the tap still opens its screen, because the
  /// screen is what the user tapped for, while a missing or non-route
  /// `route` makes the whole payload unusable.
  static NotificationTapPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (isRoute(raw)) return NotificationTapPayload(route: raw);
    if (!raw.startsWith('{')) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final route = decoded[_routeKey];
    if (route is! String || !isRoute(route)) return null;

    final inboxId = decoded[_inboxIdKey];
    return NotificationTapPayload(
      route: route,
      inboxId: inboxId is String && inboxId.isNotEmpty ? inboxId : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationTapPayload &&
      other.route == route &&
      other.inboxId == inboxId;

  @override
  int get hashCode => Object.hash(route, inboxId);

  @override
  String toString() =>
      'NotificationTapPayload(route: $route, inboxId: $inboxId)';
}
