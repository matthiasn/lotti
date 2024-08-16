import 'package:lotti/classes/journal_entities.dart';

class CalendarEvent {
  CalendarEvent({
    required this.entity,
    this.linkedFrom,
  });

  JournalEntity entity;
  JournalEntity? linkedFrom;
}
