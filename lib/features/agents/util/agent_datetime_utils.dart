/// Pure date/time helpers shared across the agents feature.
library;

/// Whether [a] and [b] fall on the same calendar day in their own time zone.
///
/// Compares the year, month, and day components only — the time of day is
/// ignored. Both arguments are compared as-is (no UTC normalisation), so they
/// should already be in the same time zone (typically both local).
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
