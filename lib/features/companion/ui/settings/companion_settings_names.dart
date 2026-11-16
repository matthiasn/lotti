import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/l10n/app_localizations.dart';

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
      CompanionHairStyle.long => m.companionSettingsHairStyleLong,
      CompanionHairStyle.waves => m.companionSettingsHairStyleWaves,
      CompanionHairStyle.ponytail => m.companionSettingsHairStylePonytail,
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

/// [eyes]' name in the picker, as a screen reader says it.
String eyeColourName(AppLocalizations m, CompanionEyeColour eyes) =>
    switch (eyes) {
      CompanionEyeColour.darkBrown => m.companionSettingsEyeColourDarkBrown,
      CompanionEyeColour.brown => m.companionSettingsEyeColourBrown,
      CompanionEyeColour.hazel => m.companionSettingsEyeColourHazel,
      CompanionEyeColour.amber => m.companionSettingsEyeColourAmber,
      CompanionEyeColour.green => m.companionSettingsEyeColourGreen,
      CompanionEyeColour.grey => m.companionSettingsEyeColourGrey,
      CompanionEyeColour.blue => m.companionSettingsEyeColourBlue,
    };

/// [sass]'s name in the picker.
String sassName(AppLocalizations m, CompanionSass sass) => switch (sass) {
  CompanionSass.warm => m.companionSettingsSassWarm,
  CompanionSass.cheeky => m.companionSettingsSassCheeky,
  CompanionSass.sassy => m.companionSettingsSassSassy,
};
