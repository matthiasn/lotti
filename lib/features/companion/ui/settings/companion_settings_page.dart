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

/// Where a person makes her their own: her skin tone, her hairstyle and its
/// colour, the outfit she wears or none, so she picks one each session, and
/// how much sass she reads with.
///
/// She stands above the choices, head to toe and as a portrait, in what is
/// chosen; every change shows at once and is stored
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
    final look = ref.watch(companionLookProvider);
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
                DsSegmentedToggle<CompanionHairStyle>(
                  expand: true,
                  selected: custom.hairStyle,
                  onChanged: (style) =>
                      controller.set(custom.copyWith(hairStyle: style)),
                  segments: [
                    for (final style in CompanionHairStyle.values)
                      DsSegment(style, hairStyleName(messages, style)),
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
            SettingsFormSection(
              title: messages.companionSettingsOutfitLabel,
              description: messages.companionSettingsOutfitDescription,
              children: [
                Wrap(
                  spacing: spacing.step2,
                  runSpacing: spacing.step2,
                  children: [
                    DesignSystemChip(
                      label: messages.companionSettingsOutfitSurprise,
                      selected: custom.outfitId == null,
                      onPressed: () =>
                          controller.set(custom.copyWith(outfitId: () => null)),
                    ),
                    for (final outfit in companionOutfits)
                      DesignSystemChip(
                        label: outfitName(messages, outfit),
                        selected: custom.outfitId == outfit.id,
                        onPressed: () => controller.set(
                          custom.copyWith(outfitId: () => outfit.id),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// [style]'s name in the picker.
String hairStyleName(AppLocalizations m, CompanionHairStyle style) =>
    switch (style) {
      CompanionHairStyle.bun => m.companionSettingsHairStyleBun,
      CompanionHairStyle.curls => m.companionSettingsHairStyleCurls,
      CompanionHairStyle.afro => m.companionSettingsHairStyleAfro,
      CompanionHairStyle.locs => m.companionSettingsHairStyleLocs,
      CompanionHairStyle.bob => m.companionSettingsHairStyleBob,
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

/// [outfit]'s name in the picker; one of [companionOutfits].
String outfitName(AppLocalizations m, CompanionLook outfit) =>
    switch (outfit.id) {
      'grandma_stage' => m.companionSettingsOutfitStage,
      'grandma_rock' => m.companionSettingsOutfitRock,
      'grandma_garden' => m.companionSettingsOutfitGarden,
      'grandma_lavender' => m.companionSettingsOutfitLavender,
      'grandma_winter' => m.companionSettingsOutfitWinter,
      _ => m.companionSettingsOutfitEveryday,
    };

/// [sass]'s name in the picker.
String sassName(AppLocalizations m, CompanionSass sass) => switch (sass) {
  CompanionSass.warm => m.companionSettingsSassWarm,
  CompanionSass.cheeky => m.companionSettingsSassCheeky,
  CompanionSass.sassy => m.companionSettingsSassSassy,
};
