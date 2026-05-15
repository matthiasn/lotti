import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

/// Undo window for the delete toast. Matches the checklist row's delete
/// pattern so the destructive-undoable feedback feels uniform across the
/// app.
const kAiDeleteToastDuration = Duration(seconds: 5);

/// Dwell time for the error toast. Slightly longer than the success
/// window because the user has to read both the failure title and the
/// underlying error detail before deciding what to do next.
const kAiDeleteErrorToastDuration = Duration(seconds: 6);

/// Service that handles delete operations for AI configurations
///
/// This service provides a unified interface for deleting AI configurations
/// with proper confirmation modals, cascading deletes, and undo functionality.
///
/// **Features:**
/// - Confirmation modals with contextual warnings
/// - Cascading delete for providers (removes associated models)
/// - Design-system toasts with undo functionality
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
  /// 3. Shows success DS toast with undo functionality
  /// 4. Handles errors gracefully
  ///
  /// **Parameters:**
  /// - [context]: BuildContext for navigation and toasts
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
            _showDeletedToast(context, ref, config, cascade: result);
          }
          return true;

        case AiConfigModel():
        case AiConfigPrompt():
        case AiConfigInferenceProfile():
        case AiConfigSkill():
          await repository.deleteConfig(config.id);
          if (context.mounted) {
            _showDeletedToast(context, ref, config);
          }
          return true;
      }
    } catch (error) {
      if (context.mounted) {
        _showErrorToast(context, config, error);
      }
      return false;
    }
  }

  /// Shows a confirmation modal for delete operations
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
                    color: context.colorScheme.errorContainer.withValues(
                      alpha: 0.3,
                    ),
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
                              color: context.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
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
                                  style: context.textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                if (config.description?.isNotEmpty ??
                                    false) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    config.description!,
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(
                                          color: context
                                              .colorScheme
                                              .onSurfaceVariant,
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
                            color: context.colorScheme.secondary.withValues(
                              alpha: 0.1,
                            ),
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
                                        .colorScheme
                                        .onSecondaryContainer,
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
              LottiTertiaryButton(
                onPressed: () => Navigator.of(context).pop(false),
                label: context.messages.cancelButton,
              ),
              LottiPrimaryButton(
                onPressed: () => Navigator.of(context).pop(true),
                label: context.messages.deleteButton,
                icon: Icons.delete_forever_outlined,
                isDestructive: true,
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Shows the design-system toast for a successful delete, with the
  /// checklist-style 5 s undo window. When [cascade] is provided and
  /// non-empty (only for provider deletions) the toast description
  /// lists the model names that were cascaded — the DS toast caps the
  /// description at two lines, so long lists ellipsize naturally.
  void _showDeletedToast(
    BuildContext context,
    WidgetRef ref,
    AiConfig config, {
    CascadeDeletionResult? cascade,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final messages = context.messages;
    final cascadeModels = cascade?.deletedModels ?? const [];
    final description = cascadeModels.isEmpty
        ? null
        : messages.aiDeleteToastCascadeDescription(
            cascadeModels.length,
            cascadeModels.map((m) => m.name).join(', '),
          );

    messenger.showDesignSystemToast(
      tone: DesignSystemToastTone.warning,
      title: _toastTitle(messages, config),
      description: description,
      duration: kAiDeleteToastDuration,
      countdown: true,
      replaceCurrent: true,
      action: ToastAction(
        label: messages.aiDeleteToastUndoAction,
        onPressed: () {
          if (config is AiConfigInferenceProvider && cascade != null) {
            _undoProviderDeletion(ref, config, cascade);
          } else {
            _undoConfigDeletion(ref, config);
          }
          messenger.hideCurrentSnackBar();
        },
      ),
    );
  }

  /// Shows the design-system error toast when a delete operation fails.
  /// Captures the messenger up-front to mirror [_showDeletedToast] —
  /// both paths go through `ScaffoldMessengerState.showDesignSystemToast`
  /// so the invocation style stays uniform across this service.
  void _showErrorToast(BuildContext context, AiConfig config, Object error) {
    ScaffoldMessenger.of(context).showDesignSystemToast(
      tone: DesignSystemToastTone.error,
      title: context.messages.aiDeleteToastErrorTitle(config.name),
      description: error.toString(),
      duration: kAiDeleteErrorToastDuration,
      replaceCurrent: true,
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
      AiConfigInferenceProfile() => 'Delete Profile',
      AiConfigSkill() => 'Delete Skill',
    };
  }

  String _getDeleteWarning(AiConfig config) {
    return switch (config) {
      AiConfigInferenceProvider() =>
        'This will permanently delete the provider and all associated models.',
      AiConfigModel() =>
        'This will permanently delete the model configuration.',
      AiConfigPrompt() => 'This will permanently delete the prompt template.',
      AiConfigInferenceProfile() =>
        'This will permanently delete the inference profile.',
      AiConfigSkill() => 'This will permanently delete the skill.',
    };
  }

  IconData _getConfigIcon(AiConfig config) {
    return switch (config) {
      AiConfigInferenceProvider() => Icons.hub,
      AiConfigModel() => Icons.smart_toy,
      AiConfigPrompt() => Icons.psychology,
      AiConfigInferenceProfile() => Icons.tune,
      AiConfigSkill() => Icons.auto_fix_high,
    };
  }

  String _toastTitle(AppLocalizations messages, AiConfig config) {
    return switch (config) {
      AiConfigInferenceProvider() => messages.aiDeleteToastProviderTitle,
      AiConfigModel() => messages.aiDeleteToastModelTitle,
      AiConfigPrompt() => messages.aiDeleteToastPromptTitle,
      AiConfigInferenceProfile() => messages.aiDeleteToastProfileTitle,
      AiConfigSkill() => messages.aiDeleteToastSkillTitle,
    };
  }
}
