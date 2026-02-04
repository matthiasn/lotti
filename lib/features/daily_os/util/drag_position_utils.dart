/// Section-local position utilities for planned block drag operations.
///
/// All functions operate within a single visible section (startHour to endHour)
/// using the standard hourHeight (40px/hour). These utilities do NOT handle
/// folded timeline coordinates - they assume a simple linear mapping within
/// a single visible section.
///
/// For folded-global coordinates, use `timeline_folding_utils.dart` instead.
library;

/// Callback for when drag state changes.
typedef DragActiveChangedCallback = void Function({required bool isDragging});

/// Height in pixels for one hour in the timeline.
const double kHourHeight = 40;

/// Height of resize handles on desktop (pointer input).
const double kResizeHandleHeightDesktop = 12;

/// Height of resize handles on touch devices (larger touch targets).
const double kResizeHandleHeightTouch = 20;

/// Minimum block duration in minutes.
const int kMinimumBlockMinutes = 15;

/// Minimum block height (in pixels) for resize handles to be active.
/// Blocks shorter than this use move-only mode.
const double kMinimumBlockHeightForResize = 48;

/// Default snap grid interval in minutes.
const int kSnapToMinutes = 5;

/// Haptic feedback interval in minutes (fires when crossing these boundaries).
const int kHapticFeedbackMinutes = 15;

/// Maximum minutes in a day (24 * 60).
const int kMaxMinutesInDay = 24 * 60;

/// Converts a DateTime to minutes from the start of the given [date].
///
/// The conversion is based on the calendar date difference (in UTC) and the
/// wall-clock hour/minute values. This makes `24:00` representable as next-day
/// `00:00` (i.e., 1440 minutes) without being affected by DST transitions.
///
/// Values outside 0-1440 are clamped.
int minutesFromDate(DateTime date, DateTime time) {
  final baseUtc = DateTime.utc(date.year, date.month, date.day);
  final timeUtc = DateTime.utc(time.year, time.month, time.day);
  final dayOffset = timeUtc.difference(baseUtc).inDays;

  final minutes = dayOffset * kMaxMinutesInDay + time.hour * 60 + time.minute;
  return minutes.clamp(0, kMaxMinutesInDay);
}

/// Converts a Y position within a section to minutes from midnight.
///
/// [localY] is the Y position relative to the section's top edge.
/// [sectionStartHour] is the hour where the section begins.
///
/// Returns minutes from midnight (0-1440).
int positionToMinutes(double localY, int sectionStartHour) {
  final minutesFromSectionStart = (localY / kHourHeight * 60).round();
  return sectionStartHour * 60 + minutesFromSectionStart;
}

/// Converts minutes from midnight to a Y position within a section.
///
/// [minutes] is the time in minutes from midnight (0-1440).
/// [sectionStartHour] is the hour where the section begins.
///
/// Returns the Y position relative to the section's top edge.
double minutesToPosition(int minutes, int sectionStartHour) {
  final minutesFromSectionStart = minutes - (sectionStartHour * 60);
  return minutesFromSectionStart * kHourHeight / 60;
}

/// Snaps minutes to the nearest grid interval.
///
/// [minutes] is the raw time in minutes from midnight.
/// [gridMinutes] is the snap interval (default 5 minutes).
///
/// Returns minutes snapped to the nearest grid point, clamped to 0-1440.
int snapToGrid(int minutes, {int gridMinutes = kSnapToMinutes}) {
  final snapped = (minutes / gridMinutes).round() * gridMinutes;
  return snapped.clamp(0, kMaxMinutesInDay);
}

/// Clamps minutes to section bounds.
///
/// [minutes] is the time in minutes from midnight.
/// [sectionStartHour] is the hour where the section begins.
/// [sectionEndHour] is the hour where the section ends.
///
/// Returns minutes clamped to the section's time range.
int clampToSection(int minutes, int sectionStartHour, int sectionEndHour) {
  final minMinutes = sectionStartHour * 60;
  final maxMinutes = sectionEndHour * 60;
  return minutes.clamp(minMinutes, maxMinutes);
}

/// Calculates the delta in minutes from a Y position delta.
///
/// [deltaY] is the change in Y position (pixels).
///
/// Returns the corresponding change in minutes.
int deltaToMinutes(double deltaY) {
  return (deltaY / kHourHeight * 60).round();
}

/// Formats minutes from midnight as a time string (HH:MM).
///
/// [minutes] is the time in minutes from midnight (0-1440).
///
/// Returns a string like "09:15" or "14:30".
/// Handles 1440 (end of day) as "24:00" for timeline display.
String formatMinutesAsTime(int minutes) {
  // Handle end-of-day boundary explicitly
  if (minutes >= kMaxMinutesInDay) {
    return '24:00';
  }
  final hours = (minutes ~/ 60).clamp(0, 23);
  final mins = minutes % 60;
  return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
}

/// Formats a duration in minutes as a human-readable string.
///
/// [minutes] is the duration in minutes.
///
/// Returns a string like "1h 30m" or "45m".
String formatDurationMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;

  if (hours == 0) {
    return '${mins}m';
  } else if (mins == 0) {
    return '${hours}h';
  } else {
    return '${hours}h ${mins}m';
  }
}
