import 'package:flutter/scheduler.dart';

/// Applies [write] — a `BeamLocation.buildPages` mirroring the current route
/// into a `NavService` notifier — at a moment the framework allows.
///
/// Beamer calls `buildPages` from its delegate's `build`, and the notifiers
/// mirrored there drive `ValueListenableBuilder`s that sit *beside* the
/// delegate in the desktop shell (the sidebar's Time Analysis and AI Impact
/// entries), not above it. Notifying them synchronously is therefore a
/// `setState() called during build` — an assertion in debug builds and a
/// skipped rebuild otherwise. During a build the write is deferred to the end
/// of the frame; outside one (a location built directly, as its unit tests
/// do) it applies at once, so the URL remains the single writer either way.
///
/// The other route mirrors — `desktopSelectedEntryId`, `ProjectId`,
/// `DashboardId`, `SettingsRoute` — stay synchronous on purpose: their
/// listeners are the split-pane pages *inside* the delegate's navigator (a
/// descendant may be marked dirty while its ancestor builds), and the settings
/// tree's URL sync defers past the frame on its own side.
void mirrorRouteState(void Function() write) {
  final phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((_) => write());
    return;
  }
  write();
}
