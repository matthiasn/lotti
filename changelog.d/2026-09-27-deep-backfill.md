### Added
- **A deep backfill in sync maintenance brings devices that drifted apart
  back together.** Ordinary repair can only ask for gaps a device can name,
  so history an older installation never recorded stayed missing for good.
  *Settings → Sync → Maintenance → Deep backfill* sends your other devices a
  list of every entry, link, agent record, notification and usage record on
  this device, deletions included. Each one compares the list with its own
  records, asks for what it is missing and sends back what this device
  lacks, so both sides end up with everything either had. Entries edited on
  two devices at once come back as a conflict for you to resolve, never
  silently overwritten.
