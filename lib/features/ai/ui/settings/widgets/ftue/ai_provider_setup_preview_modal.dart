import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Outcome of the setup-preview modal. `excludedProviderModelIds` is the
/// set of `KnownModel.providerModelId` values the user unticked — the
/// caller threads that through `runFtueSetupForType` so the matching
/// rows are removed after the standard FTUE preset runs.
@immutable
class AiProviderSetupPreviewResult {
  const AiProviderSetupPreviewResult({
    required this.confirmed,
    required this.excludedProviderModelIds,
  });

  const AiProviderSetupPreviewResult.cancelled()
    : confirmed = false,
      excludedProviderModelIds = const <String>{};

  final bool confirmed;
  final Set<String> excludedProviderModelIds;
}

/// Per-provider preview data the modal renders.
///
/// Bundles the FTUE preset's `KnownModel` list with the seeded profile
/// name and the test-category name so the modal can ship one widget tree
/// for every provider type. `models` may be empty (Ollama) — the caller
/// is expected to short-circuit and skip the modal in that case via
/// `AiProviderSetupPreviewModal.skipsPreviewFor(...)`.
@immutable
class AiProviderSetupPreviewPreset {
  const AiProviderSetupPreviewPreset({
    required this.providerName,
    required this.profileName,
    required this.categoryName,
    required this.models,
  });

  final String providerName;
  final String profileName;
  final String categoryName;
  final List<KnownModel> models;
}

/// Modal: "{Provider} connected · Live · Review what Lotti will add".
///
/// Renders three sections:
/// - **New models** — checkbox per row; unticking a row records its
///   `providerModelId` in the excluded set. All boxes start ticked.
/// - **Already added** — read-only rows for models the provider already
///   owns. No checkboxes; just chips. Empty if the user is setting up
///   the provider for the first time.
/// - **Inference profile + test category** — confirms what the FTUE
///   will seed alongside the model rows.
///
/// Replaces the old `FtueSetupDialog` confirmation. Footer:
/// `Customize` (cancel — returns to the provider form) and
/// `Accept & finish` (returns `confirmed: true` with the excluded set).
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
      InferenceProviderType.gemini => _geminiPreset(),
      InferenceProviderType.openAi => _openAiPreset(),
      InferenceProviderType.mistral => _mistralPreset(),
      InferenceProviderType.alibaba => _alibabaPreset(),
      InferenceProviderType.anthropic => _anthropicPreset(),
      InferenceProviderType.ollama => _ollamaPreset(),
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
    final existing = allModels
        .whereType<AiConfigModel>()
        .where((m) => m.inferenceProviderId == providerId)
        .toList(growable: false);

    if (!context.mounted) {
      return const AiProviderSetupPreviewResult.cancelled();
    }

    // Filter out preset models the user already has — those become
    // read-only rows in the "already added" section, not editable rows.
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

    final result =
        await ModalUtils.showSinglePageModal<AiProviderSetupPreviewResult>(
          context: context,
          title: context.messages.aiSetupPreviewModalTitle(preset.providerName),
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
    final accent = _providerAccent(widget.providerType, tokens);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConnectedBanner(
          providerName: widget.preset.providerName,
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
        _NewModelsSection(
          models: widget.preset.models,
          excluded: _excluded,
          accent: accent,
          onToggle: _toggle,
        ),
        if (widget.existingModels.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step5),
          _AlreadyAddedSection(models: widget.existingModels),
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

class _NewModelsSection extends StatelessWidget {
  const _NewModelsSection({
    required this.models,
    required this.excluded,
    required this.accent,
    required this.onToggle,
  });

  final List<KnownModel> models;
  final Set<String> excluded;
  final Color accent;
  // ignore: avoid_positional_boolean_parameters
  final void Function(String providerModelId, bool? value) onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          label: messages.aiSetupPreviewModelsSectionLabel,
          count: models.length,
        ),
        SizedBox(height: tokens.spacing.step3),
        ...models.map(
          (model) => Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step3),
            child: _ModelRow(
              model: model,
              ticked: !excluded.contains(model.providerModelId),
              accent: accent,
              onChanged: (v) => onToggle(model.providerModelId, v),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.ticked,
    required this.accent,
    required this.onChanged,
  });

  final KnownModel model;
  final bool ticked;
  final Color accent;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step3),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(
          color: ticked ? accent.withValues(alpha: 0.32) : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesignSystemCheckbox(
            value: ticked,
            onChanged: onChanged,
            semanticsLabel: model.name,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  model.providerModelId,
                  style: tokens.typography.styles.others.caption.copyWith(
                    fontFamily: 'Inconsolata',
                    color: tokens.colors.text.lowEmphasis,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: tokens.spacing.step2),
                _CapabilityChips(model: model),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlreadyAddedSection extends StatelessWidget {
  const _AlreadyAddedSection({required this.models});

  final List<AiConfigModel> models;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          label: messages.aiSetupPreviewAlreadyAddedSectionLabel,
          count: models.length,
          subdued: true,
        ),
        SizedBox(height: tokens.spacing.step3),
        ...models.map(
          (model) => Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step3),
            child: _ReadOnlyModelRow(model: model),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyModelRow extends StatelessWidget {
  const _ReadOnlyModelRow({required this.model});

  final AiConfigModel model;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step3),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 20,
            color: tokens.colors.text.lowEmphasis,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  model.providerModelId,
                  style: tokens.typography.styles.others.caption.copyWith(
                    fontFamily: 'Inconsolata',
                    color: tokens.colors.text.lowEmphasis,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: tokens.spacing.step2),
                _StoredModelCapabilityChips(model: model),
              ],
            ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    this.subdued = false,
  });

  final String label;
  final int count;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = subdued
        ? tokens.colors.text.lowEmphasis
        : tokens.colors.text.mediumEmphasis;
    return Row(
      children: [
        Text(
          label,
          style: tokens.typography.styles.others.overline.copyWith(
            color: color,
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Text(
          '· $count',
          style: tokens.typography.styles.others.overline.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CapabilityChips extends StatelessWidget {
  const _CapabilityChips({required this.model});

  final KnownModel model;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final labels = _capabilityLabelsFor(
      messages: messages,
      isReasoning: model.isReasoningModel,
      inputModalities: model.inputModalities,
      outputModalities: model.outputModalities,
    );
    return _ChipRow(labels: labels);
  }
}

class _StoredModelCapabilityChips extends StatelessWidget {
  const _StoredModelCapabilityChips({required this.model});

  final AiConfigModel model;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final labels = _capabilityLabelsFor(
      messages: messages,
      isReasoning: model.isReasoningModel,
      inputModalities: model.inputModalities,
      outputModalities: model.outputModalities,
    );
    return _ChipRow(labels: labels);
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final label in labels)
          DesignSystemBadge.filled(
            label: label,
            tone: DesignSystemBadgeTone.secondary,
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Pure helpers
// --------------------------------------------------------------------------

List<String> _capabilityLabelsFor({
  required AppLocalizations messages,
  required bool isReasoning,
  required List<Modality> inputModalities,
  required List<Modality> outputModalities,
}) {
  final out = <String>[];
  if (isReasoning) {
    out.add(messages.aiCapabilityChipThinking);
  }
  if (inputModalities.contains(Modality.image)) {
    out.add(messages.aiCapabilityChipImageRecognition);
  }
  if (inputModalities.contains(Modality.audio)) {
    out.add(messages.aiCapabilityChipTranscription);
  }
  if (outputModalities.contains(Modality.image)) {
    out.add(messages.aiCapabilityChipImageGeneration);
  }
  return out;
}

Color _providerAccent(InferenceProviderType type, DsTokens tokens) {
  return switch (type) {
    InferenceProviderType.gemini => tokens.colors.aiProvider.gemini.color,
    InferenceProviderType.openAi => tokens.colors.aiProvider.openAi.color,
    InferenceProviderType.anthropic => tokens.colors.aiProvider.anthropic.color,
    InferenceProviderType.ollama => tokens.colors.aiProvider.ollama.color,
    // Providers without a dedicated brand token (Mistral, Alibaba,
    // Generic, etc.) fall back to the neutral interactive token rather
    // than impersonating Gemini's teal.
    _ => tokens.colors.interactive.enabled,
  };
}

// --------------------------------------------------------------------------
// Per-provider presets
// --------------------------------------------------------------------------

// Each preset factory returns null if the underlying canonical
// model lookup fails. In debug builds the assert above the null
// check fires loudly so the missing entry surfaces during development;
// in release the workflow falls back to the empty-preset path in
// `show()`, which skips the modal cleanly instead of crashing.

AiProviderSetupPreviewPreset? _geminiPreset() {
  final known = getFtueKnownModels();
  assert(known != null, 'Gemini FTUE known-model lookup returned null');
  if (known == null) return null;
  return AiProviderSetupPreviewPreset(
    providerName: 'Gemini',
    profileName: 'Gemini Flash',
    categoryName: ftueGeminiCategoryName,
    models: <KnownModel>[known.flash, known.pro, known.image],
  );
}

AiProviderSetupPreviewPreset? _openAiPreset() {
  final known = getOpenAiFtueKnownModels();
  assert(known != null, 'OpenAI FTUE known-model lookup returned null');
  if (known == null) return null;
  return AiProviderSetupPreviewPreset(
    providerName: 'OpenAI',
    profileName: 'OpenAI',
    categoryName: ftueOpenAiCategoryName,
    models: <KnownModel>[
      known.flash,
      known.reasoning,
      known.audio,
      known.image,
    ],
  );
}

AiProviderSetupPreviewPreset? _mistralPreset() {
  final known = getMistralFtueKnownModels();
  assert(known != null, 'Mistral FTUE known-model lookup returned null');
  if (known == null) return null;
  return AiProviderSetupPreviewPreset(
    providerName: 'Mistral',
    profileName: 'Mistral (EU)',
    categoryName: ftueMistralCategoryName,
    models: <KnownModel>[known.flash, known.reasoning, known.audio],
  );
}

AiProviderSetupPreviewPreset? _alibabaPreset() {
  final known = getAlibabaFtueKnownModels();
  assert(known != null, 'Alibaba FTUE known-model lookup returned null');
  if (known == null) return null;
  return AiProviderSetupPreviewPreset(
    providerName: 'Alibaba Cloud (Qwen)',
    profileName: 'Chinese AI Profile',
    categoryName: ftueAlibabaCategoryName,
    models: <KnownModel>[
      known.flash,
      known.reasoning,
      known.vision,
      known.audio,
      known.image,
    ],
  );
}

AiProviderSetupPreviewPreset? _anthropicPreset() {
  final known = getAnthropicFtueKnownModels();
  assert(known != null, 'Anthropic FTUE known-model lookup returned null');
  if (known == null) return null;
  return AiProviderSetupPreviewPreset(
    providerName: 'Anthropic',
    profileName: 'Anthropic Claude',
    categoryName: ftueAnthropicCategoryName,
    models: <KnownModel>[known.reasoning, known.flash],
  );
}

AiProviderSetupPreviewPreset _ollamaPreset() {
  // Ollama serves locally-pulled models. No preset model list — the
  // caller short-circuits via `skipsPreviewFor` and goes straight to
  // the result modal.
  return const AiProviderSetupPreviewPreset(
    providerName: 'Ollama',
    profileName: 'Local (Ollama)',
    categoryName: ftueOllamaCategoryName,
    models: <KnownModel>[],
  );
}
