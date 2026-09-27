### Fixed
- **Starting a task update on one device now ends the other device's
  countdown right away.** With the same task open on two devices, a device
  waited until the other device had finished its update before stopping its
  own countdown, so the countdown kept running even after the new entry had
  arrived. Now the countdown stops as soon as the other device starts an
  update that includes everything this device has, and the summary stops
  showing as outdated once that update finishes. If that update fails, it is
  retried on the device that started it.
