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
  /// and navigates using imperative navigation (Navigator.push).
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
  /// // Will navigate to InferenceProviderEditPage with the provider's ID
  /// ```
  Future<void> navigateToConfigEdit(
    BuildContext context,
    AiConfig config,
  ) async {
    final route = _createEditRoute(config);
    await Navigator.of(context).push(route);
  }

  /// Navigates to create a new inference provider
  ///
  /// **Parameters:**
  /// - [context]: BuildContext for navigation
  ///
  /// **Returns:** Future that completes when navigation finishes
  Future<void> navigateToCreateProvider(BuildContext context) async {
    final route = MaterialPageRoute<void>(
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
    final route = MaterialPageRoute<void>(
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
    final route = MaterialPageRoute<void>(
      builder: (context) => const PromptEditPage(),
    );
    await Navigator.of(context).push(route);
  }

  /// Creates the appropriate MaterialPageRoute based on config type
  ///
  /// This method uses pattern matching on the sealed AiConfig class
  /// to determine which edit page to create.
  ///
  /// **Parameters:**
  /// - [config]: The AI configuration to create a route for
  ///
  /// **Returns:** MaterialPageRoute for the appropriate edit page
  ///
  /// **Throws:**
  /// - [ArgumentError] if config type is not supported
  MaterialPageRoute<void> _createEditRoute(AiConfig config) {
    return switch (config) {
      AiConfigInferenceProvider() => MaterialPageRoute<void>(
          builder: (context) => InferenceProviderEditPage(
            configId: config.id,
          ),
        ),
      AiConfigModel() => MaterialPageRoute<void>(
          builder: (context) => InferenceModelEditPage(
            configId: config.id,
          ),
        ),
      AiConfigPrompt() => MaterialPageRoute<void>(
          builder: (context) => PromptEditPage(
            configId: config.id,
          ),
        ),
      _ => throw ArgumentError(
          'Unsupported config type: ${config.runtimeType}',
        ),
    };
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
