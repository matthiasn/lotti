### Fixed
- **Deep backfill now repairs missing and cut-short photos and recordings.**
  When two devices had the same entry, a photo or audio file missing on one of
  them, or only partly received, was never sent again, and a partial file
  stayed partial even when the whole file arrived later. A deep backfill round
  now compares file sizes between devices. It sends each device the largest
  copy any of your devices holds, even with *resend attachments* switched off,
  and a received file never replaces a larger one.
