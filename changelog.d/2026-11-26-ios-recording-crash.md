### Fixed
- **Recording audio on iPhone should no longer crash the app.** Since 1.1.104 a
  take on iOS 26 could close the app a few seconds after you started
  speaking, without an error. The recorder had switched on the phone's
  call-style voice processing for every take, which is what set off the
  crash. Recordings on iPhone are made the way they were before 1.1.104
  again, both in the app and in the chat.
