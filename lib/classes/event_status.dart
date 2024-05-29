import 'package:flutter/material.dart';

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
  String get label {
    switch (this) {
      case EventStatus.tentative:
        return 'TENTATIVE';
      case EventStatus.planned:
        return 'PLANNED';
      case EventStatus.ongoing:
        return 'ONGOING';
      case EventStatus.completed:
        return 'COMPLETED';
      case EventStatus.cancelled:
        return 'CANCELLED';
      case EventStatus.postponed:
        return 'POSTPONED';
      case EventStatus.rescheduled:
        return 'RESCHEDULED';
      case EventStatus.missed:
        return 'MISSED';
    }
  }

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
