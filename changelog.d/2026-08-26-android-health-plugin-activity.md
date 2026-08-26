### Fixed
- **Health import on Android never connected to Health Connect.** The plugin
  that talks to Health Connect refused to load on every app start — the
  Android activity Lotti ran in was not the kind it needs — so the Health
  import page had no working platform side beneath it on Android. It loads
  now, and the import works the way it does on iOS.
