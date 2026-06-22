import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_provider_setup_preview_models.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The ticked "New models" section of the setup-preview modal.
///
/// Renders one checkbox row per proposed [KnownModel]. A row is ticked when
/// its `providerModelId` is NOT in [excluded]; toggling a box calls [onToggle]
/// with the id and the new value so the modal can maintain the excluded set.
/// All rows start ticked.
class NewModelsSection extends StatelessWidget {
  const NewModelsSection({
    required this.models,
    required this.excluded,
    required this.accent,
    required this.onToggle,
    super.key,
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

/// The read-only "Already added" section of the setup-preview modal.
///
/// Lists preset models the provider already owns (resolved from the saved
/// [AiConfigModel] rows) with a check-circle marker and capability chips, but
/// no checkboxes — these can't be re-added, they're shown so the user
/// understands the preset overlaps their existing setup. Hidden by the modal
/// when [models] is empty.
class AlreadyAddedSection extends StatelessWidget {
  const AlreadyAddedSection({required this.models, super.key});

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
    final labels = modelCapabilityLabels(
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
    final labels = modelCapabilityLabels(
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

// `modelCapabilityLabels` and the accent helper both live in
// `ai_provider_visual.dart` so the preview modal, the result modal,
// and the AI Settings cards share one source of truth for the
// capability-chip labelling and the per-provider chrome.

// Provider accent now routes through the shared `aiProviderAccent`
// helper so the preview modal, the result modal, and the AI Settings
// cards can't drift on per-provider chrome.

// --------------------------------------------------------------------------
// Per-provider presets
// --------------------------------------------------------------------------

// Each preset factory returns null if the underlying canonical
// model lookup fails. In debug builds the assert above the null
// check fires loudly so the missing entry surfaces during development;
// in release the workflow falls back to the empty-preset path in
// `show()`, which skips the modal cleanly instead of crashing.

/// FTUE preset for Gemini: the "Gemini Flash" profile plus the Flash, Pro,
/// and image models. Null when the canonical lookup fails (see note above).
AiProviderSetupPreviewPreset? geminiPreset() {
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

/// FTUE preset for OpenAI: the "OpenAI" profile plus the flash, reasoning,
/// audio, and image models. Null when the canonical lookup fails.
AiProviderSetupPreviewPreset? openAiPreset() {
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

/// FTUE preset for Mistral: the EU-hosted "Mistral (EU)" profile plus the
/// flash, reasoning, and audio models. Null when the canonical lookup fails.
AiProviderSetupPreviewPreset? mistralPreset() {
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

/// FTUE preset for Melious: the default Melious profile plus thinking,
/// high-end thinking, and Whisper transcription models.
AiProviderSetupPreviewPreset? meliousPreset() {
  final known = getMeliousFtueKnownModels();
  assert(known != null, 'Melious FTUE known-model lookup returned null');
  if (known == null) return null;
  return AiProviderSetupPreviewPreset(
    providerName: 'Melious.ai',
    profileName: 'Melious.ai',
    categoryName: ftueMeliousCategoryName,
    models: <KnownModel>[
      known.thinking,
      known.advancedThinking,
      known.whisperTurbo,
      known.whisper,
    ],
  );
}

/// FTUE preset for Alibaba Cloud (Qwen): the "Chinese AI Profile" plus the
/// flash, reasoning, vision, audio, and image models. Null on lookup failure.
AiProviderSetupPreviewPreset? alibabaPreset() {
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

/// FTUE preset for Anthropic: the "Anthropic Claude" profile plus the
/// reasoning and flash models. Null when the canonical lookup fails.
AiProviderSetupPreviewPreset? anthropicPreset() {
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

/// FTUE preset for Ollama: the "Local (Ollama)" profile with an empty model
/// list. Non-nullable — Ollama has no canonical lookup to fail.
AiProviderSetupPreviewPreset ollamaPreset() {
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
