import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/settings/companion_settings_page.dart';
import 'package:lotti/features/companion/ui/settings/companion_swatch_row.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_companion.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The optional "make me yours" step between the welcome and the one key:
/// the user picks her outfit, skin tone, hair and hair colour, and she wears
/// each pick as it is made.
///
/// Every pick is saved at once through [companionCustomizationProvider], the
/// same store Settings › Companion edits, so "Skip for now" keeps whatever was
/// already picked; it only moves on. [onCustomized] fires on the first pick,
/// once per visit.
class OnboardingMakeHerYoursStep extends ConsumerStatefulWidget {
  const OnboardingMakeHerYoursStep({
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
    required this.onCustomized,
    super.key,
  });

  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onCustomized;

  @override
  ConsumerState<OnboardingMakeHerYoursStep> createState() =>
      _OnboardingMakeHerYoursStepState();
}

class _OnboardingMakeHerYoursStepState
    extends ConsumerState<OnboardingMakeHerYoursStep> {
  var _customized = false;

  void _pick(CompanionCustomization Function(CompanionCustomization) change) {
    ref
        .read(companionCustomizationProvider.notifier)
        .set(change(ref.read(companionCustomizationProvider)));
    if (_customized) return;
    _customized = true;
    widget.onCustomized();
  }

  @override
  Widget build(BuildContext context) {
    final custom = ref.watch(companionCustomizationProvider);
    final messages = context.messages;
    return OnboardingMakeHerYoursView(
      title: messages.onboardingMakeHerYoursTitle,
      companion: OnboardingCompanion(
        beat: OnboardingCompanionBeat.dressUp,
        line: messages.onboardingMakeHerYoursLine,
      ),
      line: messages.onboardingMakeHerYoursLine,
      custom: custom,
      onOutfit: (id) => _pick((c) => c.copyWith(outfitId: () => id)),
      onSkinTone: (tone) => _pick((c) => c.copyWith(skinTone: tone)),
      onHairStyle: (style) => _pick((c) => c.copyWith(hairStyle: style)),
      onHairColour: (colour) => _pick((c) => c.copyWith(hairColour: colour)),
      onContinue: widget.onContinue,
      onSkip: widget.onSkip,
      onBack: widget.onBack,
    );
  }
}

/// The "make me yours" panel, free of providers: her preview beside her
/// bubble, then one row of choices per part of her look, then the buttons.
class OnboardingMakeHerYoursView extends StatelessWidget {
  const OnboardingMakeHerYoursView({
    required this.title,
    required this.companion,
    required this.line,
    required this.custom,
    required this.onOutfit,
    required this.onSkinTone,
    required this.onHairStyle,
    required this.onHairColour,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
    super.key,
  });

  final String title;

  /// Her, full length, wearing [custom].
  final Widget companion;

  /// Her line, in the bubble beside her.
  final String line;
  final CompanionCustomization custom;

  /// Called with the picked outfit's id, or null for "Surprise me".
  final ValueChanged<String?> onOutfit;
  final ValueChanged<CompanionSkinTone> onSkinTone;
  final ValueChanged<CompanionHairStyle> onHairStyle;
  final ValueChanged<CompanionHairColour> onHairColour;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final spacing = tokens.spacing;
    final textHigh = tokens.colors.text.highEmphasis;

    Widget section(String label, Widget control) => Padding(
      padding: EdgeInsets.only(top: spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: textHigh,
            ),
          ),
          SizedBox(height: spacing.step2),
          control,
        ],
      ),
    );

    DesignSystemChip chip({
      required String label,
      required bool selected,
      required VoidCallback onPressed,
    }) => DesignSystemChip(
      label: label,
      outlined: true,
      size: DesignSystemChipSize.touch,
      selected: selected,
      onPressed: onPressed,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: ColoredBox(
        color: tokens.colors.background.level01,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.step5,
            spacing.step5,
            spacing.step5,
            // Clear the home indicator when flush to the bottom as a sheet.
            spacing.step5 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack,
                  iconSize: spacing.step5,
                  color: textHigh,
                  icon: const Icon(LottiIcons.back),
                ),
              ),
              SizedBox(height: spacing.step2),
              Text(
                title,
                style: tokens.typography.styles.heading.heading3.copyWith(
                  color: textHigh,
                ),
              ),
              SizedBox(height: spacing.step3),
              Row(
                children: [
                  // Decorative: the choices below say in words what she shows.
                  ExcludeSemantics(
                    child: SizedBox(
                      height: ControlSizes.companionCard,
                      child: AspectRatio(
                        aspectRatio: CompanionFraming.full.aspectRatio,
                        child: companion,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.step2),
                  Expanded(
                    child: OnboardingSpeechBubble(
                      text: line,
                      tail: OnboardingBubbleTail.left,
                    ),
                  ),
                ],
              ),
              section(
                messages.companionSettingsOutfitLabel,
                Wrap(
                  spacing: spacing.step2,
                  runSpacing: spacing.step2,
                  children: [
                    chip(
                      label: messages.companionSettingsOutfitSurprise,
                      selected: custom.outfitId == null,
                      onPressed: () => onOutfit(null),
                    ),
                    for (final outfit in companionOutfits)
                      chip(
                        label: outfitName(messages, outfit),
                        selected: custom.outfitId == outfit.id,
                        onPressed: () => onOutfit(outfit.id),
                      ),
                  ],
                ),
              ),
              section(
                messages.companionSettingsSkinToneLabel,
                CompanionSwatchRow<CompanionSkinTone>(
                  selected: custom.skinTone,
                  onSelected: onSkinTone,
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
              ),
              section(
                messages.companionSettingsHairStyleLabel,
                Wrap(
                  spacing: spacing.step2,
                  runSpacing: spacing.step2,
                  children: [
                    for (final style in CompanionHairStyle.values)
                      chip(
                        label: hairStyleName(messages, style),
                        selected: custom.hairStyle == style,
                        onPressed: () => onHairStyle(style),
                      ),
                  ],
                ),
              ),
              section(
                messages.companionSettingsHairColourLabel,
                CompanionSwatchRow<CompanionHairColour>(
                  selected: custom.hairColour,
                  onSelected: onHairColour,
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
              SizedBox(height: spacing.step6),
              DesignSystemButton(
                onPressed: onContinue,
                label: messages.onboardingMakeHerYoursContinue,
                leadingIcon: LottiIcons.forward,
                size: DesignSystemButtonSize.large,
                fullWidth: true,
              ),
              SizedBox(height: spacing.step2),
              Center(
                child: DesignSystemButton(
                  onPressed: onSkip,
                  label: messages.onboardingMakeHerYoursSkip,
                  variant: DesignSystemButtonVariant.tertiary,
                  size: DesignSystemButtonSize.large,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
