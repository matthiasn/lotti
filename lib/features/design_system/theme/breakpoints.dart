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

/// The reading measure for a detail column made of *worded action rows* rather
/// than prose — a short list where each row is a few words with a leading glyph
/// and a trailing affordance.
///
/// Deliberately narrower than [kDetailContentMaxWidth]. That measure is sized
/// for body copy; stretched across it, a three-word row puts its trailing
/// glyph most of a window from its label and the list stops reading as a list
/// at all — three horizontal rules instead. Non-binding on a phone, where the
/// column is already narrower than this.
///
/// Used by the task first-run band, which also lends it to the whole content
/// column while it renders so the title field, the chip lane and the band
/// share one right edge.
const kActionListContentMaxWidth = 520.0;
