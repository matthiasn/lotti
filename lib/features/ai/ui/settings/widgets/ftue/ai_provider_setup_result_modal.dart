import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Action the user picked in the result modal.
enum AiProviderSetupResultAction {
  /// `Review setup` — caller should navigate to the AI Settings page.
  reviewSetup,

  /// `Start using AI` — caller should close the FTUE flow and return
  /// the user to wherever they were before opening it.
  startUsingAi,

  /// Modal was dismissed (close button, swipe, etc.).
  dismissed,
}

/// Unified view of any provider's FTUE result. Each provider's typed
/// `<X>FtueResult` shape is mapped onto this in `from(...)` factories so
/// the modal renders the same widget tree everywhere.
@immutable
class AiProviderSetupResultData {
  const AiProviderSetupResultData({
    required this.providerName,
    required this.providerType,
    required this.modelsCreated,
    required this.modelsVerified,
    required this.profileName,
    required this.categoryName,
    required this.categoryCreated,
    required this.errors,
  });

  factory AiProviderSetupResultData.fromGemini({
    required GeminiFtueResult result,
  }) => AiProviderSetupResultData(
    providerName: 'Gemini',
    providerType: InferenceProviderType.gemini,
    modelsCreated: result.modelsCreated,
    modelsVerified: result.modelsVerified,
    profileName: 'Gemini Flash',
    categoryName: result.categoryName,
    categoryCreated: result.categoryCreated,
    errors: result.errors,
  );

  factory AiProviderSetupResultData.fromOpenAi({
    required OpenAiFtueResult result,
  }) => AiProviderSetupResultData(
    providerName: 'OpenAI',
    providerType: InferenceProviderType.openAi,
    modelsCreated: result.modelsCreated,
    modelsVerified: result.modelsVerified,
    profileName: 'OpenAI',
    categoryName: result.categoryName,
    categoryCreated: result.categoryCreated,
    errors: result.errors,
  );

  factory AiProviderSetupResultData.fromMistral({
    required MistralFtueResult result,
  }) => AiProviderSetupResultData(
    providerName: 'Mistral',
    providerType: InferenceProviderType.mistral,
    modelsCreated: result.modelsCreated,
    modelsVerified: result.modelsVerified,
    profileName: 'Mistral (EU)',
    categoryName: result.categoryName,
    categoryCreated: result.categoryCreated,
    errors: result.errors,
  );

  factory AiProviderSetupResultData.fromAlibaba({
    required AlibabaFtueResult result,
  }) => AiProviderSetupResultData(
    providerName: 'Alibaba Cloud (Qwen)',
    providerType: InferenceProviderType.alibaba,
    modelsCreated: result.modelsCreated,
    modelsVerified: result.modelsVerified,
    profileName: 'Chinese AI Profile',
    categoryName: result.categoryName,
    categoryCreated: result.categoryCreated,
    errors: result.errors,
  );

  factory AiProviderSetupResultData.fromAnthropic({
    required AnthropicFtueResult result,
  }) => AiProviderSetupResultData(
    providerName: 'Anthropic',
    providerType: InferenceProviderType.anthropic,
    modelsCreated: result.modelsCreated,
    modelsVerified: result.modelsVerified,
    profileName: 'Anthropic Claude',
    categoryName: result.categoryName,
    categoryCreated: result.categoryCreated,
    errors: result.errors,
  );

  factory AiProviderSetupResultData.fromOllama({
    required OllamaFtueResult result,
  }) => AiProviderSetupResultData(
    providerName: 'Ollama',
    providerType: InferenceProviderType.ollama,
    modelsCreated: result.modelsCreated,
    modelsVerified: result.modelsVerified,
    profileName: 'Local (Ollama)',
    categoryName: result.categoryName,
    categoryCreated: result.categoryCreated,
    errors: result.errors,
  );

  /// Dispatches on the sealed [AiFtueResult] hierarchy. The exhaustive
  /// switch means the analyzer will flag a missing arm when a new
  /// provider's result subtype is added — no silent fallthrough.
  factory AiProviderSetupResultData.from(AiFtueResult result) {
    return switch (result) {
      GeminiFtueResult() => AiProviderSetupResultData.fromGemini(
        result: result,
      ),
      OpenAiFtueResult() => AiProviderSetupResultData.fromOpenAi(
        result: result,
      ),
      MistralFtueResult() => AiProviderSetupResultData.fromMistral(
        result: result,
      ),
      AlibabaFtueResult() => AiProviderSetupResultData.fromAlibaba(
        result: result,
      ),
      AnthropicFtueResult() => AiProviderSetupResultData.fromAnthropic(
        result: result,
      ),
      OllamaFtueResult() => AiProviderSetupResultData.fromOllama(
        result: result,
      ),
    };
  }

  final String providerName;
  final InferenceProviderType providerType;
  final int modelsCreated;
  final int modelsVerified;
  final String profileName;
  final String? categoryName;
  final bool categoryCreated;
  final List<String> errors;

  int get totalModels => modelsCreated + modelsVerified;
}

/// Modal: "{Provider} is connected. We set things up for you."
///
/// Compact post-setup summary. Three bullet rows when present:
/// - Added N models
/// - Created inference profile {Profile}
/// - Set up test category {Category} to try it out
///
/// Footer: `Review setup` (jumps to AI Settings) and `Start using AI`
/// (closes the flow). Errors render in a tinted section below the
/// bullets when present.
///
/// Replaces the old `FtueResultDialog`.
class AiProviderSetupResultModal extends StatelessWidget {
  const AiProviderSetupResultModal({required this.data, super.key});

  final AiProviderSetupResultData data;

  /// Shows the result modal and returns the user's chosen action.
  /// Dismissing the sheet returns [AiProviderSetupResultAction.dismissed].
  static Future<AiProviderSetupResultAction> show({
    required BuildContext context,
    required AiProviderSetupResultData data,
  }) async {
    final action =
        await ModalUtils.showSinglePageModal<AiProviderSetupResultAction>(
          context: context,
          title: context.messages.aiSetupResultModalTitle(
            aiProviderDisplayName(
              type: data.providerType,
              messages: context.messages,
            ),
          ),
          builder: (modalCtx) => AiProviderSetupResultModal(data: data),
        );
    return action ?? AiProviderSetupResultAction.dismissed;
  }

  /// Shortcut: maps a raw FTUE result (any provider) to result data and
  /// opens the modal.
  static Future<AiProviderSetupResultAction> showFor({
    required BuildContext context,
    required AiFtueResult result,
  }) async {
    return show(context: context, data: AiProviderSetupResultData.from(result));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final hasErrors = data.errors.isNotEmpty;
    final localisedProviderName = aiProviderDisplayName(
      type: data.providerType,
      messages: messages,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          messages.aiSetupResultHeader(localisedProviderName),
          style: tokens.typography.styles.heading.heading3.copyWith(
            color: tokens.colors.text.highEmphasis,
            fontWeight: tokens.typography.weight.semiBold,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          messages.aiSetupResultLead,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        if (data.totalModels > 0)
          _ResultBullet(
            icon: Icons.memory_rounded,
            text: messages.aiSetupResultBulletModels(data.totalModels),
            accent: aiProviderAccent(type: data.providerType, tokens: tokens),
          ),
        SizedBox(height: tokens.spacing.step3),
        _ResultBullet(
          icon: Icons.tune_rounded,
          text: messages.aiSetupResultBulletProfile(data.profileName),
          accent: aiProviderAccent(type: data.providerType, tokens: tokens),
        ),
        if (data.categoryName != null) ...[
          SizedBox(height: tokens.spacing.step3),
          _ResultBullet(
            icon: Icons.folder_outlined,
            text: data.categoryCreated
                ? messages.aiSetupResultBulletCategoryCreated(
                    data.categoryName!,
                  )
                : messages.aiSetupResultBulletCategoryReused(
                    data.categoryName!,
                  ),
            accent: aiProviderAccent(type: data.providerType, tokens: tokens),
          ),
        ],
        if (hasErrors) ...[
          SizedBox(height: tokens.spacing.step5),
          _ErrorsBlock(errors: data.errors),
        ],
        SizedBox(height: tokens.spacing.step6),
        _Actions(
          onReviewSetup: () => Navigator.of(context).pop(
            AiProviderSetupResultAction.reviewSetup,
          ),
          onStart: () => Navigator.of(context).pop(
            AiProviderSetupResultAction.startUsingAi,
          ),
        ),
      ],
    );
  }
}

class _ResultBullet extends StatelessWidget {
  const _ResultBullet({
    required this.icon,
    required this.text,
    required this.accent,
  });

  final IconData icon;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: tokens.spacing.step6,
          height: tokens.spacing.step6,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(tokens.radii.s),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: tokens.spacing.step1),
            child: Text(
              text,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorsBlock extends StatelessWidget {
  const _ErrorsBlock({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final danger = tokens.colors.alert.error.defaultColor;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: danger.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            messages.aiSetupResultErrorsHeader(errors.length),
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: danger,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          for (final err in errors)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step1),
              child: Text(
                '· $err',
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

class _Actions extends StatelessWidget {
  const _Actions({required this.onReviewSetup, required this.onStart});

  final VoidCallback onReviewSetup;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Use Wrap so the two buttons reflow onto a second line on narrow
    // surfaces instead of overflowing the modal's content width.
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        DesignSystemButton(
          label: messages.aiSetupResultReviewSetupButton,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          onPressed: onReviewSetup,
        ),
        DesignSystemButton(
          label: messages.aiSetupResultStartUsingButton,
          size: DesignSystemButtonSize.large,
          onPressed: onStart,
        ),
      ],
    );
  }
}

// Provider accent now routes through `aiProviderAccent` so the preview
// modal, this result modal, and the AI Settings cards share one source
// of truth for per-provider chrome.
