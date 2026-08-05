/// Semantic, anchor-relative dates for the demo world.
///
/// The demo seed is authored as *meaning* ("due today", "overdue by two
/// days", "logged last Tuesday") rather than as calendar literals, so a world
/// seeded in March reads exactly like one seeded in July: due-soon chips are
/// due soon, the overdue ones are overdue, and the journal timeline has
/// entries in the recent past.
///
/// Every value snaps to a whole day plus an explicit hour. That is what keeps
/// the world stable at the edges of the day: a fixture authored as
/// `anchor + 3h` flips into tomorrow when the user opens the demo at 23:00,
/// while [inDays] `(1, 9)` is tomorrow morning whatever time it is now.
class DemoDates {
  const DemoDates(this.now);

  /// The clock the whole world is expressed against — `DateTime.now()` in
  /// production, the fixed manual-screenshot clock in the fixture suites.
  final DateTime now;

  /// [now]'s calendar day, offset by [days], at [hour]:[minute] local time.
  ///
  /// `DateTime`'s constructor normalises out-of-range days, so a negative or
  /// large [days] rolls across month and year boundaries correctly.
  DateTime inDays(int days, int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day + days, hour, minute);

  /// Today at [hour] — the "due today" bucket.
  DateTime today(int hour, [int minute = 0]) => inDays(0, hour, minute);

  /// Tomorrow at [hour] — the "due tomorrow" bucket.
  DateTime tomorrow(int hour) => inDays(1, hour);

  /// [days] before today at [hour]: a due date that is already past.
  ///
  /// Authored at 17:00 by default, and [days] starts at 1 — the guarantee
  /// that the chip cannot read as "due today" (or, worse, as upcoming) no
  /// matter when the world is seeded rests on that, so it is asserted here
  /// rather than left to the call sites.
  DateTime overdue(int days, [int hour = 17]) {
    assert(days >= 1, 'overdue counts whole days back, so days starts at 1');
    return inDays(-days, hour);
  }

  /// [days] before today at [hour] — for `createdAt` and logged work.
  DateTime daysAgo(int days, [int hour = 9]) => inDays(-days, hour);

  /// The next Monday strictly after today, at [hour], optionally shifted by
  /// [plusDays] into that week ("next week" content).
  DateTime nextMonday(int hour, {int plusDays = 0}) =>
      inDays(daysUntilNextMonday + plusDays, hour);

  /// Whole days from today to the next Monday strictly after it (1–7).
  int get daysUntilNextMonday {
    final delta = (DateTime.monday - now.weekday + 7) % 7;
    return delta == 0 ? 7 : delta;
  }

  /// The [n]-th most recent weekday strictly before today, at [hour].
  ///
  /// Logged work lands on working days, so a demo world seeded on a Monday
  /// does not show three sessions tracked over the weekend.
  DateTime pastWeekday(int n, [int hour = 9]) {
    assert(n >= 1, 'pastWeekday counts back from today, so n starts at 1');
    var found = 0;
    for (var back = 1; back <= n * 2 + 7; back++) {
      final day = inDays(-back, hour);
      if (day.weekday <= DateTime.friday && ++found == n) return day;
    }
    // Unreachable: at least five weekdays occur in any seven-day window, so
    // n weekdays are always found within 2n+7 days.
    throw StateError('No weekday found $n days back from $now');
  }
}
