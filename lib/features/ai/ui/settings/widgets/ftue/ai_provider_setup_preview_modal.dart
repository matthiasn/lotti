import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_provider_setup_preview_models.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_provider_setup_preview_rows.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

export 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_provider_setup_preview_models.dart';

/// FTUE "Review what Lotti will add" sheet shown after a provider connects.
///
/// Lets the user preview and opt out of the per-provider preset before it is
/// applied: a connected banner, the profile that will be seeded, the
/// tickable [NewModelsSection], an optional read-only [AlreadyAddedSection],
/// and the test category footer. Returns an
/// [AiProviderSetupPreviewResult] carrying `confirmed` plus the set of
/// `providerModelId`s the user unticked (Accept & finish), or
/// [AiProviderSetupPreviewResult.cancelled] on Customize / dismiss.
///
/// Prefer the [show] static entry point — it resolves the preset, filters
/// out already-configured models, and short-circuits (returning a confirmed
/// empty result) when there is nothing left to review.
class AiProviderSetupPreviewModal extends StatefulWidget {
  const AiProviderSetupPreviewModal({
    required this.providerType,
    required this.preset,
    required this.existingModels,
    super.key,
  });

  final InferenceProviderType providerType;
  final AiProviderSetupPreviewPreset preset;
  final List<AiConfigModel> existingModels;

  /// True for providers that ship no FTUE preset (Ollama in PR-1) — the
  /// caller should run setup directly and jump to the result modal,
  /// because there are no rows to review.
  static bool skipsPreviewFor(InferenceProviderType type) {
    return presetFor(type)?.models.isEmpty ?? true;
  }

  /// Returns the FTUE preset for [type], or null if the provider has no
  /// preset wired in.
  static AiProviderSetupPreviewPreset? presetFor(InferenceProviderType type) {
    return switch (type) {
      InferenceProviderType.gemini => geminiPreset(),
      InferenceProviderType.openAi => openAiPreset(),
      InferenceProviderType.mistral => mistralPreset(),
      InferenceProviderType.alibaba => alibabaPreset(),
      InferenceProviderType.anthropic => anthropicPreset(),
      InferenceProviderType.ollama => ollamaPreset(),
      _ => null,
    };
  }

  /// Opens the preview modal. Returns
  /// [AiProviderSetupPreviewResult.cancelled] if the user dismisses the
  /// sheet, taps Customize, or taps the close button — i.e. anything
  /// short of Accept & finish.
  static Future<AiProviderSetupPreviewResult> show({
    required BuildContext context,
    required WidgetRef ref,
    required InferenceProviderType providerType,
    required String providerId,
  }) async {
    final preset = presetFor(providerType);
    if (preset == null || preset.models.isEmpty) {
      // Skip the preview for providers without a model preset (Ollama).
      return const AiProviderSetupPreviewResult(
        confirmed: true,
        excludedProviderModelIds: <String>{},
      );
    }

    final repo = ref.read(aiConfigRepositoryProvider);
    final allModels = await repo.getConfigsByType(AiConfigType.model);
    final allProviders = await repo.getConfigsByType(
      AiConfigType.inferenceProvider,
    );
    final presetModelIds = preset.models
        .map((model) => model.providerModelId)
        .toSet();
    final providersById = {
      for (final provider
          in allProviders.whereType<AiConfigInferenceProvider>())
        provider.id: provider,
    };
    final existing = _filterExistingPresetModels(
      allModels.whereType<AiConfigModel>(),
      presetModelIds: presetModelIds,
      providerId: providerId,
      providerType: providerType,
      providersById: providersById,
    );

    if (!context.mounted) {
      return const AiProviderSetupPreviewResult.cancelled();
    }

    // Filter out preset models the user already has through this provider or
    // a usable synced provider of the same type. Those become read-only rows
    // in the "already added" section, not editable rows.
    final existingPresetIds = existing.map((m) => m.providerModelId).toSet();
    final newModels = preset.models
        .where((km) => !existingPresetIds.contains(km.providerModelId))
        .toList(growable: false);

    if (newModels.isEmpty) {
      // Everything in the preset is already configured — nothing to
      // review. Confirm with an empty excluded set and let the
      // workflow jump straight to the result modal.
      return const AiProviderSetupPreviewResult(
        confirmed: true,
        excludedProviderModelIds: <String>{},
      );
    }

    // Resolve the localised provider name once so the modal title
    // matches the in-modal banner; the preset's `providerName` is
    // intentionally still the English brand alias used downstream by
    // the result modal's accent map and analytics.
    final localisedProviderName = aiProviderDisplayName(
      type: providerType,
      messages: context.messages,
    );
    final result =
        await ModalUtils.showSinglePageModal<AiProviderSetupPreviewResult>(
          context: context,
          title: context.messages.aiSetupPreviewModalTitle(
            localisedProviderName,
          ),
          builder: (modalCtx) => AiProviderSetupPreviewModal(
            providerType: providerType,
            preset: AiProviderSetupPreviewPreset(
              providerName: preset.providerName,
              profileName: preset.profileName,
              categoryName: preset.categoryName,
              models: newModels,
            ),
            existingModels: existing,
          ),
        );

    return result ?? const AiProviderSetupPreviewResult.cancelled();
  }

  @override
  State<AiProviderSetupPreviewModal> createState() =>
      _AiProviderSetupPreviewModalState();
}

class _AiProviderSetupPreviewModalState
    extends State<AiProviderSetupPreviewModal> {
  /// Provider-model ids the user has unticked. Empty = "accept all
  /// proposed models". Mutated by the checkbox callbacks.
  final Set<String> _excluded = <String>{};

  void _toggle(String providerModelId, bool? value) {
    setState(() {
      if (value == true) {
        _excluded.remove(providerModelId);
      } else {
        _excluded.add(providerModelId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final accent = aiProviderAccent(
      type: widget.providerType,
      tokens: tokens,
    );

    final localisedProviderName = aiProviderDisplayName(
      type: widget.providerType,
      messages: messages,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConnectedBanner(
          providerName: localisedProviderName,
          accent: accent,
        ),
        SizedBox(height: tokens.spacing.step4),
        Text(
          messages.aiSetupPreviewLead,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        _ProfilePreviewCard(
          profileName: widget.preset.profileName,
          providerType: widget.providerType,
          accent: accent,
        ),
        SizedBox(height: tokens.spacing.step5),
        NewModelsSection(
          models: widget.preset.models,
          excluded: _excluded,
          accent: accent,
          onToggle: _toggle,
        ),
        if (widget.existingModels.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step5),
          AlreadyAddedSection(models: widget.existingModels),
        ],
        SizedBox(height: tokens.spacing.step5),
        _CategoryFooter(categoryName: widget.preset.categoryName),
        SizedBox(height: tokens.spacing.step5),
        _Actions(
          onCustomize: () => Navigator.of(context).pop(
            const AiProviderSetupPreviewResult.cancelled(),
          ),
          onAccept: () => Navigator.of(context).pop(
            AiProviderSetupPreviewResult(
              confirmed: true,
              excludedProviderModelIds: Set<String>.unmodifiable(_excluded),
            ),
          ),
        ),
      ],
    );
  }
}

List<AiConfigModel> _filterExistingPresetModels(
  Iterable<AiConfigModel> models, {
  required Set<String> presetModelIds,
  required String providerId,
  required InferenceProviderType providerType,
  required Map<String, AiConfigInferenceProvider> providersById,
}) {
  final existing = <AiConfigModel>[];
  final seenProviderModelIds = <String>{};

  for (final model in models) {
    if (!presetModelIds.contains(model.providerModelId) ||
        seenProviderModelIds.contains(model.providerModelId)) {
      continue;
    }

    if (model.inferenceProviderId == providerId) {
      existing.add(model);
      seenProviderModelIds.add(model.providerModelId);
      continue;
    }

    final provider = providersById[model.inferenceProviderId];
    if (provider == null || provider.inferenceProviderType != providerType) {
      continue;
    }

    if (provider.isUsable) {
      existing.add(model);
      seenProviderModelIds.add(model.providerModelId);
    }
  }

  return existing;
}

// --------------------------------------------------------------------------
// Section widgets
// --------------------------------------------------------------------------

class _ConnectedBanner extends StatelessWidget {
  const _ConnectedBanner({required this.providerName, required this.accent});

  final String providerName;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step3,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Container(
            width: tokens.spacing.step3,
            height: tokens.spacing.step3,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              messages.aiSetupPreviewConnectedHeader(providerName),
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          DesignSystemBadge.filled(
            label: messages.aiSetupPreviewLiveBadge,
            tone: DesignSystemBadgeTone.success,
          ),
        ],
      ),
    );
  }
}

class _ProfilePreviewCard extends StatelessWidget {
  const _ProfilePreviewCard({
    required this.profileName,
    required this.providerType,
    required this.accent,
  });

  final String profileName;
  final InferenceProviderType providerType;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Row(
        children: [
          Container(
            width: tokens.spacing.step6,
            height: tokens.spacing.step6,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(tokens.radii.s),
            ),
            child: Icon(Icons.tune_rounded, size: 18, color: accent),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messages.aiSetupPreviewProfileSectionLabel,
                  style: tokens.typography.styles.others.overline.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  profileName,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ],
            ),
          ),
          DesignSystemBadge.filled(
            label: messages.aiSetupPreviewProfileSetActiveBadge,
            // ignore: avoid_redundant_argument_values
            tone: DesignSystemBadgeTone.primary,
          ),
        ],
      ),
    );
  }
}

class _CategoryFooter extends StatelessWidget {
  const _CategoryFooter({required this.categoryName});

  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Row(
      children: [
        Icon(
          Icons.folder_outlined,
          size: 18,
          color: tokens.colors.text.lowEmphasis,
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            messages.aiSetupPreviewCategoryFooter(categoryName),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onCustomize, required this.onAccept});

  final VoidCallback onCustomize;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        DesignSystemButton(
          label: messages.aiSetupPreviewCustomizeButton,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          onPressed: onCustomize,
        ),
        DesignSystemButton(
          label: messages.aiSetupPreviewAcceptButton,
          size: DesignSystemButtonSize.large,
          onPressed: onAccept,
        ),
      ],
    );
  }
}
