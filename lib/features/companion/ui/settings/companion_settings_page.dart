import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/companion/ui/settings/companion_swatch_row.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/pages/sliver_box_adapter_page.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';
import 'package:material_ui/material_ui.dart';

/// The subject her preview here is dressed for: on "Surprise me", the
/// session's outfit for her settings, steady while choices are made.
@visibleForTesting
const companionSettingsDressedFor = 'companion-settings';

/// The mobile page for [CompanionSettingsBody], in the settings chrome.
class CompanionSettingsPage extends StatelessWidget {
  const CompanionSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsCompanionTitle,
      showBackButton: true,
      child: const CompanionSettingsBody(),
    );
  }
}

/// Where a person makes the companion their own: who it is (Lotti, the
/// grandpa, the aunt or the uncle), the outfit worn or none, so a fresh one is picked every time it
/// is shown, the skin tone, the hairstyle and its colour, and how much sass
/// it reads with.
///
/// The companion stands above the choices, head to toe and as a portrait,
/// in what is chosen, with the character and outfit pickers right under it;
/// every change shows at once and is stored
/// ([companionCustomizationProvider]). A sass picked shows too: she takes
/// a slip that way ([companionReaction], [companionSignOff]). Shared by the
/// mobile page and the desktop settings panel.
class CompanionSettingsBody extends ConsumerStatefulWidget {
  const CompanionSettingsBody({super.key});

  @override
  ConsumerState<CompanionSettingsBody> createState() =>
      _CompanionSettingsBodyState();
}

class _CompanionSettingsBodyState extends ConsumerState<CompanionSettingsBody> {
  final _preview = CompanionController();

  /// Makes her [sass] and has her show it: how she takes a slip.
  void _setSass(CompanionSass sass) {
    ref
        .read(companionCustomizationProvider.notifier)
        .set(ref.read(companionCustomizationProvider).copyWith(sass: sass));
    final gesture = companionReaction(-2, sass: sass).gesture;
    if (gesture != null) _preview.play(gesture);
    final face = companionSignOff(const [-2], sass: sass);
    if (face != null) _preview.flourish(face);
  }

  @override
  Widget build(BuildContext context) {
    final custom = ref.watch(companionCustomizationProvider);
    final controller = ref.read(companionCustomizationProvider.notifier);
    final roll = ref.watch(companionLookRollProvider);
    final look = roll.draw(companionSettingsDressedFor);
    final messages = context.messages;
    final spacing = context.designTokens.spacing;

    return SettingsContentArea(
      child: Padding(
        padding: EdgeInsets.only(top: spacing.step5, bottom: spacing.step6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Decorative: the choices below say in words what she shows.
            ExcludeSemantics(
              child: SizedBox(
                height: ControlSizes.companionCard,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: CompanionFraming.full.aspectRatio,
                      child: CompanionView(
                        key: const ValueKey('companionSettingsFull'),
                        look: look,
                        stage: true,
                        autoGestures: false,
                        controller: _preview,
                      ),
                    ),
                    SizedBox(width: spacing.step4),
                    AspectRatio(
                      aspectRatio: 1,
                      child: CompanionView(
                        key: const ValueKey('companionSettingsBust'),
                        look: look,
                        framing: CompanionFraming.bust,
                        stage: true,
                        autoGestures: false,
                        seed: 23,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.step5),
            // Who it is and what it wears are picked right under the
            // preview they change.
            SettingsFormSection(
              title: messages.companionSettingsCharacterLabel,
              description: messages.companionSettingsCharacterDescription,
              children: [
                _ChipChoice<CompanionSpecies>(
                  selected: custom.character,
                  onSelected: (species) =>
                      controller.set(custom.asCharacter(species)),
                  choices: [
                    for (final species in CompanionSpecies.choosable)
                      (species, characterName(messages, species)),
                  ],
                ),
              ],
            ),
            SettingsFormSection(
              title: messages.companionSettingsOutfitLabel,
              description: messages.companionSettingsOutfitDescription,
              children: [
                // No outfit is "Surprise me".
                _ChipChoice<String?>(
                  selected: custom.outfitId,
                  onSelected: (id) =>
                      controller.set(custom.copyWith(outfitId: () => id)),
                  choices: [
                    (null, messages.companionSettingsOutfitSurprise),
                    for (final outfit in roll.outfits)
                      (outfit.id, outfitName(messages, outfit)),
                  ],
                ),
              ],
            ),
            SettingsFormSection(
              title: messages.companionSettingsSkinToneLabel,
              children: [
                CompanionSwatchRow<CompanionSkinTone>(
                  selected: custom.skinTone,
                  onSelected: (tone) =>
                      controller.set(custom.copyWith(skinTone: tone)),
                  swatches: [
                    for (final tone in CompanionSkinTone.values)
                      (
                        value: tone,
                        colour: tone.skin,
                        label: messages.companionSettingsSkinTone(
                          tone.index + 1,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SettingsFormSection(
              title: messages.companionSettingsHairStyleLabel,
              children: [
                // Chips, not a segmented toggle: seven styles do not fit a
                // phone's width in one row.
                _ChipChoice<CompanionHairStyle>(
                  selected: custom.hairStyle,
                  onSelected: (style) =>
                      controller.set(custom.copyWith(hairStyle: style)),
                  choices: [
                    for (final style in CompanionHairStyle.values)
                      (style, hairStyleName(messages, style)),
                  ],
                ),
              ],
            ),
            SettingsFormSection(
              title: messages.companionSettingsHairColourLabel,
              children: [
                CompanionSwatchRow<CompanionHairColour>(
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
              ],
            ),
            SettingsFormSection(
              title: messages.companionSettingsSassLabel,
              description: messages.companionSettingsSassDescription,
              children: [
                DsSegmentedToggle<CompanionSass>(
                  expand: true,
                  selected: custom.sass,
                  onChanged: _setSass,
                  segments: [
                    for (final sass in CompanionSass.values)
                      DsSegment(sass, sassName(messages, sass)),
                  ],
                ),
              ],
            ),
            SettingsFormSection(
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
            ),
          ],
        ),
      ),
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

/// [species]' name in the picker; one of [CompanionSpecies.choosable].
String characterName(AppLocalizations m, CompanionSpecies species) =>
    switch (species) {
      CompanionSpecies.grandpa => m.companionSettingsCharacterGrandpa,
      CompanionSpecies.aunt => m.companionSettingsCharacterAunt,
      CompanionSpecies.uncle => m.companionSettingsCharacterUncle,
      _ => m.companionSettingsCharacterLotti,
    };

/// [style]'s name in the picker.
String hairStyleName(AppLocalizations m, CompanionHairStyle style) =>
    switch (style) {
      CompanionHairStyle.bun => m.companionSettingsHairStyleBun,
      CompanionHairStyle.curls => m.companionSettingsHairStyleCurls,
      CompanionHairStyle.afro => m.companionSettingsHairStyleAfro,
      CompanionHairStyle.locs => m.companionSettingsHairStyleLocs,
      CompanionHairStyle.bob => m.companionSettingsHairStyleBob,
      CompanionHairStyle.short => m.companionSettingsHairStyleShort,
      CompanionHairStyle.balding => m.companionSettingsHairStyleBalding,
    };

/// [colour]'s name in the picker, as a screen reader says it.
String hairColourName(AppLocalizations m, CompanionHairColour colour) =>
    switch (colour) {
      CompanionHairColour.silver => m.companionSettingsHairColourSilver,
      CompanionHairColour.white => m.companionSettingsHairColourWhite,
      CompanionHairColour.grey => m.companionSettingsHairColourGrey,
      CompanionHairColour.black => m.companionSettingsHairColourBlack,
      CompanionHairColour.brown => m.companionSettingsHairColourBrown,
      CompanionHairColour.auburn => m.companionSettingsHairColourAuburn,
      CompanionHairColour.pink => m.companionSettingsHairColourPink,
      CompanionHairColour.lavender => m.companionSettingsHairColourLavender,
      CompanionHairColour.blue => m.companionSettingsHairColourBlue,
    };

/// [outfit]'s name in the picker; one of a character's outfits. Each
/// character's first outfit is its everyday one.
String outfitName(AppLocalizations m, CompanionLook outfit) =>
    switch (outfit.id) {
      'grandma_stage' => m.companionSettingsOutfitStage,
      'grandma_rock' => m.companionSettingsOutfitRock,
      'grandma_garden' => m.companionSettingsOutfitGarden,
      'grandma_lavender' => m.companionSettingsOutfitLavender,
      'grandma_winter' => m.companionSettingsOutfitWinter,
      'grandpa_jazz' => m.companionSettingsOutfitJazz,
      'grandpa_seaside' => m.companionSettingsOutfitSeaside,
      'grandpa_market' => m.companionSettingsOutfitMarket,
      'aunt_studio' => m.companionSettingsOutfitStudio,
      'aunt_festival' => m.companionSettingsOutfitFestival,
      'aunt_weekend' => m.companionSettingsOutfitWeekend,
      'uncle_night' => m.companionSettingsOutfitNight,
      'uncle_skate' => m.companionSettingsOutfitSkate,
      'uncle_snow' => m.companionSettingsOutfitSnow,
      _ => m.companionSettingsOutfitEveryday,
    };

/// [sass]'s name in the picker.
String sassName(AppLocalizations m, CompanionSass sass) => switch (sass) {
  CompanionSass.warm => m.companionSettingsSassWarm,
  CompanionSass.cheeky => m.companionSettingsSassCheeky,
  CompanionSass.sassy => m.companionSettingsSassSassy,
};
