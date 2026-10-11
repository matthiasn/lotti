### Fixed
- **Devices still on an older version end up with your latest settings.**
  An older version applied feature flags and AI settings in whatever order
  they arrived, so a late, outdated change could win there. Updated devices
  now send the current value again whenever they see that happening.
- **Entries deleted and cleaned up by an older version no longer come
  back.** When another device still held such an entry, it could reappear
  after a full resync; it is now recognised and kept away.
- **Photos and recordings you delete are also removed on devices that have
  not updated yet**, instead of leaving their files behind.
- **A few tasks, AI responses and people created on an older version now
  reach your other devices** without having to be edited first.
