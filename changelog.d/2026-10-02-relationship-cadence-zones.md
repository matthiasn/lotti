### Fixed
- **A person's check-in reminders and briefings could come a day early or
  late, or twice, when you use Lotti in more than one time zone.** A
  check-in logged near midnight counted as a different day on a device in
  another zone, so the two devices kept overwriting each other's view of
  when the person was next due and each paid for its own briefing. Every
  device now counts from the day on the calendar where the check-in was
  logged, and the reminder, the people list and the briefing agree on that
  day.
- **Adding a comment, recording or photo to a check-in from a device in
  another time zone left the briefing out of date for good.** The change
  was read as older than the briefing it should have refreshed. It now
  refreshes the briefing wherever it was made.
- **A briefing written on one device could be refreshed again, needlessly,
  by a device in another time zone.** Briefings are now stamped so every
  device reads the same moment.
- **In the people list, someone a day over their cadence read as due today
  on the morning the clocks sprang forward.** Days over are counted on the
  calendar, so the short night no longer costs a day.
