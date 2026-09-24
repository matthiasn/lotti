### Fixed
- **A message to a goal could be answered twice when you use Lotti on more
  than one device.** While the device you typed on was still answering, your
  other devices could pick the same message up and answer it as well. Now only
  the device you typed on answers. If it cannot — the answer failed, or the
  device went away — one of your other devices answers after half an hour,
  and only one.
- **A goal's second report update of the day could run on one device only,
  or not at all.** When new evidence called for another report refresh after
  the day's first one, your other devices ignored the request, so it ran
  only on the device that made it and never if that device was closed for
  good. Every device now sees it, and whichever one is available runs it.
- **A scheduled goal, relationship or daily-briefing update could be lost
  if the app was killed at the wrong moment.** The update was marked done
  before the app had recorded that it still owed it. The app now records it
  first, and a device that restarts after such a crash no longer runs the
  same update twice.
