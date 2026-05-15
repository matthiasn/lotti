/// Responsive breakpoints for the redesigned AI Settings surfaces.
///
/// Both values are inner-width thresholds measured at the surface that
/// owns the layout (the card list's sliver constraints; the header
/// bar's `LayoutBuilder` constraints), not screen-level `MediaQuery`
/// reads. That way the detail pane width is what drives the switch,
/// not the device.
library;

/// Cross-axis extent at which the card lists on the AI Settings page
/// switch from a single-column stack (mobile / narrow detail pane) to
/// a two-column grid (desktop). Used by `_buildCardList` in
/// `ai_settings_page.dart`.
const double aiSettingsGridColumnBreakpoint = 700;

/// Width at which `AiSettingsHeaderBar` stops fitting the search
/// field + the "+ Add provider" CTA side-by-side and stacks them
/// vertically.
const double aiSettingsHeaderStackBreakpoint = 600;

/// Inner-modal width above which the FTUE result modal switches from
/// the mobile bottom-sheet (CTA fills the row) to the desktop / tablet
/// dialog (CTA pinned to the right edge with a comfortable cap).
const double aiSetupResultDesktopBreakpoint = 480;

/// Cap on the FTUE result modal's CTA width on the desktop / tablet
/// dialog. Below the cap the button hugs the right edge of the modal;
/// above it the button stops stretching so it doesn't read as a
/// form-save bar.
const double aiSetupResultDesktopCtaMaxWidth = 280;
