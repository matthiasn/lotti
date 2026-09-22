# Services

Process-wide services registered in GetIt before any widget exists: logging,
change notification, time tracking, navigation, notifications, entity caching,
vector clocks, geolocation and window management.

These are the things that must exist for the whole life of the process and cannot
be scoped to a widget tree.

## How it works

- **Startup order and the GetIt/Riverpod boundary** —
  [knowledge/architecture/bootstrap-and-di.md](../../knowledge/architecture/bootstrap-and-di.md)
- **The logging stack**: domains, the domain-aware entry point, and the buffered
  file sink —
  [knowledge/architecture/logging-and-diagnostics.md](../../knowledge/architecture/logging-and-diagnostics.md)
- **Device location**: platform routing, the native sources on each platform,
  permission and the IP fallback —
  [knowledge/architecture/device-location.md](../../knowledge/architecture/device-location.md)
- **Change notification** and the three update streams —
  [knowledge/architecture/persistence.md](../../knowledge/architecture/persistence.md)
