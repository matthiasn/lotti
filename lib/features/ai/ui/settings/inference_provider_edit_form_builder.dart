part of 'inference_provider_edit_page.dart';

/// Form and error-state builders for [_InferenceProviderEditPageState], split
/// from the page file for size. Stateless build helpers; the one stateful
/// callback (API-key visibility) delegates to a method on the state class.
extension _InferenceProviderEditPageForm on _InferenceProviderEditPageState {
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
      onPressed: _toggleApiKeyVisibility,
      tooltip: _showApiKey
          ? messages.apiKeyHideTooltip
          : messages.apiKeyShowTooltip,
    );

    if (isCreate) {
      // v5 flat-field layout matching the screenshot at
      // /Desktop/Screenshot 2026-05-13 at 17.09.21: caption-above-field
      // rows with right-side hints, the API-key helper link, the
      // privacy hint, and the live `ConnectionStatusStrip` below
      // Base URL. No `AiFormSection` wrappers — sections collapse to
      // simple stacked fields per the design.
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FlatField(
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
                  return FlatField(
                    label: messages.apiKeyInputLabel,
                    hintRight: consoleUrl != null
                        ? messages.aiProviderConnectKeyHelperLink(consoleUrl)
                        : null,
                    hintRightTone: FlatFieldHintTone.link,
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
              FlatField(
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
              ConnectionStatusStrip(
                providerType: formState.inferenceProviderType,
                onRetest: () => _retryConnectionVerify(
                  providerType: formState.inferenceProviderType,
                  apiKey: formController.apiKeyController.text,
                  baseUrl: formController.baseUrlController.text,
                ),
              ),
            ] else ...[
              SizedBox(height: tokens.spacing.step6),
              EmbeddedProviderHint(
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
              ProviderTypeField(
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
                EmbeddedProviderHint(
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
            AvailableModelsSection(
              providerId: widget.configId!,
              providerType: formState.inferenceProviderType,
            ),

          // AI Setup Section - Only show for supported providers when editing
          if (widget.configId != null &&
              ftueSupportedProviderTypes.contains(
                formState.inferenceProviderType,
              ))
            AiSetupSection(
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
