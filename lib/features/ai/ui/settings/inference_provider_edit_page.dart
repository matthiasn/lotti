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
import 'package:lotti/features/ai/ui/settings/services/ftue_trigger_service.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_components.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_error_extension.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_provider_setup_preview_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_provider_setup_result_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_type_selection_modal.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:uuid/uuid.dart';

/// Runs the FTUE setup for the given provider type.
///
/// Returns an [AiFtueResult] subtype, or null if the provider type has no
/// FTUE wired in. Any `providerModelId` in [excludedProviderModelIds] is
/// skipped end-to-end — no row is created, so the result's
/// `modelsCreated` count reflects exactly what landed in the database
/// (no post-hoc deletion needed).
Future<AiFtueResult?> runFtueSetupForType({
  required BuildContext context,
  required WidgetRef ref,
  required InferenceProviderType providerType,
  required AiConfigInferenceProvider config,
  required ProviderPromptSetupService setupService,
  Set<String> excludedProviderModelIds = const {},
}) async {
  return switch (providerType) {
    InferenceProviderType.alibaba => setupService.performAlibabaFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
    ),
    InferenceProviderType.anthropic => setupService.performAnthropicFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
    ),
    InferenceProviderType.gemini => setupService.performGeminiFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
    ),
    InferenceProviderType.ollama => setupService.performOllamaFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
    ),
    InferenceProviderType.openAi => setupService.performOpenAiFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
    ),
    InferenceProviderType.mistral => setupService.performMistralFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
    ),
    _ => null,
  };
}

/// Performs the full FTUE setup workflow: preview, setup, and result.
///
/// 1. Opens `AiProviderSetupPreviewModal` so the user can untick proposed
///    models before they're created. Already-configured models for the
///    same provider show in a read-only section so re-running the wizard
///    doesn't pretend they're new. Providers without an FTUE preset
///    (Ollama) skip this modal entirely.
/// 2. Runs `runFtueSetupForType` with the unticked set as
///    `excludedProviderModelIds` — the per-provider helpers skip every
///    excluded `providerModelId` at creation time, so the success-modal
///    model count reflects exactly what landed in the database.
/// 3. Opens `AiProviderSetupResultModal` with the FTUE result and
///    returns the action the user picked.
///
/// Returns the [AiProviderSetupResultAction] the user chose in the
/// result modal, or `null` if the workflow was cancelled or skipped
/// before the result modal opened. Callers decide whether to act on
/// the chosen action (e.g. pop the page on `startUsingAi`).
Future<AiProviderSetupResultAction?> performFtueSetupWorkflow({
  required BuildContext context,
  required WidgetRef ref,
  required InferenceProviderType providerType,
  required AiConfigInferenceProvider config,
  required ProviderPromptSetupService setupService,
  required String providerName,
  required bool Function() isMounted,
}) async {
  final preview = await AiProviderSetupPreviewModal.show(
    context: context,
    ref: ref,
    providerType: providerType,
    providerId: config.id,
  );

  if (!preview.confirmed || !isMounted()) return null;

  final result = await runFtueSetupForType(
    // ignore: use_build_context_synchronously
    context: context,
    ref: ref,
    providerType: providerType,
    config: config,
    setupService: setupService,
    excludedProviderModelIds: preview.excludedProviderModelIds,
  );

  if (result == null || !isMounted()) return null;

  return AiProviderSetupResultModal.showFor(
    // ignore: use_build_context_synchronously
    context: context,
    result: result,
  );
}

class InferenceProviderEditPage extends ConsumerStatefulWidget {
  const InferenceProviderEditPage({
    this.configId,
    this.preselectedType,
    this.focusApiKey = false,
    super.key,
  });

  final String? configId;

  /// If provided, pre-selects this provider type for new providers.
  /// Only used when configId is null (creating a new provider).
  final InferenceProviderType? preselectedType;

  /// When `true`, the form focuses the API key field on first frame and
  /// scrolls it into view. Used by the provider card's "Fix" affordance
  /// (invalid-key status) so the user lands directly on the field that
  /// needs editing instead of scanning the form.
  final bool focusApiKey;

  @override
  ConsumerState<InferenceProviderEditPage> createState() =>
      _InferenceProviderEditPageState();
}

class _InferenceProviderEditPageState
    extends ConsumerState<InferenceProviderEditPage> {
  bool _showApiKey = false;
  bool _isSaving = false;
  final FocusNode _apiKeyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.focusApiKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _apiKeyFocusNode.requestFocus();
        // Without this the field can sit below the fold on small
        // viewports — focus alone does not scroll the SliverAppBar
        // collapsed. Best-effort: only acts if the FocusNode is
        // attached (i.e. the API-key section is actually mounted for
        // this provider type).
        final ctx = _apiKeyFocusNode.context;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.2,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  /// Helper to get the form controller provider with correct parameters
  InferenceProviderFormControllerProvider get _formProvider =>
      inferenceProviderFormControllerProvider(
        configId: widget.configId,
        preselectedType: widget.configId == null
            ? widget.preselectedType
            : null,
      );

  @override
  Widget build(BuildContext context) {
    // Listen for the config if editing an existing one
    final configAsync = widget.configId != null
        ? ref.watch(aiConfigByIdProvider(widget.configId!))
        : const AsyncData<AiConfig?>(null);

    // Watch the form state to enable/disable save button
    final formState = ref.watch(_formProvider).value;

    final isFormValid =
        formState != null &&
        formState.isValid &&
        (widget.configId == null || formState.isDirty);

    // Create save handler that can be used by both app bar action and keyboard shortcut
    Future<void> handleSave() async {
      if (!isFormValid || _isSaving) return;

      setState(() => _isSaving = true);

      try {
        final config = formState.toAiConfig();
        final controller = ref.read(_formProvider.notifier);

        if (widget.configId == null) {
          await controller.addConfig(config);

          // Offer to set up default prompts for supported providers
          // Only show FTUE if this is the first provider of this type
          if (context.mounted && config is AiConfigInferenceProvider) {
            await _offerFtueSetupIfFirstProvider(config);
          }
        } else {
          await controller.updateConfig(config);
        }

        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } catch (_) {
        // Surface a toast so the spinner snapping off after a failed
        // addConfig / updateConfig isn't silent — matches the
        // inference profile form's save error UX.
        if (mounted) {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.commonError,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }

    final tokens = context.designTokens;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          if (isFormValid && !_isSaving) {
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
                      titlePadding: EdgeInsets.only(
                        bottom: tokens.spacing.step5,
                      ),
                      title: Text(
                        widget.configId == null
                            ? context.messages.apiKeyAddPageTitle
                            : context.messages.apiKeyEditPageTitle,
                        style: tokens.typography.styles.heading.heading3
                            .copyWith(
                              color: context.colorScheme.onSurface,
                              fontWeight: tokens.typography.weight.semiBold,
                            ),
                      ),
                    ),
                  ),
                  // Form Content
                  SliverToBoxAdapter(
                    child: switch (configAsync) {
                      AsyncData(value: final config) => _buildForm(
                        context,
                        ref,
                        config,
                        formState,
                        isFormValid,
                        handleSave,
                      ),
                      AsyncError() => _buildErrorState(context),
                      _ => Center(
                        child: Padding(
                          padding: EdgeInsets.all(tokens.spacing.step9),
                          child: const CircularProgressIndicator(),
                        ),
                      ),
                    },
                  ),
                ],
              ),
            ),
            // Fixed bottom bar
            FormBottomBar(
              onSave: isFormValid && !_isSaving ? handleSave : null,
              onCancel: () => Navigator.of(context).pop(),
              isFormValid: isFormValid,
              isDirty: widget.configId == null || (formState?.isDirty ?? false),
              isLoading: _isSaving,
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
    final tokens = context.designTokens;
    final messages = context.messages;
    if (formState == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step9),
          child: const CircularProgressIndicator(),
        ),
      );
    }

    final formController = ref.read(_formProvider.notifier);

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step6),
      child: Column(
        children: [
          // Provider Configuration Section
          AiFormSection(
            title: messages.apiKeyProviderConfigTitle,
            icon: Icons.settings_rounded,
            description: messages.apiKeyProviderConfigDescription,
            children: [
              // Provider Type Selection — read-only field. Uses a
              // gesture-tappable styled box (no `TextEditingController`)
              // so we don't allocate a fresh controller on every rebuild.
              _ProviderTypeField(
                label: messages.apiKeyProviderTypeLabel,
                value: formState.inferenceProviderType.displayName(context),
                icon: formState.inferenceProviderType.icon,
                onTap: () => _showProviderTypeModal(context),
              ),
              SizedBox(height: tokens.spacing.step6),

              // Display Name
              AiTextField(
                label: messages.apiKeyDisplayNameLabel,
                hint: messages.apiKeyDisplayNameHint,
                controller: formController.nameController,
                onChanged: formController.nameChanged,
                validator: (_) => formState.name.error?.displayMessage,
                prefixIcon: Icons.label_outline_rounded,
              ),
              SizedBox(height: tokens.spacing.step6),

              // Base URL
              AiTextField(
                label: messages.apiKeyBaseUrlLabel,
                hint: 'https://api.example.com',
                controller: formController.baseUrlController,
                onChanged: formController.baseUrlChanged,
                validator: (_) => formState.baseUrl.error?.displayMessage,
                keyboardType: TextInputType.url,
                prefixIcon: Icons.link_rounded,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step7),

          // Authentication Section - Only show for providers that require API key
          if (!ProviderConfig.noApiKeyRequired.contains(
            formState.inferenceProviderType,
          )) ...[
            AiFormSection(
              title: messages.apiKeyAuthenticationTitle,
              icon: Icons.security_rounded,
              description: messages.apiKeyAuthenticationDescription,
              children: [
                // API Key
                AiTextField(
                  label: messages.apiKeyInputLabel,
                  hint: messages.apiKeyInputHint,
                  controller: formController.apiKeyController,
                  focusNode: _apiKeyFocusNode,
                  onChanged: formController.apiKeyChanged,
                  validator: (_) => formState.apiKey.error?.displayMessage,
                  obscureText: !_showApiKey,
                  prefixIcon: Icons.key_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showApiKey
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    onPressed: () => setState(() {
                      _showApiKey = !_showApiKey;
                    }),
                    tooltip: _showApiKey
                        ? messages.apiKeyHideTooltip
                        : messages.apiKeyShowTooltip,
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step6),
          ],

          // Available Models Section - Only show when editing existing provider
          if (widget.configId != null)
            _AvailableModelsSection(
              providerId: widget.configId!,
              providerType: formState.inferenceProviderType,
            ),

          // AI Setup Section - Only show for supported providers when editing
          if (widget.configId != null &&
              ftueSupportedProviderTypes.contains(
                formState.inferenceProviderType,
              ))
            _AiSetupSection(
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

  /// Offers FTUE setup if this is the first provider of the given type.
  ///
  /// This ensures users get the full setup experience when adding a new
  /// provider type (e.g., adding Mistral after already having Gemini),
  /// but avoids redundant prompts when adding additional providers of
  /// the same type.
  Future<void> _offerFtueSetupIfFirstProvider(
    AiConfigInferenceProvider config,
  ) async {
    if (!mounted) return;

    final ftueTriggerService = ref.read(ftueTriggerServiceProvider.notifier);

    // Check if FTUE should be triggered for this provider
    final triggerResult = await ftueTriggerService.shouldTriggerFtue(config);

    switch (triggerResult) {
      case FtueTriggerResult.skipNotFirstProvider:
      case FtueTriggerResult.skipUnsupportedProvider:
        return;

      case FtueTriggerResult.shouldShowFtue:
        // Continue to show FTUE based on provider type
        break;
    }

    if (!mounted) return;

    // Perform FTUE setup for supported provider types
    await _performFtueSetupForProvider(config: config);
  }

  /// Performs FTUE setup flow for a supported provider.
  ///
  /// Shows the confirmation dialog, runs the appropriate setup, and displays
  /// the result dialog.
  Future<void> _performFtueSetupForProvider({
    required AiConfigInferenceProvider config,
  }) async {
    final providerName = config.inferenceProviderType.ftueDisplayName;
    if (providerName == null) return;

    final setupService = ref.read(providerPromptSetupServiceProvider);

    await performFtueSetupWorkflow(
      context: context,
      ref: ref,
      providerType: config.inferenceProviderType,
      config: config,
      setupService: setupService,
      providerName: providerName,
      isMounted: () => mounted,
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(tokens.spacing.step5),
              decoration: BoxDecoration(
                color: context.colorScheme.errorContainer.withValues(
                  alpha: 0.2,
                ),
                borderRadius: BorderRadius.circular(tokens.radii.l),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: tokens.spacing.step9,
                color: context.colorScheme.error,
              ),
            ),
            SizedBox(height: tokens.spacing.step6),
            Text(
              messages.apiKeyEditLoadError,
              style: tokens.typography.styles.body.bodyLarge.copyWith(
                color: context.colorScheme.onSurface,
                fontWeight: tokens.typography.weight.semiBold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              messages.apiKeyEditLoadErrorRetry,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing.step6),
            LottiSecondaryButton(
              label: messages.apiKeyEditGoBackButton,
              onPressed: () => Navigator.of(context).pop(),
              icon: Icons.arrow_back_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only field used to surface the currently-selected provider type
/// inside the form. Tapping anywhere on the field opens the provider
/// type modal. Implemented as a styled box (no `TextEditingController`)
/// so we don't allocate a new controller per build the way an
/// `AbsorbPointer(AiTextField(...))` pattern would.
class _ProviderTypeField extends StatelessWidget {
  const _ProviderTypeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      button: true,
      label: label,
      value: value,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step5,
            vertical: tokens.spacing.step4,
          ),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: tokens.spacing.step6,
                color: context.colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        fontWeight: tokens.typography.weight.semiBold,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      value,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: context.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ],
          ),
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
    final tokens = context.designTokens;
    final messages = context.messages;
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
            SizedBox(height: tokens.spacing.step4),
            AiFormSection(
              title: messages.apiKeyAvailableModelsTitle,
              icon: Icons.psychology_rounded,
              description: messages.apiKeyAvailableModelsDescription,
              children: [
                ...knownModels.map((knownModel) {
                  final isAdded = existingModelIds.contains(
                    knownModel.providerModelId,
                  );
                  return Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.step4),
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
      loading: () => Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step6),
          child: const CircularProgressIndicator(),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
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
    final tokens = context.designTokens;
    final messages = context.messages;
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
            : context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(
          color: widget.isAdded
              ? context.colorScheme.primary.withValues(alpha: 0.3)
              : context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model icon
            Container(
              width: tokens.spacing.step8,
              height: tokens.spacing.step8,
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
                borderRadius: BorderRadius.circular(tokens.radii.s),
              ),
              child: Icon(
                _getModelIcon(),
                size: tokens.spacing.step6,
                color: widget.isAdded
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),

            SizedBox(width: tokens.spacing.step4),

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
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
                                fontWeight: tokens.typography.weight.semiBold,
                                color: context.colorScheme.onSurface,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isAdded) ...[
                        SizedBox(width: tokens.spacing.step3),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing.step3,
                            vertical: tokens.spacing.step1,
                          ),
                          decoration: BoxDecoration(
                            color: context.colorScheme.primary,
                            borderRadius: BorderRadius.circular(tokens.radii.s),
                          ),
                          child: Text(
                            messages.aiSettingsAddedLabel,
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: context.colorScheme.onPrimary,
                                  fontWeight: tokens.typography.weight.semiBold,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  SizedBox(height: tokens.spacing.step2),

                  // Description
                  Text(
                    widget.knownModel.description,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: tokens.spacing.step3),

                  // Modalities
                  Wrap(
                    spacing: tokens.spacing.step2,
                    runSpacing: tokens.spacing.step2,
                    children: [
                      _ModalityChip(
                        label: messages.apiKeyKnownModelInputLabel(
                          inputModalities,
                        ),
                        icon: Icons.input_rounded,
                      ),
                      _ModalityChip(
                        label: messages.apiKeyKnownModelOutputLabel(
                          outputModalities,
                        ),
                        icon: Icons.output_rounded,
                      ),
                      if (widget.knownModel.isReasoningModel)
                        _ModalityChip(
                          label: messages.aiSettingsReasoningLabel,
                          icon: Icons.psychology_alt_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: tokens.spacing.step3),

            // Add button
            if (!widget.isAdded)
              IconButton(
                onPressed: _isAdding ? null : _addModel,
                icon: _isAdding
                    ? SizedBox(
                        width: tokens.spacing.step6,
                        height: tokens.spacing.step6,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colorScheme.primary,
                        ),
                      )
                    : Container(
                        width: tokens.spacing.step7,
                        height: tokens.spacing.step7,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.colorScheme.primaryContainer,
                              context.colorScheme.primaryContainer.withValues(
                                alpha: 0.7,
                              ),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: tokens.spacing.step3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: tokens.spacing.step5,
                          color: context.colorScheme.primary,
                        ),
                      ),
                tooltip: messages.aiSettingsAddModelTooltip,
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

/// Section for manually triggering AI setup (models, prompts, category).
class _AiSetupSection extends ConsumerStatefulWidget {
  const _AiSetupSection({
    required this.providerId,
    required this.providerType,
  });

  final String providerId;
  final InferenceProviderType providerType;

  @override
  ConsumerState<_AiSetupSection> createState() => _AiSetupSectionState();
}

class _AiSetupSectionState extends ConsumerState<_AiSetupSection> {
  bool _isRunning = false;

  /// Resolves the user-facing provider name through `aiProviderDisplayName`
  /// so the FTUE workflow surfaces use the localised brand name (e.g.
  /// "Google Gemini") and not the English-only `ftueDisplayName` constant.
  String _providerName(BuildContext context) =>
      aiProviderDisplayName(type: widget.providerType, messages: context.messages);

  Future<void> _runFtueSetup() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
    });

    try {
      final repository = ref.read(aiConfigRepositoryProvider);
      final setupService = ref.read(providerPromptSetupServiceProvider);

      // Get the provider config
      final config = await repository.getConfigById(widget.providerId);
      if (config == null || config is! AiConfigInferenceProvider) {
        return;
      }

      if (!mounted) return;

      final action = await performFtueSetupWorkflow(
        context: context,
        ref: ref,
        providerType: widget.providerType,
        config: config,
        setupService: setupService,
        providerName: _providerName(context),
        isMounted: () => mounted,
      );

      // "Start using AI" exits the setup flow — pop the edit page so the
      // user lands back at the settings list instead of staring at the
      // provider form they just re-ran the wizard from.
      if (action == AiProviderSetupResultAction.startUsingAi && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: tokens.spacing.step7),
        AiFormSection(
          title: messages.aiSetupWizardTitle,
          icon: Icons.auto_awesome_rounded,
          description: messages.aiSetupWizardDescription(_providerName(context)),
          children: [
            Container(
              padding: EdgeInsets.all(tokens.spacing.step5),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(tokens.radii.m),
                border: Border.all(
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(tokens.spacing.step3),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(tokens.radii.s),
                        ),
                        child: Icon(
                          Icons.settings_suggest_rounded,
                          color: context.colorScheme.primary,
                          size: tokens.spacing.step6,
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              messages.aiSetupWizardRunLabel,
                              style: tokens.typography.styles.subtitle.subtitle2
                                  .copyWith(
                                    color: context.colorScheme.onSurface,
                                    fontWeight:
                                        tokens.typography.weight.semiBold,
                                  ),
                            ),
                            SizedBox(height: tokens.spacing.step1),
                            Text(
                              messages.aiSetupWizardCreatesOptimized,
                              style: tokens.typography.styles.body.bodySmall
                                  .copyWith(
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  // Info about idempotency
                  Container(
                    padding: EdgeInsets.all(tokens.spacing.step4),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer.withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(tokens.radii.s),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: tokens.spacing.step5,
                          color: context.colorScheme.primary,
                        ),
                        SizedBox(width: tokens.spacing.step3),
                        Expanded(
                          child: Text(
                            messages.aiSetupWizardSafeToRunMultiple,
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color:
                                      context.colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  // Run button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isRunning ? null : _runFtueSetup,
                      icon: _isRunning
                          ? SizedBox(
                              width: tokens.spacing.step5,
                              height: tokens.spacing.step5,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colorScheme.onPrimary,
                              ),
                            )
                          : Icon(
                              Icons.auto_awesome,
                              size: tokens.spacing.step5,
                            ),
                      label: Text(
                        _isRunning
                            ? messages.aiSetupWizardRunningButton
                            : messages.aiSetupWizardRunButton,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: tokens.spacing.step4,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
