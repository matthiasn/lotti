/// How a stored journal time is read, the same on every device.
///
/// Journal metadata times (`dateFrom`, `createdAt`, `updatedAt`) are written
/// as the writer's local wall-clock components without an offset —
/// `toIso8601String` on a local `DateTime` drops the zone — beside the
/// `utcOffset` the entry was last stamped with. A reader in another zone
/// parses the same components as a different instant, so `.toUtc()` on a
/// stored value names a different moment on every device, and a calendar
/// day taken from that moment is a different day east and west of the
/// writer. Nothing devices must agree on may be read that way
/// (`specs/tla/RelationshipCadence.tla`, ADR 0114).
///
/// Two readings are zone-free, and these are the only two the relationship
/// runtime uses: the calendar day the components name
/// ([relationshipCalendarDay]), which is the day the writer saw on their
/// own calendar, and the instant the writer meant, rebuilt from the
/// components and the stored offset ([relationshipStoredInstant]). Days are
/// midnight-UTC day keys, so day arithmetic is component arithmetic in a
/// calendar without DST: a day is always one day long.
library;

/// The instant a journal time [stored] names on every device.
///
/// The entry's own [utcOffsetMinutes] (the device's offset when the entry
/// was last stamped) turns the stored components back into the instant the
/// writer meant. A value already in UTC, or one without a recorded offset,
/// is taken as it is.
DateTime relationshipStoredInstant(DateTime stored, int? utcOffsetMinutes) {
  if (stored.isUtc || utcOffsetMinutes == null) return stored.toUtc();
  return DateTime.utc(
    stored.year,
    stored.month,
    stored.day,
    stored.hour,
    stored.minute,
    stored.second,
    stored.millisecond,
    stored.microsecond,
  ).subtract(Duration(minutes: utcOffsetMinutes));
}

/// The calendar day [value]'s components name, as a midnight-UTC day key.
///
/// Read off the components, never through `.toUtc()`: a stored journal time
/// then names the writer's calendar day on every device, and a local `now`
/// names the device's own day. A value in UTC names its UTC day — call
/// `toLocal()` first where the local day is meant.
DateTime relationshipCalendarDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

/// The day [cadenceDays] calendar days after [reference]'s day, as a day key.
///
/// Component arithmetic rather than a `Duration`: adding twenty-four hours
/// per day across a DST transition lands an hour off, and across a 23-hour
/// day on the wrong date. The cadence counts days on the calendar.
DateTime relationshipDueDay(DateTime reference, int cadenceDays) {
  final day = relationshipCalendarDay(reference);
  return DateTime.utc(day.year, day.month, day.day + cadenceDays);
}

/// Whole calendar days from [from]'s day to [to]'s day: zero on the same
/// day, positive when [to] is a later day, negative when earlier.
///
/// Counted on day keys, so the 23-hour day of a spring-forward is one day,
/// not zero, and the time of day plays no part.
int relationshipCalendarDaysBetween(DateTime from, DateTime to) =>
    relationshipCalendarDay(
      to,
    ).difference(relationshipCalendarDay(from)).inDays;
