import 'package:flutter/widgets.dart';

/// The minimum window width at which the app switches from mobile layout
/// (bottom navigation bar) to desktop layout (persistent left sidebar).
const kDesktopBreakpoint = 960.0;

/// The minimum available content width at which the Projects overview flows its
/// category sections into two columns, so a wide window is used as a command
/// surface instead of a single column floating in empty side-margins.
const kWideProjectsOverviewBreakpoint = 1100.0;

/// Returns `true` when the current window is wide enough for the desktop
/// layout (sidebar + content area instead of bottom navigation).
bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
