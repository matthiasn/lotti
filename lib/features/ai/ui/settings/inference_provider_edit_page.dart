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
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

part 'inference_provider_form_create.dart';
part 'inference_provider_form_edit.dart';

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
          getIt<DomainLogger>().error(
            LogDomain.ai,
            error,
            stackTrace: stackTrace,
            subDomain: widget.configId == null
                ? 'INFERENCE_PROVIDER_EDIT_PAGE.handleSave.add'
                : 'INFERENCE_PROVIDER_EDIT_PAGE.handleSave.update',
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
          getIt<DomainLogger>().error(
            LogDomain.ai,
            error,
            stackTrace: stackTrace,
            subDomain: 'INFERENCE_PROVIDER_EDIT_PAGE.handleSaveDraft',
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
