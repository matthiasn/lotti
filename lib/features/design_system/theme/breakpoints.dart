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

/// The reading measure for the unified Goals list: one calm centered column
/// of goal cards whose rows are short worded lines, not prose.
///
/// Deliberately narrower than [kDetailContentMaxWidth] (sized for body copy)
/// and than the Habits page's dashboard band: stretched wider, a goal card's
/// habit rows put their trailing complete button most of a window away from
/// the habit name and the card stops reading as a group. Confirmed at 700 in
/// the "Goals, Unified" design handover. Non-binding below this width.
const kUnifiedGoalsContentMaxWidth = 700.0;

/// The width at which a page header folds its tools (filter tabs, search)
/// from one row beside the title into a second line beneath it — the
/// habits-header breakpoint, shared by the unified Goals header.
const kPageHeaderFoldWidth = 520.0;

/// The goal detail chat drawer's width (design handover §4b: "~400px right
/// overlay") — a non-modal peer surface, not a column the dashboard reflows
/// around.
const kGoalChatDrawerWidth = 400.0;

/// The narrowest row width that can host an inline trailing control (a
/// stepper, say) beside the row's title without starving the title's measure.
/// Below this, the control drops to the row's secondary line.
///
/// 496 is the measured point at which a two-word title, a cadence stepper
/// and a trailing checkbox stop fitting on one 16dp-padded row.
const kRowInlineControlMinWidth = 496.0;

/// The fixed width for a short numeric target input rendered inline beside a
/// row title (a unit-labelled amount, a step count). Wide enough for a
/// five-digit value plus its unit label, narrow enough to leave the row's
/// title its measure.
const kInlineTargetInputWidth = 320.0;
