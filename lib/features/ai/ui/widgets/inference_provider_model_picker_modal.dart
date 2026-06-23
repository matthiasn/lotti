import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Bottom-sheet / dialog picker for choosing which model handles one
/// per-invocation inference run, overriding the inference profile's slot for
/// that single call. Used by the AI-popup skill flows (transcription, image
/// analysis, prompt generation, cover-art image generation).
///
/// The picker filters **first by provider, then by model** so a user with many
/// models across several providers (Anthropic, OpenAI, Gemini, Mistral, a local
/// Ollama, …) is never confronted with one long flat list:
///
/// - **0 models** → returns `null` (nothing to pick).
/// - **1 model** → returns its id without showing the modal (the "1 tap for the
///   only model" promise).
/// - **1 provider** → skips the provider step and shows that provider's models
///   directly, branded with the provider identity.
/// - **2+ providers** → a two-page flow: page 1 lists the providers (with a
///   one-tap "Current default" shortcut at the top), page 2 lists the chosen
///   provider's models with a back button.
///
/// The profile default is marked with a single `tokens.colors.interactive`
/// accent (a check + the supplied badge label) — never a second hue — gets the
/// same `activated` tint on both steps, and is ordered first within its
/// provider. On wide layouts the content column is capped at the modal page
/// breakpoint so rows read at a comfortable measure instead of spanning the
/// whole dialog.
class InferenceProviderModelPickerModal {
  const InferenceProviderModelPickerModal._();

  /// Opens the picker and resolves with the chosen model's id, or `null` when
  /// the user dismisses it (or there was nothing to pick). See the class doc
  /// for the adaptive short-circuits.
  static Future<String?> show({
    required BuildContext context,
    required String? defaultModelId,
    required List<AiConfigModel> models,
    required List<AiConfigInferenceProvider> providers,
    required String title,
    required String defaultBadgeLabel,
  }) async {
    if (models.isEmpty) return null;
    if (models.length == 1) return models.first.id;

    final providersById = <String, AiConfigInferenceProvider>{
      for (final provider in providers) provider.id: provider,
    };

    // Group models under their provider, preserving first-seen order so the
    // provider list is stable and matches the order the caller supplied.
    final providerOrder = <String>[];
    final modelsByProvider = <String, List<AiConfigModel>>{};
    for (final model in models) {
      final providerId = model.inferenceProviderId;
      final bucket = modelsByProvider[providerId];
      if (bucket == null) {
        providerOrder.add(providerId);
        modelsByProvider[providerId] = <AiConfigModel>[model];
      } else {
        bucket.add(model);
      }
    }

    // A single provider needs no provider step — show its models directly,
    // branded with the provider identity so the user always knows whose
    // models they are looking at.
    if (providerOrder.length == 1) {
      return ModalUtils.showSinglePageModal<String>(
        context: context,
        titleWidget: _ProviderPageTitle(
          provider: providersById[providerOrder.first],
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        builder: (modalContext) => _ModelList(
          models: orderModelsDefaultFirst(models, defaultModelId),
          defaultModelId: defaultModelId,
          defaultBadgeLabel: defaultBadgeLabel,
          onSelected: (id) => Navigator.of(modalContext).pop(id),
        ),
      );
    }

    final selectedProvider = ValueNotifier<AiConfigInferenceProvider?>(null);
    final pageIndexNotifier = ValueNotifier<int>(0);

    // The profile default (when it resolves to one of the offered models) gets
    // a one-tap shortcut at the top of the provider page.
    final defaultModel = defaultModelId == null
        ? null
        : models.firstWhereOrNull((model) => model.id == defaultModelId);

    try {
      return await ModalUtils.showMultiPageModal<String>(
        context: context,
        pageIndexNotifier: pageIndexNotifier,
        pageListBuilder: (modalContext) => [
          ModalUtils.modalSheetPage(
            context: modalContext,
            title: title,
            showCloseButton: true,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: _ProviderPage(
              providerOrder: providerOrder,
              modelsByProvider: modelsByProvider,
              providersById: providersById,
              defaultModel: defaultModel,
              defaultProvider: defaultModel == null
                  ? null
                  : providersById[defaultModel.inferenceProviderId],
              onDefaultSelected: () =>
                  Navigator.of(modalContext).pop(defaultModel!.id),
              onProviderSelected: (provider) {
                selectedProvider.value = provider;
                pageIndexNotifier.value = 1;
              },
            ),
          ),
          ModalUtils.modalSheetPage(
            context: modalContext,
            // Same dismiss affordance as page 1 so the two pages read as one
            // picker (back arrow + branded title + close).
            showCloseButton: true,
            padding: const EdgeInsets.symmetric(vertical: 20),
            onTapBack: () => pageIndexNotifier.value = 0,
            titleWidget: ValueListenableBuilder<AiConfigInferenceProvider?>(
              valueListenable: selectedProvider,
              builder: (context, provider, _) =>
                  _ProviderPageTitle(provider: provider),
            ),
            child: ValueListenableBuilder<AiConfigInferenceProvider?>(
              valueListenable: selectedProvider,
              builder: (context, provider, _) {
                if (provider == null) return const SizedBox.shrink();
                return _ModelList(
                  models: orderModelsDefaultFirst(
                    modelsByProvider[provider.id] ?? const [],
                    defaultModelId,
                  ),
                  defaultModelId: defaultModelId,
                  defaultBadgeLabel: defaultBadgeLabel,
                  onSelected: (id) => Navigator.of(modalContext).pop(id),
                );
              },
            ),
          ),
        ],
      );
    } finally {
      selectedProvider.dispose();
      pageIndexNotifier.dispose();
    }
  }

  /// Returns [models] with the default (if present) moved to the front, the
  /// rest keeping their relative order. Pure ordering function (no context, no
  /// state) so it can be unit-tested directly.
  @visibleForTesting
  static List<AiConfigModel> orderModelsDefaultFirst(
    List<AiConfigModel> models,
    String? defaultModelId,
  ) {
    if (defaultModelId == null) return models;
    final defaultModel = models.firstWhereOrNull(
      (model) => model.id == defaultModelId,
    );
    if (defaultModel == null) return models;
    return [
      defaultModel,
      ...models.where((model) => model.id != defaultModelId),
    ];
  }
}

/// Caps the content column at the modal page breakpoint on wide layouts and
/// centres it, so rows read at a comfortable measure instead of spanning the
/// whole dialog (on phones the cap is wider than the screen, so it is a no-op).
class _ConstrainedBody extends StatelessWidget {
  const _ConstrainedBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: WoltModalConfig.pageBreakpoint * 1.0,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Page 1 of the multi-provider flow: a one-tap "Current default" shortcut
/// (when it exists) followed by the provider list.
class _ProviderPage extends StatelessWidget {
  const _ProviderPage({
    required this.providerOrder,
    required this.modelsByProvider,
    required this.providersById,
    required this.defaultModel,
    required this.defaultProvider,
    required this.onDefaultSelected,
    required this.onProviderSelected,
  });

  final List<String> providerOrder;
  final Map<String, List<AiConfigModel>> modelsByProvider;
  final Map<String, AiConfigInferenceProvider> providersById;
  final AiConfigModel? defaultModel;
  final AiConfigInferenceProvider? defaultProvider;
  final VoidCallback onDefaultSelected;
  final ValueChanged<AiConfigInferenceProvider> onProviderSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final defaultModel = this.defaultModel;

    return _ConstrainedBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (defaultModel != null) ...[
            _SectionLabel(
              text: context.messages.aiModelPickerCurrentDefaultLabel,
            ),
            // The default reads as a *model* (name + wire id + check), not a
            // provider — so it can't be mistaken for the provider row below.
            DesignSystemListItem(
              title: defaultModel.name,
              subtitle: defaultModel.providerModelId.isNotEmpty
                  ? defaultModel.providerModelId
                  : null,
              leading: _ProviderTile(
                type: defaultProvider?.inferenceProviderType,
              ),
              trailing: Icon(
                Icons.check_rounded,
                color: tokens.colors.interactive.enabled,
                size: tokens.spacing.step6,
              ),
              activated: true,
              onTap: onDefaultSelected,
            ),
            _SectionLabel(
              text: context.messages.aiModelPickerByProviderLabel,
              tightTop: true,
            ),
          ],
          for (final (index, providerId) in providerOrder.indexed)
            _ProviderRow(
              provider: providersById[providerId],
              modelCount: modelsByProvider[providerId]?.length ?? 0,
              showDivider: index < providerOrder.length - 1,
              onTap: () {
                final provider = providersById[providerId];
                if (provider != null) onProviderSelected(provider);
              },
            ),
        ],
      ),
    );
  }
}

/// A single provider row — branded tile, name, model count, drill-down chevron.
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.modelCount,
    required this.showDivider,
    required this.onTap,
  });

  final AiConfigInferenceProvider? provider;
  final int modelCount;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemListItem(
      title: aiProviderDisplayName(
        type: provider?.inferenceProviderType,
        messages: context.messages,
      ),
      subtitle: context.messages.aiModelPickerProviderModelCount(modelCount),
      leading: _ProviderTile(type: provider?.inferenceProviderType),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: tokens.colors.text.mediumEmphasis,
        size: tokens.spacing.step6,
      ),
      showDivider: showDivider,
      onTap: onTap,
    );
  }
}

/// Page 2 of the multi-provider flow (and the whole body in the single-provider
/// case): the model rows for one provider. Rows carry a step8 leading spacer so
/// their titles align with the provider step's text column (no left jump on
/// drill-in).
class _ModelList extends StatelessWidget {
  const _ModelList({
    required this.models,
    required this.defaultModelId,
    required this.defaultBadgeLabel,
    required this.onSelected,
  });

  final List<AiConfigModel> models;
  final String? defaultModelId;
  final String defaultBadgeLabel;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return _ConstrainedBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, model) in models.indexed)
            DesignSystemListItem(
              title: model.name,
              subtitle: model.providerModelId.isNotEmpty
                  ? model.providerModelId
                  : null,
              leading: SizedBox(width: tokens.spacing.step8),
              trailing: model.id == defaultModelId
                  ? _DefaultMarker(label: defaultBadgeLabel)
                  : null,
              activated: model.id == defaultModelId,
              selected: model.id == defaultModelId,
              showDivider: index < models.length - 1,
              onTap: () => onSelected(model.id),
            ),
        ],
      ),
    );
  }
}

/// Branded square tile for a provider — accent-tinted surface + the provider's
/// icon in its accent hue. Falls back to a neutral interactive accent for
/// providers without a brand token.
class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.type});

  final InferenceProviderType? type;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: tokens.spacing.step8,
      height: tokens.spacing.step8,
      decoration: BoxDecoration(
        color: aiProviderSurface(type: type, tokens: tokens),
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Icon(
        aiProviderIcon(type),
        color: aiProviderAccent(type: type, tokens: tokens),
        size: tokens.spacing.step6,
      ),
    );
  }
}

/// Reactive top-bar title for the model page: the chosen provider's icon + name.
/// Matches the modal's own title slot styling so the header reads as one
/// consistent slot across both pages of the flow.
class _ProviderPageTitle extends StatelessWidget {
  const _ProviderPageTitle({required this.provider});

  final AiConfigInferenceProvider? provider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final type = provider?.inferenceProviderType;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            aiProviderIcon(type),
            color: aiProviderAccent(type: type, tokens: tokens),
            size: tokens.spacing.step5,
          ),
          SizedBox(width: tokens.spacing.step2),
          Flexible(
            child: Text(
              aiProviderDisplayName(type: type, messages: context.messages),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleMedium?.copyWith(
                color: context.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single-accent default marker: the badge label + a check, both in the
/// interactive accent. Deliberately not a filled pill (no second hue).
class _DefaultMarker extends StatelessWidget {
  const _DefaultMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: accent,
            fontWeight: tokens.typography.weight.semiBold,
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Icon(Icons.check_rounded, color: accent, size: tokens.spacing.step6),
      ],
    );
  }
}

/// Quiet caption that labels a zone of the picker (the default shortcut and the
/// provider list). [tightTop] trims the top padding so a second caption sits
/// closer to the row above it.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.tightTop = false});

  final String text;
  final bool tightTop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tightTop ? tokens.spacing.step3 : tokens.spacing.step2,
        tokens.spacing.step5,
        tokens.spacing.step2,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ),
    );
  }
}
