import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/ui/settings/companion_settings_names.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

void main() {
  test('every part and outfit has its own name', () {
    final AppLocalizations m = AppLocalizationsEn();
    expect(
      CompanionHairStyle.values.map((s) => hairStyleName(m, s)).toSet(),
      hasLength(CompanionHairStyle.values.length),
    );
    expect(
      CompanionHairColour.values.map((c) => hairColourName(m, c)).toSet(),
      hasLength(CompanionHairColour.values.length),
    );
    for (final species in CompanionSpecies.choosable) {
      final outfits = CompanionLook.of(species);
      expect(
        outfits.map((o) => outfitName(m, o)).toSet(),
        hasLength(outfits.length),
        reason: species.name,
      );
    }
    expect(
      CompanionSpecies.choosable.map((s) => characterName(m, s)).toList(),
      ['Lotti', 'Grandpa', 'Aunt', 'Uncle'],
    );
    expect(
      CompanionSass.values.map((s) => sassName(m, s)).toSet(),
      hasLength(CompanionSass.values.length),
    );
  });

  test("each character's first outfit is called Everyday", () {
    final AppLocalizations m = AppLocalizationsEn();
    expect(outfitName(m, CompanionLook.grandma), 'Everyday');
    expect(outfitName(m, CompanionLook.grandpa), 'Everyday');
    expect(
      [
        CompanionLook.grandpaJazz,
        CompanionLook.grandpaSeaside,
        CompanionLook.grandpaMarket,
      ].map((o) => outfitName(m, o)),
      ['Jazz', 'Seaside', 'Market day'],
    );
    expect(outfitName(m, CompanionLook.aunt), 'Everyday');
    expect(
      [
        CompanionLook.auntStudio,
        CompanionLook.auntFestival,
        CompanionLook.auntWeekend,
      ].map((o) => outfitName(m, o)),
      ['Studio', 'Festival', 'Weekend'],
    );
    expect(outfitName(m, CompanionLook.uncle), 'Everyday');
    expect(
      [
        CompanionLook.uncleNight,
        CompanionLook.uncleSkate,
        CompanionLook.uncleSnow,
      ].map((o) => outfitName(m, o)),
      ['Night out', 'Skate park', 'Snow day'],
    );
  });

  test('every eye colour has its own name', () {
    final AppLocalizations m = AppLocalizationsEn();
    expect(
      CompanionEyeColour.values.map((e) => eyeColourName(m, e)).toSet(),
      hasLength(CompanionEyeColour.values.length),
    );
  });
}
