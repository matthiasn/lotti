import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

enum EventStatus {
  tentative,
  planned,
  ongoing,
  completed,
  cancelled,
  postponed,
  rescheduled,
  missed,
}

extension EventStatusX on EventStatus {
  /// Human-readable, localized status label for UI surfaces.
  String localizedLabel(BuildContext context) => switch (this) {
    EventStatus.tentative => context.messages.eventsStatusTentative,
    EventStatus.planned => context.messages.eventsStatusPlanned,
    EventStatus.ongoing => context.messages.eventsStatusOngoing,
    EventStatus.completed => context.messages.eventsStatusCompleted,
    EventStatus.cancelled => context.messages.eventsStatusCancelled,
    EventStatus.postponed => context.messages.eventsStatusPostponed,
    EventStatus.rescheduled => context.messages.eventsStatusRescheduled,
    EventStatus.missed => context.messages.eventsStatusMissed,
  };

  Color get color {
    switch (this) {
      case EventStatus.tentative:
        return Colors.grey;
      case EventStatus.planned:
        return Colors.blue;
      case EventStatus.ongoing:
        return Colors.orange;
      case EventStatus.completed:
        return Colors.green;
      case EventStatus.cancelled:
        return Colors.red;
      case EventStatus.postponed:
        return Colors.yellow;
      case EventStatus.rescheduled:
        return Colors.purple;
      case EventStatus.missed:
        return Colors.red;
    }
  }
}
