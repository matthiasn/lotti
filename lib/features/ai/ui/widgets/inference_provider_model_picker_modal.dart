import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
/// The profile default is rendered as a **model row** (a single-accent
/// `interactive` selection dot + name + wire id + a `Default ✓` marker + a
/// stronger activated tint) identically wherever it appears — pinned on page 1
/// and first in its provider's list on page 2 — so it reads as one model with a
/// shortcut rather than a duplicate provider entry. Non-default model rows lead
/// with their provider's brand-accent dot instead. The body is full-bleed,
/// aligned with the modal's top bar, on every layout.
class InferenceProviderModelPickerModal {
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
    final providersById = <String, AiConfigInferenceProvider>{
      for (final provider in providers) provider.id: provider,
    };

    // Drop models whose provider is missing or has been deleted: they can't be
    // routed (the runner needs a provider) and would otherwise render as dead
    // rows whose tap does nothing. But never strand the user: if *every* model's
    // provider is unresolved (a data inconsistency, or a caller that didn't pass
    // the provider list), fall back to all of them so the picker still works —
    // just without per-provider branding — rather than silently returning null.
    final withProvider = models
        .where((m) => providersById.containsKey(m.inferenceProviderId))
        .toList();
    final validModels = withProvider.isEmpty ? models : withProvider;
    if (validModels.isEmpty) return null;
    if (validModels.length == 1) return validModels.first.id;

    // Group models under their provider, preserving first-seen order so the
    // provider list is stable and matches the order the caller supplied.
    final providerOrder = <String>[];
    final modelsByProvider = <String, List<AiConfigModel>>{};
    for (final model in validModels) {
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
      final onlyProvider = providersById[providerOrder.first];
      return ModalUtils.showSinglePageModal<String>(
        context: context,
        titleWidget: _ProviderPageTitle(provider: onlyProvider),
        padding: const EdgeInsets.symmetric(vertical: 20),
        builder: (modalContext) => _ModelList(
          models: orderModelsDefaultFirst(validModels, defaultModelId),
          providerType: onlyProvider?.inferenceProviderType,
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
        : validModels.firstWhereOrNull((model) => model.id == defaultModelId);

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
              defaultBadgeLabel: defaultBadgeLabel,
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
                  providerType: provider.inferenceProviderType,
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

/// Scrolls the picker body. The content stays full-bleed (aligned with the
/// modal's own full-width top bar) rather than capped/centred, so the rows
/// don't float inside the dialog on wide layouts.
class _PickerScrollView extends StatelessWidget {
  const _PickerScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: child);
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
    required this.defaultBadgeLabel,
    required this.onDefaultSelected,
    required this.onProviderSelected,
  });

  final List<String> providerOrder;
  final Map<String, List<AiConfigModel>> modelsByProvider;
  final Map<String, AiConfigInferenceProvider> providersById;
  final AiConfigModel? defaultModel;
  final AiConfigInferenceProvider? defaultProvider;
  final String defaultBadgeLabel;
  final VoidCallback onDefaultSelected;
  final ValueChanged<AiConfigInferenceProvider> onProviderSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final defaultModel = this.defaultModel;

    return _PickerScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (defaultModel != null) ...[
            _SectionLabel(
              text: context.messages.aiModelPickerCurrentDefaultLabel,
            ),
            // The default renders as the same model-row lockup it gets on
            // page 2 (accent dot + name + wire id + Default marker), so it
            // reads as a model with a shortcut — never a duplicate provider.
            _ModelRow(
              model: defaultModel,
              providerType: defaultProvider?.inferenceProviderType,
              isDefault: true,
              defaultBadgeLabel: defaultBadgeLabel,
              onTap: onDefaultSelected,
            ),
            // A hairline structurally separates the one-tap default zone from
            // the browse-by-provider list, so the shortcut doesn't rely on its
            // tint alone to read as "skip the steps".
            Divider(
              height: 1,
              thickness: 1,
              indent: tokens.spacing.step5,
              color: tokens.colors.decorative.level01,
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
      size: DesignSystemListItemSize.small,
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
/// case): the model rows for one provider.
class _ModelList extends StatelessWidget {
  const _ModelList({
    required this.models,
    required this.providerType,
    required this.defaultModelId,
    required this.defaultBadgeLabel,
    required this.onSelected,
  });

  final List<AiConfigModel> models;
  final InferenceProviderType? providerType;
  final String? defaultModelId;
  final String defaultBadgeLabel;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _PickerScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // No per-row hairlines on this short list — the row rhythm plus the
          // default's activated band carry the structure, and a divider would
          // collide with that band.
          for (final model in models)
            _ModelRow(
              model: model,
              providerType: providerType,
              isDefault: model.id == defaultModelId,
              defaultBadgeLabel: defaultBadgeLabel,
              onTap: () => onSelected(model.id),
            ),
        ],
      ),
    );
  }
}

/// One selectable model — used identically for the page-1 default shortcut and
/// every page-2 model row, so the default reads as the same object in both
/// places. A small provider-accent dot fills the leading rail (aligning the
/// text column and carrying the provider brand the header promises); the
/// default gets the single-accent marker plus a stronger activated tint.
class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.providerType,
    required this.isDefault,
    required this.defaultBadgeLabel,
    required this.onTap,
  });

  final AiConfigModel model;
  final InferenceProviderType? providerType;
  final bool isDefault;
  final String defaultBadgeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemListItem(
      size: DesignSystemListItemSize.small,
      title: model.name,
      subtitle: model.providerModelId.isNotEmpty ? model.providerModelId : null,
      subtitleMaxLines: 2,
      // The default leads with the single selection accent (matching its band
      // + marker) so the strongest scan position reinforces "selected"; other
      // rows lead with their provider's brand accent for grouping.
      leading: _LeadingDot(
        color: isDefault
            ? tokens.colors.interactive.enabled
            : aiProviderAccent(type: providerType, tokens: tokens),
      ),
      trailing: isDefault ? _DefaultMarker(label: defaultBadgeLabel) : null,
      activated: isDefault,
      selected: isDefault,
      activatedBackgroundColor: isDefault
          ? DesignSystemListPalette.activatedFillStrong(tokens)
          : null,
      onTap: onTap,
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

/// Small coloured dot occupying a model row's leading rail — keeps model titles
/// on the same column as the provider step. The [color] carries either the
/// provider's brand accent (grouping) or the selection accent (the default).
class _LeadingDot extends StatelessWidget {
  const _LeadingDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      width: tokens.spacing.step8,
      child: Center(
        child: Container(
          width: tokens.spacing.step5,
          height: tokens.spacing.step5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Reactive top-bar title for the model page: the chosen provider's icon + name.
/// Uses the shared [ModalUtils.modalTitleStyle] so the branded page-2 header
/// matches the plain page-1 title exactly.
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
              style: ModalUtils.modalTitleStyle(context),
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
