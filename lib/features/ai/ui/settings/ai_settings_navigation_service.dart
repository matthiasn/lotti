import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/widgets/nav_bar/bottom_nav_safe_navigator.dart';

/// Service responsible for handling navigation to AI configuration edit pages
///
/// This service encapsulates all navigation logic for AI settings and provides
/// a clean interface for navigating to different edit pages based on config type.
class AiSettingsNavigationService {
  const AiSettingsNavigationService();

  /// Navigates to the appropriate edit page based on the AI
  /// configuration type. Provider / model / profile rows all beam to
  /// a per-kind URL so the Settings V2 desktop master/detail surface
  /// swaps the right pane in place. Prompt and skill rows aren't
  /// editable through the settings UI today — they fall back to the
  /// legacy no-op slide route.
  Future<void> navigateToConfigEdit(
    BuildContext context,
    AiConfig config,
  ) async {
    switch (config) {
      case AiConfigInferenceProvider(:final id):
        await navigateToProviderDetail(context, providerId: id);
      case AiConfigModel(:final id):
        nav_service.beamToNamed('/settings/ai/model/$id');
      case AiConfigInferenceProfile(:final id):
        nav_service.beamToNamed('/settings/ai/profile/$id');
      case AiConfigPrompt() || AiConfigSkill():
        // Not editable through the settings UI — preserve the existing
        // no-op behavior so callers that hit this branch don't crash.
        await Navigator.of(context).push(
          _createSlideRoute(builder: (_) => const SizedBox.shrink()),
        );
    }
  }

  /// Navigates to the provider detail page via Beamer. When
  /// [focusApiKey] is true, the URL carries `?focusApiKey=true` so the
  /// detail page auto-routes to the edit form with the API key field
  /// focused — the Fix-flow entry point used by the provider card's
  /// invalid-key affordance.
  ///
  /// Using Beamer (instead of `Navigator.push`) is what makes desktop
  /// master/detail work: the URL change drives the `AiPanelDispatch`
  /// inside the AI panel registry entry, which swaps the right-pane
  /// content in place. On mobile, Beamer pushes the detail page on
  /// top of the AI Settings page in the standard page stack so back
  /// navigation keeps working.
  ///
  /// The [context] argument is unused — Beamer reads its delegate
  /// from the singleton `NavService` — but kept on the signature so
  /// the call site stays symmetric with the other `navigateTo…`
  /// methods and tests can stub a `BuildContext` without special
  /// casing.
  Future<void> navigateToProviderDetail(
    BuildContext context, {
    required String providerId,
    bool focusApiKey = false,
  }) async {
    final path = focusApiKey
        ? '/settings/ai/provider/$providerId?focusApiKey=true'
        : '/settings/ai/provider/$providerId';
    nav_service.beamToNamed(path);
  }

  /// Navigates to create a new inference provider
  Future<void> navigateToCreateProvider(
    BuildContext context, {
    InferenceProviderType? preselectedType,
  }) async {
    await _pushEditorForm(
      context,
      builder: (context) => InferenceProviderEditPage(
        preselectedType: preselectedType,
      ),
    );
  }

  /// Opens the provider edit form for an existing provider on top of
  /// the current page. Unlike [navigateToProviderDetail] this uses
  /// Navigator.push so the edit form overlays the detail page in both
  /// desktop and mobile modes — the user expects a back-gesture to
  /// return to the detail view they came from. Centralised here so the
  /// detail page doesn't reach for `Navigator.push` directly and tests
  /// can stub navigation through the service.
  Future<void> navigateToProviderEdit(
    BuildContext context, {
    required String providerId,
    bool focusApiKey = false,
  }) async {
    await _pushEditorForm(
      context,
      builder: (context) => InferenceProviderEditPage(
        configId: providerId,
        focusApiKey: focusApiKey,
      ),
    );
  }

  /// Navigates to the model create form. When [preselectedProviderId]
  /// is supplied, the new form's owning provider is pre-filled — used
  /// when the call site already has a provider context, e.g. "Add
  /// Model" from inside a provider's detail page. The top-level
  /// "+ Add model" FAB calls without an id and the user must pick
  /// the provider manually.
  Future<void> navigateToCreateModel(
    BuildContext context, {
    String? preselectedProviderId,
  }) async {
    final route = _createSlideRoute(
      builder: (context) => InferenceModelEditPage(
        preselectedProviderId: preselectedProviderId,
      ),
    );
    await Navigator.of(context).push(route);
  }

  /// Navigates to create a new inference profile
  Future<void> navigateToCreateProfile(BuildContext context) async {
    final route = _createSlideRoute(
      builder: (context) => const InferenceProfileForm(),
    );
    await Navigator.of(context).push(route);
  }

  /// Pushes a full-screen AI-settings editor form (the provider connect /
  /// edit form) so its sticky save bar stays reachable.
  ///
  /// On mobile the app shell paints a floating bottom navigation bar as an
  /// overlay on top of each tab's page stack (see `beamer_app.dart`). A form
  /// pushed onto the *nested* tab navigator therefore has its bottom save bar
  /// hidden behind that pill — the original "couldn't save the provider" bug.
  /// [bottomNavSafeNavigatorOf] returns the root navigator on mobile, lifting
  /// the whole form above the shell (including the bottom nav) so the save
  /// action always clears the bottom edge. On desktop there is no bottom nav
  /// and the form overlays only the settings panel, so it stays nested.
  Future<void> _pushEditorForm(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return bottomNavSafeNavigatorOf(
      context,
    ).push(_createSlideRoute(builder: builder));
  }

  /// Creates a smooth slide transition route with both pages moving
  PageRoute<void> _createSlideRoute({
    required Widget Function(BuildContext) builder,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Primary transition: new page slides in from right
        const primaryBegin = Offset(1, 0);
        const primaryEnd = Offset.zero;

        // Secondary transition: old page slides out to left
        const secondaryBegin = Offset.zero;
        const secondaryEnd = Offset(
          -0.3,
          0,
        ); // Slide out partially for depth effect

        const curve = Curves.easeInOut;

        // Animation for the incoming page (current page being navigated to)
        final primarySlideAnimation =
            Tween(
              begin: primaryBegin,
              end: primaryEnd,
            ).animate(
              CurvedAnimation(parent: animation, curve: curve),
            );

        // Animation for the outgoing page (previous page being left behind)
        final secondarySlideAnimation =
            Tween(
              begin: secondaryBegin,
              end: secondaryEnd,
            ).animate(
              CurvedAnimation(parent: secondaryAnimation, curve: curve),
            );

        // Fade effect for extra polish on the incoming page
        final fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.8, curve: Curves.easeIn),
          ),
        );

        // Stack both transitions: outgoing page behind, incoming page in front
        return Stack(
          children: [
            // Background: Previous page sliding out to the left
            SlideTransition(
              position: secondarySlideAnimation,
              child: Container(
                color: Theme.of(context).colorScheme.surface,
              ),
            ),

            // Foreground: New page sliding in from the right with fade
            SlideTransition(
              position: primarySlideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
