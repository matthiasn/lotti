import 'package:flutter/widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;

/// Parent URL the AI-settings detail pages return to. Centralised so
/// the per-page back affordance and any deep-link "back" intent agree
/// on the same destination — `/settings/ai` lands on the AI Settings
/// list (Providers tab by default) regardless of mobile vs desktop
/// surface.
const String aiSettingsParentRoute = '/settings/ai';

/// Back affordance shared by the AI-settings detail pages
/// (`AiProviderDetailPage`, `InferenceModelEditPage`,
/// `InferenceProfileDetailPage`).
///
/// On mobile (and any time the detail page was pushed onto the
/// nearest [Navigator] via Beamer's location stack) `Navigator.canPop`
/// is true and we route through [Navigator.maybePop] so any
/// [PopScope]/`WillPopScope` guards on the page (e.g. an unsaved-form
/// confirmation) get a chance to intercept — the system back gesture
/// and the AppBar arrow stay in lockstep, and we never bulldoze
/// unsaved edits.
///
/// On desktop master/detail the page is rendered as a child of
/// `AiPanelDispatch` inside the Settings V2 panel slot — it was
/// **never pushed** onto the panel's Navigator, so `canPop` is false
/// and `maybePop` would be a silent no-op (the user taps Back and
/// nothing happens). In that case we fall back to beaming the parent
/// route, which collapses the panel selection back to the AI Settings
/// list and matches the desktop user's mental model of "back to
/// where I came from".
Future<void> popAiSettingsDetail(BuildContext context) async {
  final navigator = Navigator.maybeOf(context);
  if (navigator != null && navigator.canPop()) {
    // `maybePop` honours any PopScope guard the page may wire up — if
    // the guard returns false (e.g. unsaved-form dialog cancels), the
    // route stays put and we don't fall through to the beam path,
    // which would otherwise discard the user's edits anyway.
    await navigator.maybePop();
    return;
  }
  // Defensive: in widget tests the page is often the [MaterialApp.home]
  // root, so `canPop` is false and there is no live NavService binding.
  // Bail out silently instead of crashing — there is nowhere to go in
  // a single-page test surface, and the production beamer path is
  // exercised by integration tests that register the real NavService.
  if (nav_service.beamToNamedOverride == null &&
      !getIt.isRegistered<nav_service.NavService>()) {
    return;
  }
  nav_service.beamToNamed(aiSettingsParentRoute);
}
