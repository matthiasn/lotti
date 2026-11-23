import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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
}
