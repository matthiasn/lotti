import 'package:flutter/widgets.dart';

/// The minimum window width at which the app switches from mobile layout
/// (bottom navigation bar) to desktop layout (persistent left sidebar).
const kDesktopBreakpoint = 960.0;

/// Returns `true` when the current window is wide enough for the desktop
/// layout (sidebar + content area instead of bottom navigation).
bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
