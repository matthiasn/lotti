import 'dart:async';

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
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
import 'package:lotti/features/ai/ui/settings/services/ftue_trigger_service.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_settings_back_nav.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_components.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_error_extension.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_pick_provider_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_provider_setup_preview_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_provider_setup_result_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/mlx_audio_model_download_dialog.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:url_launcher/url_launcher.dart';
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

  /// Debounce timer for the live connection verifier. Fires the probe
  /// 600 ms after the user stops typing in the API key or base URL
  /// so we don't hammer the provider on every keystroke. Cancelled
  /// + reset on each input change and in `dispose()`.
  Timer? _connectionVerifyDebounce;

  /// Set once the Fix-flow has actually focused + scrolled the API key
  /// field, so the retry in `build` stops once it has succeeded. The
  /// retry exists because the form's first frame can render a loading
  /// placeholder (when `configId` is set), in which case the API-key
  /// section isn't mounted yet and `_apiKeyFocusNode.context` is null —
  /// a one-shot `addPostFrameCallback` in `initState` would silently
  /// no-op in that case.
  bool _didFocusApiKey = false;

  @override
  void dispose() {
    _connectionVerifyDebounce?.cancel();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  /// Schedule a debounced live verification of the API key against the
  /// provider's `/models` endpoint. The 600 ms window keeps the form
  /// from probing on every keystroke while the user is typing — the
  /// probe fires once the field has been still long enough for the
  /// input to look intentional. Cancels any pending probe so the
  /// latest input wins.
  void _scheduleConnectionVerify({
    required InferenceProviderType providerType,
    required String apiKey,
    required String baseUrl,
  }) {
    _connectionVerifyDebounce?.cancel();
    final controller = ref.read(
      connectionVerifierControllerProvider(providerType).notifier,
    );
    // Invalidate any in-flight probe up front. Cancelling the debounce
    // timer alone leaves an already-started probe alive — its
    // post-await write would briefly render a stale state for the
    // previous credentials until the next debounced probe completes.
    // `invalidate()` bumps the generation guard inside the controller
    // without touching visible state, so the in-flight probe's
    // `myGen != _generation` check drops its result.
    if (apiKey.trim().isEmpty && providerType != InferenceProviderType.ollama) {
      // Empty key → reset the strip to idle so the previous probe's
      // outcome doesn't linger across a clear. `reset()` already bumps
      // the generation guard, so any in-flight probe is invalidated.
      controller.reset();
      return;
    }
    controller.invalidate();
    _connectionVerifyDebounce = Timer(
      const Duration(milliseconds: 600),
      () {
        if (!mounted) return;
        controller.verify(baseUrl: baseUrl, apiKey: apiKey);
      },
    );
  }

  /// Fire the verifier immediately (no debounce) — bound to the
  /// strip's Re-test / Retry buttons so the user gets an instant
  /// response when they explicitly request a probe.
  void _retryConnectionVerify({
    required InferenceProviderType providerType,
    required String apiKey,
    required String baseUrl,
  }) {
    _connectionVerifyDebounce?.cancel();
    ref
        .read(connectionVerifierControllerProvider(providerType).notifier)
        .verify(baseUrl: baseUrl, apiKey: apiKey);
  }

  /// Re-runs every build until the API-key section is actually
  /// mounted (i.e. `_apiKeyFocusNode.context` is non-null), then
  /// requests focus + scrolls into view exactly once. Only fires when
  /// the caller asked for the Fix-flow via `widget.focusApiKey`.
  void _tryFocusApiKey() {
    if (!widget.focusApiKey || _didFocusApiKey || !mounted) return;
    final ctx = _apiKeyFocusNode.context;
    if (ctx == null) return;
    _didFocusApiKey = true;
    _apiKeyFocusNode.requestFocus();
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.2,
    );
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
    // Schedule the Fix-flow focus retry from every build. `initState`'s
    // post-frame callback fires before the form has finished loading
    // its config, when the API-key section isn't mounted yet, so a
    // one-shot retry there silently no-ops; this re-tries after every
    // build until the section appears.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusApiKey());

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

    // Save & continue requires the full form to validate (display
    // name, API key for cloud providers, base URL shape). Save as
    // draft uses the looser check below so the user can persist a
    // partial config and finish later — that's what "draft" means.
    final hasNameForDraft =
        formState != null && formState.name.value.trim().isNotEmpty;
    final canSaveAsDraft =
        widget.configId == null && hasNameForDraft && !_isSaving;

    // Create save handler that can be used by both app bar action and keyboard shortcut.
    // [fireFtueWorkflow] is `false` when the user invokes "Save as draft" from
    // the v5 footer — the row gets persisted but the FTUE preview/result
    // modal flow is skipped so the user can come back later to seed models.
    Future<void> handleSave({bool fireFtueWorkflow = true}) async {
      if (!isFormValid || _isSaving) return;

      setState(() => _isSaving = true);

      try {
        final config = formState.toAiConfig();
        final controller = ref.read(_formProvider.notifier);

        if (widget.configId == null) {
          await controller.addConfig(config);

          // Offer to set up default prompts for supported providers
          // Only show FTUE if this is the first provider of this type
          // AND the caller didn't explicitly opt out (Save as draft).
          if (fireFtueWorkflow &&
              context.mounted &&
              config is AiConfigInferenceProvider) {
            if (config.inferenceProviderType ==
                InferenceProviderType.mlxAudio) {
              await _offerMlxAudioInstall(config);
            } else {
              await _offerFtueSetupIfFirstProvider(config);
            }
          }
        } else {
          await controller.updateConfig(config);
        }

        if (context.mounted) {
          await popAiSettingsDetail(context);
        }
      } catch (error, stackTrace) {
        // Forward the failure to the app's LoggingService so production
        // surfaces it in the insight stream (the rest of the AI feature
        // already routes its `catch` arms through `getIt<LoggingService>()`
        // — see `AiConfigDeleteService._performUndo`). Wrapped in its own
        // try/catch so a missing LoggingService registration in tests
        // does not mask the user-facing toast below.
        try {
          getIt<LoggingService>().captureException(
            error,
            domain: 'AI_CONFIG',
            subDomain: widget.configId == null
                ? 'INFERENCE_PROVIDER_EDIT_PAGE.handleSave.add'
                : 'INFERENCE_PROVIDER_EDIT_PAGE.handleSave.update',
            stackTrace: stackTrace,
          );
        } catch (_) {
          // LoggingService not available (e.g., in tests) — ignore.
        }
        // Surface a toast so the spinner snapping off after a failed
        // addConfig / updateConfig isn't silent — matches the
        // inference profile form's save error UX. The `context.mounted`
        // check here also guards the `context.showToast` /
        // `context.messages` reads against an async-gap rebuild.
        if (context.mounted) {
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

    // Looser save path used by the v5 footer's "Save as draft" button.
    // The user has signalled "I'll come back later" so we persist the
    // partially-filled config (name + provider type are enough — base
    // URL falls back to the provider default, API key may be empty
    // and stays empty until the user returns) and surface a toast so
    // the silent pop doesn't feel like the tap was lost. FTUE
    // workflow is intentionally skipped — no test category, no model
    // seeding, no preview/result modal — that's the whole point of
    // a draft.
    Future<void> handleSaveDraft() async {
      // Both conditions imply formState is non-null:
      //   - canSaveAsDraft was computed with `formState != null`
      //     (folded through `hasNameForDraft`)
      //   - Dart's flow analysis propagates the promotion through
      //     these final boolean locals into the closure body, so
      //     `formState.toAiConfig()` below is sound without a `!`
      //     cast — adding a redundant `formState == null` check
      //     here would trigger an `unnecessary_null_comparison`
      //     warning.
      if (_isSaving || !canSaveAsDraft) return;
      setState(() => _isSaving = true);
      try {
        final config = formState.toAiConfig();
        final controller = ref.read(_formProvider.notifier);
        await controller.addConfig(config);
        if (context.mounted) {
          context.showToast(
            tone: DesignSystemToastTone.success,
            title: context.messages.aiProviderConnectSavedAsDraftToast,
          );
          await popAiSettingsDetail(context);
        }
      } catch (error, stackTrace) {
        try {
          getIt<LoggingService>().captureException(
            error,
            domain: 'AI_CONFIG',
            subDomain: 'INFERENCE_PROVIDER_EDIT_PAGE.handleSaveDraft',
            stackTrace: stackTrace,
          );
        } catch (_) {
          // LoggingService not registered (tests) — ignore.
        }
        if (context.mounted) {
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
    final isCreate = widget.configId == null;
    final providerType = formState?.inferenceProviderType;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          if (isFormValid && !_isSaving) {
            handleSave();
          }
        },
      },
      child: Scaffold(
        // v5 alignment: route the page background through the design
        // tokens (background.level01) so the connect form sits on the
        // same surface as `AiProviderDetailPage`, `AiSettingsPage`,
        // and the rest of the AI surfaces — `colorScheme.surface` is
        // off the design palette and visibly drifts on dark mode.
        backgroundColor: tokens.colors.background.level01,
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // App bar — for create mode the title is the
                  // breadcrumb chip (rendered below as part of the
                  // form chrome), so the bar collapses to a back
                  // arrow only. For edit mode the legacy "Edit
                  // Provider" title remains.
                  SliverAppBar(
                    expandedHeight: isCreate ? kToolbarHeight : 100,
                    pinned: true,
                    backgroundColor: tokens.colors.background.level01,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: context.colorScheme.onSurface,
                        size: 28,
                      ),
                      onPressed: () => popAiSettingsDetail(context),
                    ),
                    flexibleSpace: isCreate
                        ? null
                        : FlexibleSpaceBar(
                            titlePadding: EdgeInsets.only(
                              bottom: tokens.spacing.step5,
                            ),
                            title: Text(
                              context.messages.apiKeyEditPageTitle,
                              style: tokens.typography.styles.heading.heading3
                                  .copyWith(
                                    color: context.colorScheme.onSurface,
                                    fontWeight:
                                        tokens.typography.weight.semiBold,
                                  ),
                            ),
                          ),
                  ),
                  if (isCreate && providerType != null)
                    SliverToBoxAdapter(
                      child: _CreateModeChrome(
                        providerType: providerType,
                        onChooseProvider: () {
                          // Same affordance as the back arrow — the
                          // user wants to revisit the picker. We
                          // pop (or beam to /settings/ai on desktop
                          // where the page lives in a panel slot)
                          // so the FAB handler in the settings page
                          // can re-open the modal.
                          popAiSettingsDetail(context);
                        },
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
            // Fixed bottom bar — create mode uses the v5 three-button
            // footer (Back to providers / Save as draft / Save &
            // continue); edit mode keeps the legacy two-button bar.
            if (isCreate)
              _AddProviderFooterBar(
                onBack: () => popAiSettingsDetail(context),
                onSaveDraft: handleSaveDraft,
                onSaveAndContinue: handleSave,
                canSaveDraft: canSaveAsDraft,
                canSaveAndContinue: isFormValid,
                isSaving: _isSaving,
              )
            else
              FormBottomBar(
                onSave: isFormValid && !_isSaving ? handleSave : null,
                onCancel: () => popAiSettingsDetail(context),
                isFormValid: isFormValid,
                isDirty:
                    widget.configId == null || (formState?.isDirty ?? false),
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
    final isCreate = widget.configId == null;
    final needsApiKey = !ProviderConfig.noApiKeyRequired.contains(
      formState.inferenceProviderType,
    );
    final usesBaseUrl = ProviderConfig.usesBaseUrl(
      formState.inferenceProviderType,
    );
    final apiKeySuffix = IconButton(
      icon: Icon(
        _showApiKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      onPressed: () => setState(() {
        _showApiKey = !_showApiKey;
      }),
      tooltip: _showApiKey
          ? messages.apiKeyHideTooltip
          : messages.apiKeyShowTooltip,
    );

    if (isCreate) {
      // v5 flat-field layout matching the screenshot at
      // /Desktop/Screenshot 2026-05-13 at 17.09.21: caption-above-field
      // rows with right-side hints, the API-key helper link, the
      // privacy hint, and the live `_ConnectionStatusStrip` below
      // Base URL. No `AiFormSection` wrappers — sections collapse to
      // simple stacked fields per the design.
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FlatField(
              label: messages.apiKeyDisplayNameLabel,
              hintRight: messages.aiProviderConnectFieldDisplayNameHint,
              child: AiTextField(
                label: '',
                hint: messages.apiKeyDisplayNameHint,
                controller: formController.nameController,
                onChanged: formController.nameChanged,
                validator: (_) => formState.name.error?.displayMessage,
              ),
            ),
            if (needsApiKey) ...[
              SizedBox(height: tokens.spacing.step6),
              Builder(
                builder: (context) {
                  final consoleUrl = aiProviderKeyConsoleUrl(
                    formState.inferenceProviderType,
                  );
                  return _FlatField(
                    label: messages.apiKeyInputLabel,
                    hintRight: consoleUrl != null
                        ? messages.aiProviderConnectKeyHelperLink(consoleUrl)
                        : null,
                    hintRightTone: _FlatFieldHintTone.link,
                    hintRightUrl: consoleUrl,
                    child: AiTextField(
                      label: '',
                      hint: messages.apiKeyInputHint,
                      controller: formController.apiKeyController,
                      focusNode: _apiKeyFocusNode,
                      onChanged: (value) {
                        formController.apiKeyChanged(value);
                        _scheduleConnectionVerify(
                          providerType: formState.inferenceProviderType,
                          apiKey: value,
                          baseUrl: formController.baseUrlController.text,
                        );
                      },
                      validator: (_) => formState.apiKey.error?.displayMessage,
                      obscureText: !_showApiKey,
                      suffixIcon: apiKeySuffix,
                    ),
                  );
                },
              ),
            ],
            if (usesBaseUrl) ...[
              SizedBox(height: tokens.spacing.step6),
              _FlatField(
                label: messages.aiProviderConnectFieldBaseUrlLabelOptional,
                hintRight: messages.aiProviderConnectFieldBaseUrlHint,
                child: AiTextField(
                  label: '',
                  hint: messages.aiProviderConnectFieldBaseUrlPlaceholder,
                  controller: formController.baseUrlController,
                  onChanged: (value) {
                    formController.baseUrlChanged(value);
                    _scheduleConnectionVerify(
                      providerType: formState.inferenceProviderType,
                      apiKey: formController.apiKeyController.text,
                      baseUrl: value,
                    );
                  },
                  validator: (_) => formState.baseUrl.error?.displayMessage,
                  keyboardType: TextInputType.url,
                ),
              ),
              // Only carve out the gap when the strip below is actually
              // going to render — when no probe has run, the strip
              // collapses to `SizedBox.shrink()` and a fixed gap above
              // it would leave a phantom void of whitespace between the
              // base-URL field and the privacy hint.
              if (ref.watch(
                    connectionVerifierControllerProvider(
                      formState.inferenceProviderType,
                    ),
                  )
                  is! ConnectionCheckIdle)
                SizedBox(height: tokens.spacing.step5),
              _ConnectionStatusStrip(
                providerType: formState.inferenceProviderType,
                onRetest: () => _retryConnectionVerify(
                  providerType: formState.inferenceProviderType,
                  apiKey: formController.apiKeyController.text,
                  baseUrl: formController.baseUrlController.text,
                ),
              ),
            ] else ...[
              SizedBox(height: tokens.spacing.step6),
              _EmbeddedProviderHint(
                providerType: formState.inferenceProviderType,
              ),
            ],
          ],
        ),
      );
    }

    // Edit mode — keep the legacy section-based layout untouched.
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
              _ProviderTypeField(
                label: messages.apiKeyProviderTypeLabel,
                value: formState.inferenceProviderType.displayName(context),
                icon: formState.inferenceProviderType.icon,
                onTap: () => _showProviderTypeModal(context),
              ),
              SizedBox(height: tokens.spacing.step6),
              AiTextField(
                label: messages.apiKeyDisplayNameLabel,
                hint: messages.apiKeyDisplayNameHint,
                controller: formController.nameController,
                onChanged: formController.nameChanged,
                validator: (_) => formState.name.error?.displayMessage,
                prefixIcon: Icons.label_outline_rounded,
              ),
              if (usesBaseUrl) ...[
                SizedBox(height: tokens.spacing.step6),
                AiTextField(
                  label: messages.apiKeyBaseUrlLabel,
                  hint: messages.aiProviderConnectFieldBaseUrlPlaceholder,
                  controller: formController.baseUrlController,
                  onChanged: formController.baseUrlChanged,
                  validator: (_) => formState.baseUrl.error?.displayMessage,
                  keyboardType: TextInputType.url,
                  prefixIcon: Icons.link_rounded,
                ),
              ] else ...[
                SizedBox(height: tokens.spacing.step6),
                _EmbeddedProviderHint(
                  providerType: formState.inferenceProviderType,
                ),
              ],
            ],
          ),
          SizedBox(height: tokens.spacing.step7),

          if (needsApiKey) ...[
            AiFormSection(
              title: messages.apiKeyAuthenticationTitle,
              icon: Icons.security_rounded,
              description: messages.apiKeyAuthenticationDescription,
              children: [
                AiTextField(
                  label: messages.apiKeyInputLabel,
                  hint: messages.apiKeyInputHint,
                  controller: formController.apiKeyController,
                  focusNode: _apiKeyFocusNode,
                  onChanged: formController.apiKeyChanged,
                  validator: (_) => formState.apiKey.error?.displayMessage,
                  obscureText: !_showApiKey,
                  prefixIcon: Icons.key_rounded,
                  suffixIcon: apiKeySuffix,
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

  Future<void> _showProviderTypeModal(BuildContext context) async {
    // Snapshot the type pre-await so the modal opens with the
    // current selection seeded. Safe to capture before the await
    // because the field that invokes this handler is only rendered
    // inside `formContent` (i.e. once `formState` has resolved) —
    // there is no code path where this fires against a loading
    // form. If the form is still loading the seed falls back to
    // the modal's first non-disabled tile.
    final formState = ref.read(_formProvider).value;
    final picked = await AiPickProviderModal.showAllTypes(
      context: context,
      initialSelection: formState?.inferenceProviderType,
    );
    if (picked == null || !mounted) return;
    ref.read(_formProvider.notifier).inferenceProviderTypeChanged(picked);
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

  Future<void> _offerMlxAudioInstall(AiConfigInferenceProvider config) async {
    if (!mounted) return;

    final repository = ref.read(aiConfigRepositoryProvider);
    final allModels = await repository.getConfigsByType(AiConfigType.model);
    final providerModels = allModels
        .whereType<AiConfigModel>()
        .where((m) => m.inferenceProviderId == config.id)
        .where(isMlxAudioSpeechToTextModel)
        .toList(growable: false);
    if (providerModels.isEmpty || !mounted) return;

    final model = await MlxAudioModelInstallChoiceDialog.show(
      context: context,
      models: providerModels,
      recommendedModelId: mlxAudioRecommendedSttModelId,
    );
    if (model == null || !mounted) return;

    await MlxAudioModelDownloadDialog.show(context: context, model: model);
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
              onPressed: () => popAiSettingsDetail(context),
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
    final radius = BorderRadius.circular(tokens.radii.m);
    return Semantics(
      button: true,
      label: label,
      value: value,
      // Wrap the InkWell in a `Material` so the splash paints above
      // the field's opaque surface fill — without it, the
      // `Container.color` inside the InkWell would obscure the ripple.
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: radius,
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step4,
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
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                                fontWeight: tokens.typography.weight.semiBold,
                              ),
                        ),
                        SizedBox(height: tokens.spacing.step1),
                        Text(
                          value,
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
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
        ),
      ),
    );
  }
}

class _EmbeddedProviderHint extends StatelessWidget {
  const _EmbeddedProviderHint({required this.providerType});

  final InferenceProviderType providerType;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final visual = aiProviderVisual(
      type: providerType,
      tokens: tokens,
      messages: context.messages,
    );
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: visual.accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.memory_rounded, color: visual.accent),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              context.messages.aiProviderEmbeddedRuntimeHint,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ],
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
  String _providerName(BuildContext context) => aiProviderDisplayName(
    type: widget.providerType,
    messages: context.messages,
  );

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
        await popAiSettingsDetail(context);
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
          description: messages.aiSetupWizardDescription(
            _providerName(context),
          ),
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
                                  color: context.colorScheme.onPrimaryContainer,
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

/// Container that stacks the create-mode chrome — breadcrumbs, step
/// indicator, and the provider-tinted hero card — above the form.
/// Encapsulates the responsive logic so the build path stays clean:
/// the page just plugs in `_CreateModeChrome(providerType: …)` and the
/// helper picks the right padding + spacing per viewport. Wide
/// (>= 720) viewports keep the breadcrumbs row visible; narrower
/// surfaces drop them because the AppBar leading-back arrow already
/// expresses the same navigation intent.
class _CreateModeChrome extends StatelessWidget {
  const _CreateModeChrome({
    required this.providerType,
    required this.onChooseProvider,
  });

  final InferenceProviderType providerType;
  final VoidCallback onChooseProvider;

  /// Breakpoint above which the breadcrumb row + the tappable
  /// "Choose provider" step are shown. Below this width the AppBar
  /// back-arrow IS the primary back affordance, and showing a second
  /// crumb-row on a phone-sized viewport would just crowd the form.
  static const double _wideBreakpoint = 720;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _wideBreakpoint;
    final providerName = aiProviderDisplayName(
      type: providerType,
      messages: messages,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step6,
        tokens.spacing.step3,
        tokens.spacing.step6,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide) ...[
            _AddProviderBreadcrumbs(providerName: providerName),
            SizedBox(height: tokens.spacing.step4),
          ],
          _AddProviderStepIndicator(
            onChoosePressed: isWide ? onChooseProvider : null,
          ),
          SizedBox(height: tokens.spacing.step5),
          _AddProviderHeaderCard(providerType: providerType),
        ],
      ),
    );
  }
}

/// Compact breadcrumb strip rendered above the form when adding a new
/// provider. Mirrors the desktop reference design:
/// `Settings › AI Settings › Add provider › [provider name]`. On
/// narrow viewports the component truncates earlier crumbs to the
/// available width — the last (provider name) crumb is always visible
/// because it's the most location-specific.
class _AddProviderBreadcrumbs extends StatelessWidget {
  const _AddProviderBreadcrumbs({required this.providerName});

  final String providerName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final activeCaption = caption.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontWeight: tokens.typography.weight.semiBold,
    );
    final separator = Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
      child: Text('›', style: caption),
    );
    return DefaultTextStyle.merge(
      style: caption,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(messages.settingsV2DetailRootCrumb, style: caption),
          separator,
          Text(messages.settingsAiTitle, style: caption),
          separator,
          Text(messages.aiProviderConnectBreadcrumbAdd, style: caption),
          separator,
          Text(providerName, style: activeCaption),
        ],
      ),
    );
  }
}

/// Three-step horizontal indicator: "Choose provider › Connect ›
/// Review". The active step is bold + accent-coloured. The
/// `Choose provider` step renders as a back-affordance link on
/// desktop so the user can jump back to the picker without losing
/// the form state — mobile preserves the same back navigation via
/// the AppBar's leading arrow.
class _AddProviderStepIndicator extends StatelessWidget {
  const _AddProviderStepIndicator({this.onChoosePressed});

  /// Tap callback for the first step. When `null` the step is
  /// rendered as plain text (mobile) — back navigation is handled by
  /// the AppBar arrow, so a duplicate affordance would just be
  /// crowding.
  final VoidCallback? onChoosePressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final inactiveStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final activeStyle = inactiveStyle.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontWeight: tokens.typography.weight.semiBold,
    );
    final separator = Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      child: Icon(
        Icons.chevron_right_rounded,
        size: tokens.spacing.step5,
        color: tokens.colors.text.lowEmphasis,
      ),
    );
    final chooseLabel = messages.aiProviderConnectStepChoose;
    final chooseWidget = onChoosePressed == null
        ? Text(chooseLabel, style: inactiveStyle)
        : Semantics(
            button: true,
            child: InkWell(
              onTap: onChoosePressed,
              borderRadius: BorderRadius.circular(tokens.radii.s),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                  vertical: tokens.spacing.step1,
                ),
                child: Text(chooseLabel, style: inactiveStyle),
              ),
            ),
          );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chooseWidget,
        separator,
        Text(messages.aiProviderConnectStepConnect, style: activeStyle),
        separator,
        Text(messages.aiProviderConnectStepReview, style: inactiveStyle),
      ],
    );
  }
}

/// Provider-tinted hero card sitting above the form fields. Carries
/// the provider's icon in a tinted square + the localised
/// `Connect <provider name>` title + the provider's tagline. The
/// accent + surface come from `aiProviderVisual` so the same
/// per-provider chrome the rest of the AI Settings surface uses is
/// reproduced here without re-declaring colours.
class _AddProviderHeaderCard extends StatelessWidget {
  const _AddProviderHeaderCard({required this.providerType});

  final InferenceProviderType providerType;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final accent = aiProviderAccent(type: providerType, tokens: tokens);
    final surface = aiProviderSurface(type: providerType, tokens: tokens);
    final providerName = aiProviderDisplayName(
      type: providerType,
      messages: messages,
    );
    final tagline = aiProviderTagline(type: providerType, messages: messages);
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step5),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: tokens.spacing.step9,
            height: tokens.spacing.step9,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
            child: Icon(
              aiProviderIcon(providerType),
              color: accent,
              size: tokens.spacing.step7,
            ),
          ),
          SizedBox(width: tokens.spacing.step5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  messages.aiProviderConnectPageTitle(providerName),
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: tokens.typography.weight.semiBold,
                  ),
                ),
                if (tagline.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    tagline,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer action row used in the create flow: Back to providers /
/// Save as draft / Save & continue. The three buttons reflow onto
/// multiple rows on narrow viewports via `Wrap`.
class _AddProviderFooterBar extends StatelessWidget {
  const _AddProviderFooterBar({
    required this.onBack,
    required this.onSaveDraft,
    required this.onSaveAndContinue,
    required this.canSaveDraft,
    required this.canSaveAndContinue,
    required this.isSaving,
  });

  final VoidCallback onBack;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onSaveAndContinue;

  /// Loose gate for the draft button — true as soon as the form has
  /// the minimum fields a draft needs (display name + preselected
  /// provider type). Distinct from [canSaveAndContinue] because the
  /// draft path is allowed to persist a partial config that wouldn't
  /// pass full validation.
  final bool canSaveDraft;

  /// Strict gate for the primary CTA — requires the form to fully
  /// validate (display name, API key for cloud providers, base URL
  /// shape) before the FTUE workflow is allowed to fire.
  final bool canSaveAndContinue;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step6,
        vertical: tokens.spacing.step4,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        border: Border(
          top: BorderSide(
            color: tokens.colors.decorative.level01,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: tokens.spacing.step3,
        runSpacing: tokens.spacing.step3,
        children: [
          DesignSystemButton(
            label: messages.aiProviderConnectBackToProviders,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.large,
            leadingIcon: Icons.arrow_back_rounded,
            onPressed: isSaving ? null : onBack,
          ),
          Wrap(
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step3,
            children: [
              DesignSystemButton(
                label: messages.aiProviderConnectSaveAsDraft,
                variant: DesignSystemButtonVariant.secondary,
                size: DesignSystemButtonSize.large,
                onPressed: canSaveDraft && !isSaving ? onSaveDraft : null,
              ),
              DesignSystemButton(
                label: messages.aiProviderConnectSaveAndContinue,
                size: DesignSystemButtonSize.large,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: canSaveAndContinue && !isSaving
                    ? onSaveAndContinue
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tone for the right-hand hint text in a [_FlatField]. `helper`
/// renders as a low-emphasis caption; `link` renders as an accent-
/// coloured, underlined string. When a `hintRightUrl` is supplied
/// alongside the `link` tone, the hint becomes a real tap target
/// that opens the URL in an external browser.
enum _FlatFieldHintTone { helper, link }

/// Flat row used in the create-mode form: a CAPITAL caption on the
/// left, an optional right-hand hint, and the field widget below.
/// Replaces the legacy `AiFormSection` wrapper for the redesigned
/// connect form so the layout matches the reference screenshot
/// (caption + right-hand hint + field, with no surrounding card).
class _FlatField extends StatelessWidget {
  const _FlatField({
    required this.label,
    required this.child,
    this.hintRight,
    this.hintRightTone = _FlatFieldHintTone.helper,
    this.hintRightUrl,
  });

  final String label;
  final Widget child;
  final String? hintRight;
  final _FlatFieldHintTone hintRightTone;

  /// Optional URL launched when the user taps the right-hand hint.
  /// Only honored when [hintRightTone] is `_FlatFieldHintTone.link`.
  final String? hintRightUrl;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final captionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
      letterSpacing: 1.2,
      fontWeight: tokens.typography.weight.semiBold,
    );
    final isLink = hintRightTone == _FlatFieldHintTone.link;
    final hintStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: isLink
          ? tokens.colors.interactive.enabled
          : tokens.colors.text.mediumEmphasis,
      decoration: isLink && hintRightUrl != null
          ? TextDecoration.underline
          : TextDecoration.none,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label.toUpperCase(), style: captionStyle),
            ),
            if (hintRight != null && hintRight!.isNotEmpty)
              Flexible(child: _buildHintRight(hintStyle)),
          ],
        ),
        SizedBox(height: tokens.spacing.step2),
        child,
      ],
    );
  }

  Widget _buildHintRight(TextStyle style) {
    final text = Text(
      hintRight!,
      style: style,
      textAlign: TextAlign.end,
      overflow: TextOverflow.ellipsis,
    );
    final url = hintRightUrl;
    if (hintRightTone != _FlatFieldHintTone.link || url == null) {
      return text;
    }
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => _launchHintUrl(url),
        mouseCursor: SystemMouseCursors.click,
        child: text,
      ),
    );
  }

  Future<void> _launchHintUrl(String url) async {
    // Console URLs in `aiProviderKeyConsoleUrl` are stored as bare
    // hosts (e.g. `platform.openai.com`) so the rendered hint stays
    // compact. Prepend `https://` when the parsed URI lacks a scheme
    // so the launcher receives a fully-qualified target instead of
    // bailing out on the `hasScheme` guard.
    var uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://$url');
      if (uri == null || !uri.hasScheme) return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Live "Connection check" strip rendered below the Base URL field in
/// create mode. Watches the per-provider
/// [ConnectionVerifierController] state and surfaces one of four
/// faces:
///
/// - [ConnectionCheckIdle]: nothing rendered (the strip slot reserves
///   no vertical space when there is no probe to show — the form
///   stays tight when the user hasn't entered a key).
/// - [ConnectionCheckChecking]: a translucent surface with a
///   `CircularProgressIndicator` and the "Checking key…" caption.
/// - [ConnectionCheckVerified]: a green tinted card with a check icon,
///   the localised "Connection verified · N models · responded in Xms"
///   subtitle, and a Re-test button.
/// - [ConnectionCheckFailedHttp] / [ConnectionCheckFailedNetwork]: a
///   warning-tinted card with the failure reason and a Retry button.
class _ConnectionStatusStrip extends ConsumerWidget {
  const _ConnectionStatusStrip({
    required this.providerType,
    required this.onRetest,
  });

  final InferenceProviderType providerType;
  final VoidCallback onRetest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(
      connectionVerifierControllerProvider(providerType),
    );

    switch (state) {
      case ConnectionCheckIdle():
        return const SizedBox.shrink();

      case ConnectionCheckChecking():
        return _StripShell(
          background: tokens.colors.background.level02,
          border: tokens.colors.decorative.level01,
          child: Row(
            children: [
              SizedBox(
                width: tokens.spacing.step5,
                height: tokens.spacing.step5,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  messages.aiProviderConnectionCheckingLabel,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
            ],
          ),
        );

      case final ConnectionCheckVerified verified:
        final success = tokens.colors.alert.success.defaultColor;
        return _StripShell(
          background: success.withValues(alpha: 0.10),
          border: success.withValues(alpha: 0.32),
          child: Row(
            children: [
              Container(
                width: tokens.spacing.step6,
                height: tokens.spacing.step6,
                decoration: BoxDecoration(
                  color: success,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: tokens.spacing.step5,
                  color: tokens.colors.text.onInteractiveAlert,
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      messages.aiProviderConnectionVerifiedTitle,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: tokens.colors.text.highEmphasis,
                            fontWeight: tokens.typography.weight.semiBold,
                          ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      messages.aiProviderConnectionVerifiedSubtitle(
                        verified.modelCount,
                        verified.latency.inMilliseconds,
                      ),
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              DesignSystemButton(
                label: messages.aiProviderConnectionRetestButton,
                variant: DesignSystemButtonVariant.tertiary,
                onPressed: onRetest,
              ),
            ],
          ),
        );

      case final ConnectionCheckFailedHttp failed:
        return _failedStrip(
          tokens: tokens,
          messages: messages,
          title: messages.aiProviderConnectionFailedTitle(
            aiProviderDisplayName(type: providerType, messages: messages),
          ),
          detail: messages.aiProviderConnectionFailedHttpDetail(
            failed.status,
            failed.message,
          ),
          onRetry: onRetest,
        );

      case final ConnectionCheckFailedNetwork failed:
        // Pick the localized detail string by the failure code so
        // service-layer constants (timeout / invalid base URL / bad
        // response shape) stay l10n-aware. Raw platform exception
        // messages still flow through the generic `network` arm.
        final detail = switch (failed.code) {
          ConnectionFailureCode.timeout =>
            messages.aiProviderConnectionFailedTimeoutDetail,
          ConnectionFailureCode.invalidBaseUrl =>
            messages.aiProviderConnectionFailedInvalidBaseUrlDetail,
          ConnectionFailureCode.badResponseShape =>
            messages.aiProviderConnectionFailedBadResponseDetail(
              failed.message,
            ),
          ConnectionFailureCode.network =>
            messages.aiProviderConnectionFailedNetworkDetail(failed.message),
        };
        return _failedStrip(
          tokens: tokens,
          messages: messages,
          title: messages.aiProviderConnectionFailedTitle(
            aiProviderDisplayName(type: providerType, messages: messages),
          ),
          detail: detail,
          onRetry: onRetest,
        );
    }
  }

  Widget _failedStrip({
    required DsTokens tokens,
    required AppLocalizations messages,
    required String title,
    required String detail,
    required VoidCallback onRetry,
  }) {
    final danger = tokens.colors.alert.error.defaultColor;
    return _StripShell(
      background: danger.withValues(alpha: 0.10),
      border: danger.withValues(alpha: 0.32),
      child: Row(
        children: [
          Container(
            width: tokens.spacing.step6,
            height: tokens.spacing.step6,
            decoration: BoxDecoration(color: danger, shape: BoxShape.circle),
            child: Icon(
              Icons.close_rounded,
              size: tokens.spacing.step5,
              color: tokens.colors.text.onInteractiveAlert,
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: tokens.typography.weight.semiBold,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  detail,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          DesignSystemButton(
            label: messages.aiProviderConnectionRetryButton,
            variant: DesignSystemButtonVariant.tertiary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _StripShell extends StatelessWidget {
  const _StripShell({
    required this.background,
    required this.border,
    required this.child,
  });

  final Color background;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
