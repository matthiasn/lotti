import 'package:lotti/classes/journal_entities.dart';

class CalendarEvent {
  CalendarEvent({
    required this.entity,
    this.linkedFrom,
    this.categoryId,
  });

  JournalEntity entity;
  JournalEntity? linkedFrom;

  /// The category ID associated with this calendar event.
  /// Used for privacy filtering - when a category is hidden,
  /// the event still shows the colored box but hides the text.
  String? categoryId;
}
