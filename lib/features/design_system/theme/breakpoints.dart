import 'package:flutter/widgets.dart';

/// The minimum window width at which the app switches from mobile layout
/// (bottom navigation bar) to desktop layout (persistent left sidebar).
const kDesktopBreakpoint = 960.0;

/// Returns `true` when the current window is wide enough for the desktop
/// layout (sidebar + content area instead of bottom navigation).
bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

/// The shared reading measure for detail-page content (tasks, logbook
/// entries): body columns cap at this width on wide windows so lines stay
/// readable instead of running the full pane. Non-binding below this width.
///
/// 960 (widened from 760): at 760, the AI summary card's footer (wake
/// status/countdown chip beside the "Automatische Aktualisierungen" label +
/// switch) didn't have room to stay on one line in German, wrapping into an
/// unbalanced two-row layout.
const kDetailContentMaxWidth = 960.0;
