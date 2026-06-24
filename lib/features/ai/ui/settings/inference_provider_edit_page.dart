import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/settings/inference_provider_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/form_bottom_bar.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_form_create.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_form_create_status.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_form_edit.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_form_edit_setup.dart';
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
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/themes/theme.dart';

part 'inference_provider_edit_form_builder.dart';

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
  bool createDefaultCategory = true,
}) async {
  return switch (providerType) {
    InferenceProviderType.alibaba => setupService.performAlibabaFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
      createDefaultCategory: createDefaultCategory,
    ),
    InferenceProviderType.anthropic => setupService.performAnthropicFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
      createDefaultCategory: createDefaultCategory,
    ),
    InferenceProviderType.gemini => setupService.performGeminiFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
      createDefaultCategory: createDefaultCategory,
    ),
    InferenceProviderType.ollama => setupService.performOllamaFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
      createDefaultCategory: createDefaultCategory,
    ),
    InferenceProviderType.openAi => setupService.performOpenAiFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
      createDefaultCategory: createDefaultCategory,
    ),
    InferenceProviderType.melious => setupService.performMeliousFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
      createDefaultCategory: createDefaultCategory,
    ),
    InferenceProviderType.mistral => setupService.performMistralFtueSetup(
      context: context,
      ref: ref,
      provider: config,
      excludedProviderModelIds: excludedProviderModelIds,
      createDefaultCategory: createDefaultCategory,
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
    if (apiKey.trim().isEmpty &&
        !ProviderConfig.noApiKeyRequired.contains(providerType)) {
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
                      child: CreateModeChrome(
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
            //
            // Wrapped in a bottom-only `SafeArea` so the save action clears
            // the home indicator: this form is lifted above the app shell on
            // mobile (root-navigator push — see
            // `AiSettingsNavigationService`), so the bottom nav no longer
            // reserves that inset for it.
            SafeArea(
              top: false,
              child: isCreate
                  ? AddProviderFooterBar(
                      onBack: () => popAiSettingsDetail(context),
                      onSaveDraft: handleSaveDraft,
                      onSaveAndContinue: handleSave,
                      canSaveDraft: canSaveAsDraft,
                      canSaveAndContinue: isFormValid,
                      isSaving: _isSaving,
                    )
                  : FormBottomBar(
                      onSave: isFormValid && !_isSaving ? handleSave : null,
                      onCancel: () => popAiSettingsDetail(context),
                      isFormValid: isFormValid,
                      isDirty:
                          widget.configId == null ||
                          (formState?.isDirty ?? false),
                      isLoading: _isSaving,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleApiKeyVisibility() {
    setState(() {
      _showApiKey = !_showApiKey;
    });
  }
}
