import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';

/// Service that handles stylish delete operations for AI configurations
///
/// This service provides a unified interface for deleting AI configurations
/// with enhanced Series A quality styling, proper confirmation modals,
/// cascading deletes, and undo functionality.
///
/// **Features:**
/// - Stylish confirmation modals with contextual warnings
/// - Cascading delete for providers (removes associated models)
/// - Enhanced snackbars with undo functionality
/// - Proper error handling and user feedback
/// - Consistent theming across all delete operations
///
/// **Usage:**
/// ```dart
/// final deleteService = AiConfigDeleteService();
///
/// await deleteService.deleteConfig(
///   context: context,
///   ref: ref,
///   config: providerConfig,
/// );
/// ```
class AiConfigDeleteService {
  const AiConfigDeleteService();

  /// Deletes an AI configuration with proper confirmation and feedback
  ///
  /// This method handles the complete delete flow:
  /// 1. Shows confirmation modal
  /// 2. Performs delete operation (with cascading for providers)
  /// 3. Shows success snackbar with undo functionality
  /// 4. Handles errors gracefully
  ///
  /// **Parameters:**
  /// - [context]: BuildContext for navigation and snackbars
  /// - [ref]: WidgetRef for accessing providers
  /// - [config]: The configuration to delete
  ///
  /// **Returns:** True if deletion was successful, false if cancelled or failed
  Future<bool> deleteConfig({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfig config,
  }) async {
    try {
      // Show confirmation modal
      final confirmed = await _showDeleteConfirmation(context, config);
      if (!confirmed) return false;

      if (!context.mounted) return false;

      final repository = ref.read(aiConfigRepositoryProvider);

      // Perform delete operation based on config type
      switch (config) {
        case AiConfigInferenceProvider():
          final result = await repository.deleteInferenceProviderWithModels(
            config.id,
          );
          if (context.mounted) {
            _showProviderDeletedSnackbar(context, ref, config, result);
          }
          return true;

        case AiConfigModel():
          await repository.deleteConfig(config.id);
          if (context.mounted) {
            _showConfigDeletedSnackbar(context, ref, config);
          }
          return true;

        case AiConfigPrompt():
          await repository.deleteConfig(config.id);
          if (context.mounted) {
            _showConfigDeletedSnackbar(context, ref, config);
          }
          return true;

        default:
          throw ArgumentError('Unsupported config type: ${config.runtimeType}');
      }
    } catch (error) {
      if (context.mounted) {
        _showErrorSnackbar(context, config, error);
      }
      return false;
    }
  }

  /// Shows a stylish confirmation modal for delete operations
  Future<bool> _showDeleteConfirmation(
    BuildContext context,
    AiConfig config,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: context.colorScheme.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getDeleteTitle(config),
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colorScheme.errorContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colorScheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This action cannot be undone',
                        style: context.textTheme.titleSmall?.copyWith(
                          color: context.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getDeleteWarning(config),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onErrorContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Configuration details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: context.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _getConfigIcon(config),
                              color: context.colorScheme.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  config.name,
                                  style:
                                      context.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (config.description?.isNotEmpty ??
                                    false) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    config.description!,
                                    style:
                                        context.textTheme.bodySmall?.copyWith(
                                      color:
                                          context.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Show cascade warning for providers
                      if (config is AiConfigInferenceProvider) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.colorScheme.secondary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: context.colorScheme.secondary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Associated models will also be deleted',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: context
                                        .colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: context.colorScheme.onSurfaceVariant),
                ),
              ),
              LottiPrimaryButton(
                onPressed: () => Navigator.of(context).pop(true),
                label: 'Delete',
                icon: Icons.delete_forever_outlined,
                isDestructive: true,
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Shows success snackbar for provider deletion with cascade information
  void _showProviderDeletedSnackbar(
    BuildContext context,
    WidgetRef ref,
    AiConfigInferenceProvider provider,
    CascadeDeletionResult result,
  ) {
    final hasDeletedModels = result.deletedModels.isNotEmpty;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.colorScheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 6),
        dismissDirection: DismissDirection.down,
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main deletion message
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.delete_forever_outlined,
                      color: context.colorScheme.error,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Provider deleted successfully',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),

              // Cascade information
              if (hasDeletedModels) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            color: context.colorScheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${result.deletedModels.length} associated ${result.deletedModels.length == 1 ? 'model' : 'models'} deleted',
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      if (result.deletedModels.length <= 4) ...[
                        const SizedBox(height: 8),
                        ...result.deletedModels.map((model) => Padding(
                              padding: const EdgeInsets.only(left: 24, top: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color:
                                          context.colorScheme.onSurfaceVariant,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      model.name,
                                      style:
                                          context.textTheme.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                        color: context
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ] else ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: Text(
                            '${result.deletedModels.take(2).map((m) => m.name).join(', ')} and ${result.deletedModels.length - 2} more',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: context.colorScheme.primary,
          onPressed: () => _undoProviderDeletion(ref, provider, result),
        ),
      ),
    );
  }

  /// Shows success snackbar for model/prompt deletion
  void _showConfigDeletedSnackbar(
    BuildContext context,
    WidgetRef ref,
    AiConfig config,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.colorScheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 5),
        dismissDirection: DismissDirection.down,
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.delete_forever_outlined,
                color: context.colorScheme.error,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_getConfigTypeName(config)} deleted successfully',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: context.colorScheme.primary,
          onPressed: () => _undoConfigDeletion(ref, config),
        ),
      ),
    );
  }

  /// Shows error snackbar when deletion fails
  void _showErrorSnackbar(
    BuildContext context,
    AiConfig config,
    Object error,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.colorScheme.errorContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.colorScheme.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.error_outline,
                color: context.colorScheme.error,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Failed to delete ${config.name}',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    error.toString(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onErrorContainer
                          .withValues(alpha: 0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Undoes provider deletion by restoring the provider and all its models
  Future<void> _undoProviderDeletion(
    WidgetRef ref,
    AiConfigInferenceProvider provider,
    CascadeDeletionResult result,
  ) async {
    try {
      final repository = ref.read(aiConfigRepositoryProvider);

      // Restore the provider first
      await repository.saveConfig(provider);

      // Restore all deleted models
      for (final model in result.deletedModels) {
        await repository.saveConfig(model);
      }
    } catch (error) {
      // Handle undo errors silently - the config is already deleted
      // Log for debugging purposes in case undo fails consistently
      try {
        getIt<LoggingService>().captureEvent(
          'Undo provider deletion failed: ${provider.name} (${provider.id}), '
          '${result.deletedModels.length} models, error: $error',
          domain: 'AI_CONFIG',
          subDomain: 'DELETE_SERVICE',
          level: InsightLevel.warn,
        );
      } catch (_) {
        // LoggingService not available (e.g., in tests) - ignore
      }
    }
  }

  /// Undoes config deletion by restoring the configuration
  Future<void> _undoConfigDeletion(WidgetRef ref, AiConfig config) async {
    try {
      final repository = ref.read(aiConfigRepositoryProvider);
      await repository.saveConfig(config);
    } catch (error) {
      // Handle undo errors silently - the config is already deleted
      // Log for debugging purposes in case undo fails consistently
      try {
        getIt<LoggingService>().captureEvent(
          'Undo config deletion failed: ${config.name} (${config.id}), '
          'type: ${config.runtimeType}, error: $error',
          domain: 'AI_CONFIG',
          subDomain: 'DELETE_SERVICE',
          level: InsightLevel.warn,
        );
      } catch (_) {
        // LoggingService not available (e.g., in tests) - ignore
      }
    }
  }

  /// Helper methods for UI text and icons
  String _getDeleteTitle(AiConfig config) {
    return switch (config) {
      AiConfigInferenceProvider() => 'Delete Provider',
      AiConfigModel() => 'Delete Model',
      AiConfigPrompt() => 'Delete Prompt',
      _ => 'Delete Configuration',
    };
  }

  String _getDeleteWarning(AiConfig config) {
    return switch (config) {
      AiConfigInferenceProvider() =>
        'This will permanently delete the provider and all associated models.',
      AiConfigModel() =>
        'This will permanently delete the model configuration.',
      AiConfigPrompt() => 'This will permanently delete the prompt template.',
      _ => 'This will permanently delete the configuration.',
    };
  }

  IconData _getConfigIcon(AiConfig config) {
    return switch (config) {
      AiConfigInferenceProvider() => Icons.hub,
      AiConfigModel() => Icons.smart_toy,
      AiConfigPrompt() => Icons.psychology,
      _ => Icons.settings,
    };
  }

  String _getConfigTypeName(AiConfig config) {
    return switch (config) {
      AiConfigInferenceProvider() => 'Provider',
      AiConfigModel() => 'Model',
      AiConfigPrompt() => 'Prompt',
      _ => 'Configuration',
    };
  }
}
