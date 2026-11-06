### Fixed
- **Daily OS could stay on "Here's what I heard." and "Drafting your day"
  forever, without ever reading your check-in.** On startup Daily OS checks its
  saved recordings before processing anything. That check compared each
  recording's time in two different formats, decided they disagreed, and
  stopped, so after your first Daily OS recording on a device, no check-in was
  read and no plan was drafted again. Recordings are now compared correctly,
  one bad recording no longer blocks the others, and processing starts even if
  the check fails.
- **Old check-ins and drafts no longer run late.** Check-in reading, drafting
  and refining still waiting for a day before yesterday are cancelled when
  Daily OS starts, so they don't spend AI runs on days that are over or hold up
  today's plan.
