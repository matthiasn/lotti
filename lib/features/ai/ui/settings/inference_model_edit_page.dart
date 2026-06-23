import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_model_form_state.dart';
import 'package:lotti/features/ai/model/modality_extensions.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/settings/inference_model_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_widgets.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_settings_back_nav.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_components.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_error_extension.dart';
import 'package:lotti/features/ai/ui/settings/widgets/modality_selection_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_selection_modal.dart';
import 'package:lotti/features/ai/ui/widgets/gemini_thinking_mode_picker_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/selection/unified_toggle.dart';

/// Create / edit page for an inference model row. Rewritten in v3 to
/// match the visual language shipped by the AI Settings v1 → v3 page
/// redesign: design-system tokens for surfaces and spacing, sections
/// in level-02 cards, a clean AppBar with a text Save action, and a
/// provider-tinted header strip when the form has resolved its owning
/// provider. The form controller wiring (`InferenceModelFormController`,
/// modality / provider selection modals, Cmd+S shortcut) is preserved
/// verbatim — only the rendering layer changed.
class InferenceModelEditPage extends ConsumerStatefulWidget {
  const InferenceModelEditPage({
    this.configId,
    this.preselectedProviderId,
    super.key,
  });

  final String? configId;

  /// Pre-fills the new form's owning provider when the page is opened
  /// from a provider's detail page. Has no effect in edit mode
  /// (`configId != null`) — existing models always carry their own
  /// `inferenceProviderId`. Top-level "+ Add model" entry points pass
  /// nothing, so the user picks the provider manually.
  final String? preselectedProviderId;

  @override
  ConsumerState<InferenceModelEditPage> createState() =>
      _InferenceModelEditPageState();
}

class _InferenceModelEditPageState
    extends ConsumerState<InferenceModelEditPage> {
  bool _isSaving = false;

  /// Helper to get the form controller provider with correct parameters.
  /// Centralised so the watch + read + handleSave call sites can't
  /// silently disagree on the (`configId`, `preselectedProviderId`)
  /// tuple — keeping the same tuple end-to-end keeps Riverpod from
  /// spawning a second controller family instance.
  InferenceModelFormControllerProvider get _formProvider =>
      inferenceModelFormControllerProvider(
        configId: widget.configId,
        preselectedProviderId: widget.configId == null
            ? widget.preselectedProviderId
            : null,
      );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    final configAsync = widget.configId == null
        ? const AsyncData<AiConfig?>(null)
        : ref.watch(aiConfigByIdProvider(widget.configId!));

    final formState = ref.watch(_formProvider).value;

    final isFormValid =
        formState != null &&
        formState.isValid &&
        formState.inferenceProviderId.isNotEmpty &&
        formState.inputModalities.isNotEmpty &&
        formState.outputModalities.isNotEmpty &&
        (widget.configId == null || formState.isDirty);

    Future<void> handleSave() async {
      if (!isFormValid || _isSaving) return;
      setState(() => _isSaving = true);
      try {
        final config = formState.toAiConfig();
        final controller = ref.read(_formProvider.notifier);
        if (widget.configId == null) {
          await controller.addConfig(config);
        } else {
          await controller.updateConfig(config);
        }
        if (context.mounted) {
          await popAiSettingsDetail(context);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isSaving = false);
        }
        rethrow;
      }
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          if (isFormValid && !_isSaving) handleSave();
        },
      },
      child: Scaffold(
        backgroundColor: tokens.colors.background.level01,
        appBar: AppBar(
          backgroundColor: tokens.colors.background.level01,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: messages.modelEditBackTooltip,
            onPressed: () => popAiSettingsDetail(context),
          ),
          title: Text(
            widget.configId == null
                ? messages.modelAddPageTitle
                : messages.modelEditPageTitle,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
          actions: [
            // Save mirrors the note editor's toolbar Save: a primary
            // design-system button that stays quiet/disabled until the
            // form is saveable (valid, and — when editing — dirty), then
            // wakes to the teal accent. The leading save glyph keeps the
            // clean→active change from being carried by hue alone. A tooltip
            // explains WHY it's disabled (no changes vs fix errors), since the
            // AppBar has no status line like the provider form's FormBottomBar.
            Tooltip(
              message: isFormValid
                  ? messages.modelEditSaveButton
                  : (widget.configId != null &&
                        formState != null &&
                        !formState.isDirty)
                  ? messages.aiFormNoChanges
                  : messages.aiFormFixErrors,
              child: DesignSystemButton(
                label: messages.modelEditSaveButton,
                leadingIcon: Icons.save_rounded,
                onPressed: isFormValid && !_isSaving ? handleSave : null,
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
          ],
        ),
        body: switch (configAsync) {
          AsyncData() => _buildBody(context, formState),
          AsyncError() => _buildErrorState(context),
          _ => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          ),
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, InferenceModelFormState? formState) {
    if (formState == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final tokens = context.designTokens;
    final messages = context.messages;
    final formController = ref.read(_formProvider.notifier);

    // Resolve the owning provider so the header strip can wear its
    // accent. The form may not have a provider selected yet — we render
    // a neutral header in that case.
    final providerAsync = formState.inferenceProviderId.isNotEmpty
        ? ref.watch(aiConfigByIdProvider(formState.inferenceProviderId))
        : const AsyncData<AiConfig?>(null);
    final ownerProvider = providerAsync.maybeWhen(
      data: (value) => value is AiConfigInferenceProvider ? value : null,
      orElse: () => null,
    );
    final providerName = ownerProvider?.name ?? messages.modelEditProviderHint;

    final bottomInset = DesignSystemBottomNavigationBar.occupiedHeight(
      context,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step6 + bottomInset,
      ),
      children: [
        HeaderStrip(
          modelName: formState.name.value,
          providerType: ownerProvider?.inferenceProviderType,
          providerName: providerName,
        ),
        SizedBox(height: tokens.spacing.step5),
        Section(
          title: messages.modelEditSectionIdentity,
          child: SectionCard(
            children: [
              SelectorField(
                label: messages.modelEditProviderLabel,
                value: providerName,
                isEmpty: formState.inferenceProviderId.isEmpty,
                onTap: () => _showProviderSelectionModal(
                  context,
                  formController,
                  formState.inferenceProviderId,
                ),
              ),
              SizedBox(height: tokens.spacing.step4),
              AiTextField(
                label: messages.modelEditDisplayNameLabel,
                hint: messages.modelEditDisplayNameHint,
                controller: formController.nameController,
                onChanged: formController.nameChanged,
                validator: (_) => formState.name.error?.displayMessage,
                prefixIcon: Icons.label_outline_rounded,
              ),
              SizedBox(height: tokens.spacing.step4),
              AiTextField(
                label: messages.modelEditProviderModelIdLabel,
                hint: messages.modelEditProviderModelIdHint,
                controller: formController.providerModelIdController,
                onChanged: formController.providerModelIdChanged,
                validator: (_) =>
                    formState.providerModelId.error?.displayMessage,
                prefixIcon: Icons.fingerprint_rounded,
              ),
              SizedBox(height: tokens.spacing.step4),
              AiTextField(
                label: messages.modelEditDescriptionLabel,
                hint: messages.modelEditDescriptionHint,
                controller: formController.descriptionController,
                onChanged: formController.descriptionChanged,
                validator: (_) => formState.description.error,
                maxLines: 3,
                minLines: 2,
                prefixIcon: Icons.description_rounded,
              ),
              SizedBox(height: tokens.spacing.step4),
              AiTextField(
                label: messages.modelEditMaxTokensLabel,
                hint: messages.modelEditMaxTokensHint,
                controller: formController.maxCompletionTokensController,
                onChanged: formController.maxCompletionTokensChanged,
                validator: (_) =>
                    formState.maxCompletionTokens.error?.displayMessage,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.numbers_rounded,
              ),
              if (ownerProvider?.inferenceProviderType ==
                  InferenceProviderType.gemini) ...[
                SizedBox(height: tokens.spacing.step4),
                SelectorField(
                  label: messages.modelEditGeminiThinkingModeLabel,
                  value: _formatGeminiThinkingMode(
                    context,
                    formState.geminiThinkingMode,
                  ),
                  isEmpty: false,
                  onTap: () => _showGeminiThinkingModeSelectionModal(
                    context,
                    formState.geminiThinkingMode,
                    formController.geminiThinkingModeChanged,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step6),
        Section(
          title: messages.modelEditSectionCapabilities,
          child: SectionCard(
            children: [
              SelectorField(
                label: messages.modelEditInputModalitiesLabel,
                value: _formatModalities(formState.inputModalities),
                isEmpty: formState.inputModalities.isEmpty,
                onTap: () => _showModalitySelectionModal(
                  context,
                  messages.modelEditInputModalitiesLabel,
                  formState.inputModalities,
                  formController.inputModalitiesChanged,
                ),
              ),
              SizedBox(height: tokens.spacing.step4),
              SelectorField(
                label: messages.modelEditOutputModalitiesLabel,
                value: _formatModalities(formState.outputModalities),
                isEmpty: formState.outputModalities.isEmpty,
                onTap: () => _showModalitySelectionModal(
                  context,
                  messages.modelEditOutputModalitiesLabel,
                  formState.outputModalities,
                  formController.outputModalitiesChanged,
                ),
              ),
              SizedBox(height: tokens.spacing.step4),
              UnifiedAiToggleField(
                label: messages.modelEditReasoningLabel,
                description: messages.modelEditReasoningDescription,
                value: formState.isReasoningModel,
                onChanged: formController.isReasoningModelChanged,
                icon: Icons.psychology_alt_rounded,
              ),
              SizedBox(height: tokens.spacing.step3),
              UnifiedAiToggleField(
                label: messages.modelEditFunctionCallingLabel,
                description: messages.modelEditFunctionCallingDescription,
                value: formState.supportsFunctionCalling,
                onChanged: formController.supportsFunctionCallingChanged,
                icon: Icons.functions_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showProviderSelectionModal(
    BuildContext context,
    InferenceModelFormController controller,
    String selectedProviderId,
  ) {
    ProviderSelectionModal.show(
      context: context,
      onProviderSelected: controller.inferenceProviderIdChanged,
      selectedProviderId: selectedProviderId,
    );
  }

  void _showModalitySelectionModal(
    BuildContext context,
    String title,
    List<Modality> selectedModalities,
    void Function(List<Modality>) onChanged,
  ) {
    ModalitySelectionModal.show(
      context: context,
      title: title,
      selectedModalities: selectedModalities,
      onSave: onChanged,
    );
  }

  String _formatModalities(List<Modality> modalities) {
    if (modalities.isEmpty) {
      return context.messages.modelEditModalityNoneSelected;
    }
    return modalities.map((m) => m.displayName(context)).join(', ');
  }

  String _formatGeminiThinkingMode(
    BuildContext context,
    GeminiThinkingMode mode,
  ) {
    final messages = context.messages;
    return switch (mode) {
      GeminiThinkingMode.minimal => messages.geminiThinkingModeMinimalLabel,
      GeminiThinkingMode.low => messages.geminiThinkingModeLowLabel,
      GeminiThinkingMode.medium => messages.geminiThinkingModeMediumLabel,
      GeminiThinkingMode.high => messages.geminiThinkingModeHighLabel,
    };
  }

  Future<void> _showGeminiThinkingModeSelectionModal(
    BuildContext context,
    GeminiThinkingMode selectedMode,
    ValueChanged<GeminiThinkingMode> onChanged,
  ) async {
    final mode = await GeminiThinkingModePickerModal.show(
      context: context,
      selectedMode: selectedMode,
    );
    if (mode == null || !context.mounted) return;
    onChanged(mode);
  }

  Widget _buildErrorState(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(tokens.spacing.step4),
              decoration: BoxDecoration(
                color: tokens.colors.alert.error.defaultColor.withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(tokens.radii.l),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: tokens.spacing.step8,
                color: tokens.colors.alert.error.defaultColor,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            Text(
              messages.modelEditLoadError,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
                fontWeight: tokens.typography.weight.semiBold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
