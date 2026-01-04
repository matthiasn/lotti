import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/model/modality_extensions.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/settings/inference_provider_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/form_bottom_bar.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_components.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_error_extension.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_type_selection_modal.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:uuid/uuid.dart';

class InferenceProviderEditPage extends ConsumerStatefulWidget {
  const InferenceProviderEditPage({
    this.configId,
    super.key,
  });

  final String? configId;

  @override
  ConsumerState<InferenceProviderEditPage> createState() =>
      _InferenceProviderEditPageState();
}

class _InferenceProviderEditPageState
    extends ConsumerState<InferenceProviderEditPage> {
  bool _showApiKey = false;

  @override
  Widget build(BuildContext context) {
    // Listen for the config if editing an existing one
    final configAsync = widget.configId != null
        ? ref.watch(aiConfigByIdProvider(widget.configId!))
        : const AsyncData<AiConfig?>(null);

    // Watch the form state to enable/disable save button
    final formState = ref
        .watch(
            inferenceProviderFormControllerProvider(configId: widget.configId))
        .value;

    final isFormValid = formState != null &&
        formState.isValid &&
        (widget.configId == null || formState.isDirty);

    // Create save handler that can be used by both app bar action and keyboard shortcut
    Future<void> handleSave() async {
      if (!isFormValid) return;

      final config = formState.toAiConfig();
      final controller = ref.read(
        inferenceProviderFormControllerProvider(
          configId: widget.configId,
        ).notifier,
      );

      if (widget.configId == null) {
        await controller.addConfig(config);

        // Offer to set up default prompts for supported providers
        if (context.mounted && config is AiConfigInferenceProvider) {
          final setupService = ref.read(providerPromptSetupServiceProvider);
          await setupService.offerPromptSetup(
            context: context,
            ref: ref,
            provider: config,
          );
        }
      } else {
        await controller.updateConfig(config);
      }

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          if (isFormValid) {
            handleSave();
          }
        },
      },
      child: Scaffold(
        backgroundColor: context.colorScheme.surface,
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Clean App Bar
                  SliverAppBar(
                    expandedHeight: 100,
                    pinned: true,
                    backgroundColor: context.colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: context.colorScheme.onSurface,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(bottom: 16),
                      title: Text(
                        widget.configId == null
                            ? context.messages.apiKeyAddPageTitle
                            : context.messages.apiKeyEditPageTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  // Form Content
                  SliverToBoxAdapter(
                    child: switch (configAsync) {
                      AsyncData(value: final config) => _buildForm(context, ref,
                          config, formState, isFormValid, handleSave),
                      AsyncError() => _buildErrorState(context),
                      _ => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    },
                  ),
                ],
              ),
            ),
            // Fixed bottom bar
            FormBottomBar(
              onSave: isFormValid ? handleSave : null,
              onCancel: () => Navigator.of(context).pop(),
              isFormValid: isFormValid,
              isDirty: widget.configId == null || (formState?.isDirty ?? false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    WidgetRef ref,
    AiConfig? config,
    InferenceProviderFormState? formState,
    bool isFormValid,
    Future<void> Function() handleSave,
  ) {
    if (formState == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final formController = ref.read(
      inferenceProviderFormControllerProvider(configId: widget.configId)
          .notifier,
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Provider Configuration Section
          AiFormSection(
            title: 'Provider Configuration',
            icon: Icons.settings_rounded,
            description: 'Configure your AI inference provider settings',
            children: [
              // Provider Type Selection
              GestureDetector(
                onTap: () => _showProviderTypeModal(context),
                child: AbsorbPointer(
                  child: AiTextField(
                    label: 'Provider Type',
                    hint: 'Select a provider type',
                    readOnly: true,
                    controller: TextEditingController(
                      text:
                          formState.inferenceProviderType.displayName(context),
                    ),
                    prefixIcon: formState.inferenceProviderType.icon,
                    suffixIcon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Display Name
              AiTextField(
                label: 'Display Name',
                hint: 'Enter a friendly name',
                controller: formController.nameController,
                onChanged: formController.nameChanged,
                validator: (_) => formState.name.error?.displayMessage,
                prefixIcon: Icons.label_outline_rounded,
              ),
              const SizedBox(height: 20),

              // Base URL
              AiTextField(
                label: 'Base URL',
                hint: 'https://api.example.com',
                controller: formController.baseUrlController,
                onChanged: formController.baseUrlChanged,
                validator: (_) => formState.baseUrl.error?.displayMessage,
                keyboardType: TextInputType.url,
                prefixIcon: Icons.link_rounded,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Authentication Section - Only show for providers that require API key
          if (!ProviderConfig.noApiKeyRequired
              .contains(formState.inferenceProviderType)) ...[
            AiFormSection(
              title: 'Authentication',
              icon: Icons.security_rounded,
              description: 'Secure your API connection',
              children: [
                // API Key
                AiTextField(
                  label: 'API Key',
                  hint: 'Enter your API key',
                  controller: formController.apiKeyController,
                  onChanged: formController.apiKeyChanged,
                  validator: (_) => formState.apiKey.error?.displayMessage,
                  obscureText: !_showApiKey,
                  prefixIcon: Icons.key_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showApiKey
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                    onPressed: () => setState(() {
                      _showApiKey = !_showApiKey;
                    }),
                    tooltip: _showApiKey ? 'Hide API Key' : 'Show API Key',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Available Models Section - Only show when editing existing provider
          if (widget.configId != null)
            _AvailableModelsSection(
              providerId: widget.configId!,
              providerType: formState.inferenceProviderType,
            ),
        ],
      ),
    );
  }

  void _showProviderTypeModal(BuildContext context) {
    ProviderTypeSelectionModal.show(
      context: context,
      configId: widget.configId,
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    context.colorScheme.errorContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: context.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.messages.apiKeyEditLoadError,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again or contact support',
              style: TextStyle(
                fontSize: 14,
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            LottiSecondaryButton(
              label: 'Go Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icons.arrow_back_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

/// Section showing available known models that can be added to this provider.
class _AvailableModelsSection extends ConsumerWidget {
  const _AvailableModelsSection({
    required this.providerId,
    required this.providerType,
  });

  final String providerId;
  final InferenceProviderType providerType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knownModels = knownModelsByProvider[providerType] ?? [];

    if (knownModels.isEmpty) {
      return const SizedBox.shrink();
    }

    // Watch all configured models to check which are already added
    final allModelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.model),
    );

    return allModelsAsync.when(
      data: (allModels) {
        // Get models already configured for this provider
        final existingModelIds = allModels
            .whereType<AiConfigModel>()
            .where((m) => m.inferenceProviderId == providerId)
            .map((m) => m.providerModelId)
            .toSet();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            AiFormSection(
              title: 'Available Models',
              icon: Icons.psychology_rounded,
              description: 'Quick-add preconfigured models for this provider',
              children: [
                ...knownModels.map((knownModel) {
                  final isAdded =
                      existingModelIds.contains(knownModel.providerModelId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _KnownModelTile(
                      knownModel: knownModel,
                      providerId: providerId,
                      isAdded: isAdded,
                    ),
                  );
                }),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Tile displaying a known model with an add button or "Added" indicator.
class _KnownModelTile extends ConsumerStatefulWidget {
  const _KnownModelTile({
    required this.knownModel,
    required this.providerId,
    required this.isAdded,
  });

  final KnownModel knownModel;
  final String providerId;
  final bool isAdded;

  @override
  ConsumerState<_KnownModelTile> createState() => _KnownModelTileState();
}

class _KnownModelTileState extends ConsumerState<_KnownModelTile> {
  bool _isAdding = false;

  Future<void> _addModel() async {
    if (_isAdding) return;

    setState(() {
      _isAdding = true;
    });

    try {
      final repository = ref.read(aiConfigRepositoryProvider);
      final modelId = const Uuid().v4();
      final config = widget.knownModel.toAiConfigModel(
        id: modelId,
        inferenceProviderId: widget.providerId,
      );
      await repository.saveConfig(config);
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  IconData _getModelIcon() {
    // Check for image generation capability
    if (widget.knownModel.outputModalities.contains(Modality.image)) {
      return Icons.palette_rounded;
    }
    // Check for audio input (transcription)
    if (widget.knownModel.inputModalities.contains(Modality.audio)) {
      return Icons.mic_rounded;
    }
    // Reasoning model
    if (widget.knownModel.isReasoningModel) {
      return Icons.psychology_alt_rounded;
    }
    // Default
    return Icons.smart_toy_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final inputModalities = widget.knownModel.inputModalities
        .map((m) => m.displayName(context))
        .join(', ');
    final outputModalities = widget.knownModel.outputModalities
        .map((m) => m.displayName(context))
        .join(', ');

    return Container(
      decoration: BoxDecoration(
        color: widget.isAdded
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.1)
            : context.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isAdded
              ? context.colorScheme.primary.withValues(alpha: 0.3)
              : context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isAdded
                      ? [
                          context.colorScheme.primary.withValues(alpha: 0.2),
                          context.colorScheme.primary.withValues(alpha: 0.1),
                        ]
                      : [
                          context.colorScheme.surfaceContainerHighest,
                          context.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.7),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getModelIcon(),
                size: 20,
                color: widget.isAdded
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(width: 12),

            // Model info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.knownModel.name,
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isAdded) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            context.messages.aiSettingsAddedLabel,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Description
                  Text(
                    widget.knownModel.description,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.8),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Modalities
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _ModalityChip(
                        label: 'In: $inputModalities',
                        icon: Icons.input_rounded,
                      ),
                      _ModalityChip(
                        label: 'Out: $outputModalities',
                        icon: Icons.output_rounded,
                      ),
                      if (widget.knownModel.isReasoningModel)
                        _ModalityChip(
                          label: context.messages.aiSettingsReasoningLabel,
                          icon: Icons.psychology_alt_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Add button
            if (!widget.isAdded)
              IconButton(
                onPressed: _isAdding ? null : _addModel,
                icon: _isAdding
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colorScheme.primary,
                        ),
                      )
                    : Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.colorScheme.primaryContainer,
                              context.colorScheme.primaryContainer
                                  .withValues(alpha: 0.7),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.colorScheme.primary
                                  .withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: context.colorScheme.primary,
                        ),
                      ),
                tooltip: context.messages.aiSettingsAddModelTooltip,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small chip showing modality info.
class _ModalityChip extends StatelessWidget {
  const _ModalityChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:
            context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color:
                  context.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontSize: 9,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
