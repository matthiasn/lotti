import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/prompt_edit_page.dart';

/// Service responsible for handling navigation to AI configuration edit pages
///
/// This service encapsulates all navigation logic for AI settings and provides
/// a clean interface for navigating to different edit pages based on config type.
///
/// **Design Principles:**
/// - Single responsibility: Only handles navigation, no UI or business logic
/// - Type-safe: Uses pattern matching on sealed classes
/// - Consistent: Same navigation pattern for all config types
/// - Testable: Navigation can be mocked and tested
///
/// **Usage:**
/// ```dart
/// final navigationService = AiSettingsNavigationService();
///
/// // Navigate to edit page for any config type
/// await navigationService.navigateToConfigEdit(context, config);
///
/// // Navigate to create new config page
/// await navigationService.navigateToCreateProvider(context);
/// ```
class AiSettingsNavigationService {
  const AiSettingsNavigationService();

  /// Navigates to the appropriate edit page based on the AI configuration type
  ///
  /// This method uses pattern matching to determine the correct edit page
  /// and navigates using a smooth slide transition from right to left.
  ///
  /// **Parameters:**
  /// - [context]: BuildContext for navigation
  /// - [config]: The AI configuration to edit
  ///
  /// **Returns:** Future that completes when navigation finishes
  ///
  /// **Example:**
  /// ```dart
  /// await navigationService.navigateToConfigEdit(context, providerConfig);
  /// // Will navigate to InferenceProviderEditPage with smooth slide transition
  /// ```
  Future<void> navigateToConfigEdit(
    BuildContext context,
    AiConfig config,
  ) async {
    final route = _createEditRouteWithTransition(config);
    await Navigator.of(context).push(route);
  }

  /// Navigates to create a new inference provider
  ///
  /// **Parameters:**
  /// - [context]: BuildContext for navigation
  ///
  /// **Returns:** Future that completes when navigation finishes
  Future<void> navigateToCreateProvider(BuildContext context) async {
    final route = _createSlideRoute(
      builder: (context) => const InferenceProviderEditPage(),
    );
    await Navigator.of(context).push(route);
  }

  /// Navigates to create a new AI model
  ///
  /// **Parameters:**
  /// - [context]: BuildContext for navigation
  ///
  /// **Returns:** Future that completes when navigation finishes
  Future<void> navigateToCreateModel(BuildContext context) async {
    final route = _createSlideRoute(
      builder: (context) => const InferenceModelEditPage(),
    );
    await Navigator.of(context).push(route);
  }

  /// Navigates to create a new AI prompt
  ///
  /// **Parameters:**
  /// - [context]: BuildContext for navigation
  ///
  /// **Returns:** Future that completes when navigation finishes
  Future<void> navigateToCreatePrompt(BuildContext context) async {
    final route = _createSlideRoute(
      builder: (context) => const PromptEditPage(),
    );
    await Navigator.of(context).push(route);
  }

  /// Creates the appropriate route with slide transition based on config type
  ///
  /// This method uses pattern matching on the sealed AiConfig class
  /// to determine which edit page to create with smooth slide animation.
  ///
  /// **Parameters:**
  /// - [config]: The AI configuration to create a route for
  ///
  /// **Returns:** PageRoute with slide transition for the appropriate edit page
  ///
  /// **Throws:**
  /// - [ArgumentError] if config type is not supported
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
      AiConfigPrompt() => _createSlideRoute(
          builder: (context) => PromptEditPage(
            configId: config.id,
          ),
        ),
      _ => throw ArgumentError(
          'Unsupported config type: ${config.runtimeType}',
        ),
    };
  }

  /// Creates a smooth slide transition route with both pages moving
  ///
  /// This method creates a PageRouteBuilder with a custom slide transition where:
  /// - The new page slides in from the right
  /// - The previous page slides out to the left
  /// - Both animations happen simultaneously for a dynamic effect
  ///
  /// **Parameters:**
  /// - [builder]: Widget builder function for the destination page
  ///
  /// **Returns:** PageRoute with smooth bidirectional slide transition
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
        const secondaryEnd = Offset(-0.3, 0); // Slide out partially for depth effect
        
        const curve = Curves.easeInOut;

        // Animation for the incoming page (current page being navigated to)
        final primarySlideAnimation = Tween(
          begin: primaryBegin, 
          end: primaryEnd,
        ).animate(
          CurvedAnimation(parent: animation, curve: curve),
        );

        // Animation for the outgoing page (previous page being left behind)
        final secondarySlideAnimation = Tween(
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

  /// Returns the appropriate page title for create mode based on config type
  ///
  /// This helper method provides consistent titles for create operations.
  ///
  /// **Parameters:**
  /// - [configType]: The type of configuration being created
  ///
  /// **Returns:** Localized title string for the create page
  String getCreatePageTitle(Type configType) {
    if (configType == AiConfigInferenceProvider) {
      return 'Add AI Inference Provider';
    } else if (configType == AiConfigModel) {
      return 'Add AI Model';
    } else if (configType == AiConfigPrompt) {
      return 'Add AI Prompt';
    } else {
      return 'Add AI Configuration';
    }
  }

  /// Returns the appropriate page title for edit mode based on config type
  ///
  /// This helper method provides consistent titles for edit operations.
  ///
  /// **Parameters:**
  /// - [configType]: The type of configuration being edited
  ///
  /// **Returns:** Localized title string for the edit page
  String getEditPageTitle(Type configType) {
    if (configType == AiConfigInferenceProvider) {
      return 'Edit AI Inference Provider';
    } else if (configType == AiConfigModel) {
      return 'Edit AI Model';
    } else if (configType == AiConfigPrompt) {
      return 'Edit AI Prompt';
    } else {
      return 'Edit AI Configuration';
    }
  }

  /// Determines if a config can be edited
  ///
  /// Some configurations might be read-only or system-managed.
  /// This method provides a central place to check editability.
  ///
  /// **Parameters:**
  /// - [config]: The configuration to check
  ///
  /// **Returns:** True if the configuration can be edited
  bool canEditConfig(AiConfig config) {
    // For now, all configs are editable
    // This method provides a place to add business rules in the future
    return true;
  }

  /// Determines if a config can be deleted
  ///
  /// Some configurations might be protected from deletion
  /// (e.g., system defaults, configs in use).
  ///
  /// **Parameters:**
  /// - [config]: The configuration to check
  ///
  /// **Returns:** True if the configuration can be deleted
  bool canDeleteConfig(AiConfig config) {
    // For now, all configs are deletable
    // This method provides a place to add business rules in the future
    return true;
  }
}
