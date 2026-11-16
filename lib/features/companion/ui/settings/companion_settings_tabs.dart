import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/settings/companion_settings_names.dart';
import 'package:lotti/features/companion/ui/settings/companion_swatch_row.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/model/tts_voice.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_cloud_voices_section.dart';
import 'package:lotti/features/tts/ui/widgets/tts_model_selector.dart';
import 'package:lotti/features/tts/ui/widgets/tts_settings_sections.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';
import 'package:material_ui/material_ui.dart';

/// How she looks: who she is and what she wears, her hair, her skin and
/// eyes — three groups of things that belong together, not a box for each.
///
/// Choosing another character has the voice follow, a male one for the
/// grandpa and the uncle, until the user picked a voice themselves
/// ([TtsSettingsController.matchVoice]).
class CompanionLookTab extends ConsumerWidget {
  const CompanionLookTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = ref.watch(companionCustomizationProvider);
    final controller = ref.read(companionCustomizationProvider.notifier);
    final roll = ref.watch(companionLookRollProvider);
    final messages = context.messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsFormSection(
          title: messages.companionSettingsCharacterLabel,
          description: messages.companionSettingsCharacterDescription,
          children: [
            _ChipChoice<CompanionSpecies>(
              selected: custom.character,
              onSelected: (species) {
                controller.set(custom.asCharacter(species));
                // Nothing waits for the voice to follow: it is matched once
                // the stored pick is known.
                unawaited(
                  ref
                      .read(ttsSettingsControllerProvider.notifier)
                      .matchVoice(
                        species.masculine
                            ? TtsVoiceGender.male
                            : TtsVoiceGender.female,
                      ),
                );
              },
              choices: [
                for (final species in CompanionSpecies.choosable)
                  (species, characterName(messages, species)),
              ],
            ),
            _Labelled(
              label: messages.companionSettingsOutfitLabel,
              hint: messages.companionSettingsOutfitDescription,
              // No outfit is "Surprise me".
              child: _ChipChoice<String?>(
                selected: custom.outfitId,
                onSelected: (id) =>
                    controller.set(custom.copyWith(outfitId: () => id)),
                choices: [
                  (null, messages.companionSettingsOutfitSurprise),
                  for (final outfit in roll.outfits)
                    (outfit.id, outfitName(messages, outfit)),
                ],
              ),
            ),
          ],
        ),
        SettingsFormSection(
          title: messages.companionSettingsHairGroup,
          children: [
            _Labelled(
              label: messages.companionSettingsHairStyleLabel,
              // Chips, not a segmented toggle: ten styles do not fit a
              // phone's width in one row.
              child: _ChipChoice<CompanionHairStyle>(
                selected: custom.hairStyle,
                onSelected: (style) =>
                    controller.set(custom.copyWith(hairStyle: style)),
                choices: [
                  for (final style in CompanionHairStyle.values)
                    (style, hairStyleName(messages, style)),
                ],
              ),
            ),
            _Labelled(
              label: messages.companionSettingsHairColourLabel,
              child: CompanionSwatchRow<CompanionHairColour>(
                selected: custom.hairColour,
                onSelected: (colour) =>
                    controller.set(custom.copyWith(hairColour: colour)),
                swatches: [
                  for (final colour in CompanionHairColour.values)
                    (
                      value: colour,
                      colour: colour.hair,
                      label: hairColourName(messages, colour),
                    ),
                ],
              ),
            ),
          ],
        ),
        SettingsFormSection(
          title: messages.companionSettingsFaceGroup,
          children: [
            _Labelled(
              label: messages.companionSettingsSkinToneLabel,
              child: CompanionSwatchRow<CompanionSkinTone>(
                selected: custom.skinTone,
                onSelected: (tone) =>
                    controller.set(custom.copyWith(skinTone: tone)),
                swatches: [
                  for (final tone in CompanionSkinTone.values)
                    (
                      value: tone,
                      colour: tone.skin,
                      label: messages.companionSettingsSkinTone(tone.index + 1),
                    ),
                ],
              ),
            ),
            _Labelled(
              label: messages.companionSettingsEyeColourLabel,
              child: CompanionSwatchRow<CompanionEyeColour>(
                selected: custom.eyeColour,
                onSelected: (eyes) =>
                    controller.set(custom.copyWith(eyeColour: eyes)),
                swatches: [
                  for (final eyes in CompanionEyeColour.values)
                    (
                      value: eyes,
                      colour: eyes.iris,
                      label: eyeColourName(messages, eyes),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// How she sounds: whether she answers aloud, the voice she speaks with,
/// and how fast — the settings of the app's voice (`lib/features/tts/`),
/// the sections its Speech page is made of, here beside the figure they
/// speak from. What is technical, the speech
/// model and preparing audio ahead, comes last.
///
/// Without read-aloud switched on there is no voice to choose: only whether
/// she answers aloud is asked.
class CompanionVoiceTab extends ConsumerWidget {
  const CompanionVoiceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = ref.watch(companionCustomizationProvider);
    final controller = ref.read(companionCustomizationProvider.notifier);
    final readAloud =
        ref.watch(configFlagProvider(enableAiSummaryTtsFlag)).value ?? false;
    final messages = context.messages;

    final speaks = SettingsFormSection(
      title: messages.companionSettingsVoiceLabel,
      description: messages.companionSettingsVoiceDescription,
      children: [
        SettingsSwitchRow(
          key: const ValueKey('companion-speaks-replies'),
          title: messages.companionSettingsSpeakRepliesTitle,
          value: custom.speaksReplies,
          onChanged: (value) =>
              controller.set(custom.copyWith(speaksReplies: value)),
        ),
      ],
    );
    if (!readAloud) return speaks;

    final modelId = ref.watch(
      ttsSettingsControllerProvider.select((settings) => settings.modelId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        speaks,
        const TtsVoiceSection(),
        const TtsCloudVoicesSection(),
        const TtsSpeedSection(),
        SettingsFormSection(
          title: messages.companionSettingsAdvancedLabel,
          children: [
            TtsModelSelector(
              modelId: modelId,
              onChanged: ref
                  .read(ttsSettingsControllerProvider.notifier)
                  .setModel,
            ),
            const TtsAutoPrepareRow(described: true),
          ],
        ),
      ],
    );
  }
}

/// How she takes things: how much sass she reads with. A pick shows on her
/// at once ([onSass]).
class CompanionPersonalityTab extends ConsumerWidget {
  const CompanionPersonalityTab({required this.onSass, super.key});

  final ValueChanged<CompanionSass> onSass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sass = ref.watch(
      companionCustomizationProvider.select((custom) => custom.sass),
    );
    final messages = context.messages;
    return SettingsFormSection(
      title: messages.companionSettingsSassLabel,
      description: messages.companionSettingsSassDescription,
      children: [
        DsSegmentedToggle<CompanionSass>(
          expand: true,
          selected: sass,
          onChanged: onSass,
          segments: [
            for (final sass in CompanionSass.values)
              DsSegment(sass, sassName(messages, sass)),
          ],
        ),
      ],
    );
  }
}

/// A choice inside a group, under its own quiet [label] — and a [hint]
/// where the label alone does not say what is chosen.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child, this.hint});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        if (hint case final hint?)
          Text(
            hint,
            style: styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        SizedBox(height: tokens.spacing.step3),
        child,
      ],
    );
  }
}

/// One of [choices] picked from a wrap of chips, [selected] marked.
class _ChipChoice<T> extends StatelessWidget {
  const _ChipChoice({
    required this.selected,
    required this.onSelected,
    required this.choices,
  });

  final T selected;
  final ValueChanged<T> onSelected;
  final List<(T, String)> choices;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return Wrap(
      spacing: spacing.step2,
      runSpacing: spacing.step2,
      children: [
        for (final (value, label) in choices)
          DesignSystemChip(
            label: label,
            outlined: true,
            size: DesignSystemChipSize.touch,
            selected: value == selected,
            onPressed: () => onSelected(value),
          ),
      ],
    );
  }
}
