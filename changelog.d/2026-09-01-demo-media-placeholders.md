### Added
- **Sample-data pictures show a blurred preview while they download.** The
  Penguin Logistics demo fetches its 91 cover and attachment images in the
  background, and until now every cover slot sat empty until its file
  arrived. Each image now ships with a ThumbHash — about thirty bytes that
  decode into a soft-focus stand-in with the picture's colours and rough
  composition — drawn in the task list, the task header and the linked-image
  cards the moment the demo opens, and cross-faded into the real picture
  when it lands (or swapped at once when reduced motion is on).

### Fixed
- **On iPhone and iPad, a demo world still downloading its pictures showed
  error boxes instead of covers.** iOS offers no directory watch, and the
  cover widgets asked for one whenever a file was missing; the failure filled
  every cover slot with a giant error box and could bring the app down. The
  widgets now check for the file themselves where the OS cannot watch, and
  fall back the same way when a watch is refused elsewhere.
