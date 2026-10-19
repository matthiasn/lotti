### Fixed
- **The close button on agent internals did nothing on a phone.** The sheet's
  invisible drag strip lay across its top edge and caught the tap meant for the
  X, so the only way out was tapping beside the sheet. The X now closes it, and
  a downward swipe still dismisses it. The goal and person agent chats get the
  same fix where they open as a bottom sheet in a narrow window.
