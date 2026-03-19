import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';

/// Service responsible for handling navigation to AI configuration edit pages
///
/// This service encapsulates all navigation logic for AI settings and provides
/// a clean interface for navigating to different edit pages based on config type.
class AiSettingsNavigationService {
  const AiSettingsNavigationService();

  /// Navigates to the appropriate edit page based on the AI configuration type
  Future<void> navigateToConfigEdit(
    BuildContext context,
    AiConfig config,
  ) async {
    final route = _createEditRouteWithTransition(config);
    await Navigator.of(context).push(route);
  }

  /// Navigates to create a new inference provider
  Future<void> navigateToCreateProvider(
    BuildContext context, {
    InferenceProviderType? preselectedType,
  }) async {
    final route = _createSlideRoute(
      builder: (context) => InferenceProviderEditPage(
        preselectedType: preselectedType,
      ),
    );
    await Navigator.of(context).push(route);
  }

  /// Navigates to create a new AI model
  Future<void> navigateToCreateModel(BuildContext context) async {
    final route = _createSlideRoute(
      builder: (context) => const InferenceModelEditPage(),
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

  /// Creates the appropriate route with slide transition based on config type
  PageRoute<void> _createEditRouteWithTransition(AiConfig config) {
    return switch (config) {
      AiConfigInferenceProvider() => _createSlideRoute(
        builder: (context) => InferenceProviderEditPage(
          configId: config.id,
        ),
      ),
      AiConfigModel() => _createSlideRoute(
        builder: (context) => InferenceModelEditPage(
          configId: config.id,
        ),
      ),
      AiConfigInferenceProfile() => _createSlideRoute(
        builder: (context) => InferenceProfileForm(existingProfile: config),
      ),
      // Prompts and skills are not editable through the settings UI.
      AiConfigPrompt() || AiConfigSkill() => _createSlideRoute(
        builder: (_) => const SizedBox.shrink(),
      ),
    };
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
