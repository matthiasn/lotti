import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';

void main() {
  /// Lotti's outfits, in order: what she changes between.
  final companionOutfits = CompanionLook.of(CompanionSpecies.grandma);

  /// The grandpa's outfits, in order.
  final hisOutfits = CompanionLook.of(CompanionSpecies.grandpa);

  /// A customization that has chosen the grandpa, his outfit a surprise.
  const grandpa = CompanionCustomization(character: CompanionSpecies.grandpa);

  /// A container whose session seed is [seed] and whose customization is
  /// [customization], not read from storage.
  ProviderContainer containerWith({
    int seed = 7,
    CompanionCustomization customization = const CompanionCustomization(),
  }) {
    final container = ProviderContainer(
      overrides: [
        companionOutfitSeedProvider.overrideWithValue(seed),
        companionCustomizationProvider.overrideWithBuild(
          (ref, notifier) => customization,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// A roll with nothing picked and nothing chosen: every draw a surprise.
  CompanionLookRoll surpriseRoll(int seed) => CompanionLookRoll(
    customization: const CompanionCustomization(),
    picked: null,
    seed: seed,
  );

  /// What she wears for [subject], by outfit id.
  String worn(ProviderContainer container, [String subject = 'task-1']) =>
      container.read(companionLookRollProvider).draw(subject).id;

  group('the outfits of the roll', () {
    test("are Lotti's looks, in order, by default", () {
      expect(surpriseRoll(7).outfits, companionOutfits);
      expect(companionOutfits.length, greaterThanOrEqualTo(4));
    });

    test("are the grandpa's once he is chosen", () {
      final roll = CompanionLookRoll(
        customization: grandpa,
        picked: null,
        seed: 7,
      );
      expect(roll.outfits, hisOutfits);
    });
  });

  group('companionOutfitSeedProvider', () {
    test('draws a non-negative 31-bit seed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final seed = container.read(companionOutfitSeedProvider);
      expect(seed, inInclusiveRange(0, (1 << 31) - 1));
    });

    test('is drawn once: every read in a session sees the same seed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final first = container.read(companionOutfitSeedProvider);
      expect(container.read(companionOutfitSeedProvider), first);
    });
  });

  group('surprise me', () {
    test('dresses her in one of her outfits', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(
          companionOutfits,
          contains(surpriseRoll(seed).outfitFor('task-$seed')),
        );
      }
    });

    test('is the same outfit on every draw for the same subject', () {
      final roll = surpriseRoll(7);
      final first = roll.outfitFor('task-1');
      for (var i = 0; i < 20; i++) {
        expect(roll.outfitFor('task-1'), same(first));
        expect(roll.draw('task-1').id, first.id);
      }
    });

    test('is the same outfit from a roll built afresh with the same seed — '
        'a remounted host dresses her as before', () {
      expect(
        surpriseRoll(7).outfitFor('task-1'),
        surpriseRoll(7).outfitFor('task-1'),
      );
    });

    test('differs between subjects, so tasks do not all look alike', () {
      final roll = surpriseRoll(7);
      final outfits = {
        for (var i = 0; i < 60; i++) roll.outfitFor('task-$i'),
      };
      expect(outfits.length, greaterThan(1));
    });

    test('differs between sessions for the same subject', () {
      final outfits = {
        for (var seed = 0; seed < 60; seed++)
          surpriseRoll(seed).outfitFor('task-1'),
      };
      expect(outfits.length, greaterThan(1));
    });

    test('reaches every outfit across subjects', () {
      final roll = surpriseRoll(7);
      final outfits = {
        for (var i = 0; i < 400; i++) roll.outfitFor('subject-$i'),
      };
      expect(outfits, companionOutfits.toSet());
    });

    test('dresses her for an empty subject too', () {
      expect(companionOutfits, contains(surpriseRoll(7).outfitFor('')));
    });
  });

  group('a rebuild of the roll', () {
    // The regression: her outfit changed while a task was on screen,
    // because every rebuild drew a new one.
    test('for a change that is not her outfit keeps what she wears', () {
      final container = containerWith();
      final before = worn(container);
      // Every skin tone at every sass: eighteen rebuilds, and not one may
      // change her clothes.
      for (final skinTone in CompanionSkinTone.values) {
        for (final sass in CompanionSass.values) {
          container
              .read(companionCustomizationProvider.notifier)
              .set(
                CompanionCustomization(
                  skinTone: skinTone,
                  hairStyle: CompanionHairStyle.locs,
                  sass: sass,
                ),
              );
          expect(worn(container), before, reason: '$skinTone $sass');
        }
      }
    });
  });

  group('precedence', () {
    test('a chosen outfit is worn for every subject', () {
      final container = containerWith(
        customization: const CompanionCustomization(
          outfitId: 'grandma_winter',
        ),
      );
      for (var i = 0; i < 10; i++) {
        expect(worn(container, 'task-$i'), CompanionLook.grandmaWinter.id);
      }
    });

    test('a chosen outfit that is not one of hers falls back to the '
        'surprise', () {
      // A cat look is a known look, but not one of the grandmother's outfits.
      final roll = CompanionLookRoll(
        customization: const CompanionCustomization(outfitId: 'cat'),
        picked: null,
        seed: 7,
      );
      expect(roll.outfitFor('task-1'), surpriseRoll(7).outfitFor('task-1'));
    });

    test('the stage pick wins over a chosen outfit', () {
      final roll = CompanionLookRoll(
        customization: const CompanionCustomization(
          outfitId: 'grandma_winter',
        ),
        picked: CompanionLook.grandmaRock,
        seed: 7,
      );
      expect(roll.outfitFor('task-1'), CompanionLook.grandmaRock);
    });

    test('the stage pick wins over the surprise, for every subject', () {
      final roll = CompanionLookRoll(
        customization: const CompanionCustomization(),
        picked: CompanionLook.grandmaGarden,
        seed: 7,
      );
      for (var i = 0; i < 10; i++) {
        expect(roll.outfitFor('task-$i'), CompanionLook.grandmaGarden);
      }
    });
  });

  group('draw', () {
    test('is the outfit for the subject in the skin and hair of her '
        'customization', () {
      const custom = CompanionCustomization(
        skinTone: CompanionSkinTone.tone6,
        hairStyle: CompanionHairStyle.afro,
        hairColour: CompanionHairColour.lavender,
      );
      final roll = CompanionLookRoll(
        customization: custom,
        picked: null,
        seed: 7,
      );
      final outfit = roll.outfitFor('task-1');
      final look = roll.draw('task-1');
      expect(look.id, outfit.id);
      expect(look.hairStyle, CompanionHairStyle.afro);
      expect(look.palette.skin, CompanionSkinTone.tone6.skin);
      expect(look.palette.hair, CompanionHairColour.lavender.hair);
      expect(look.palette.dress, outfit.palette.dress);
    });
  });

  group('the stage pick', () {
    test('next steps from the outfit she wears for the subject', () {
      final container = containerWith();
      final from = container
          .read(companionLookRollProvider)
          .outfitFor('task-1');
      container.read(companionOutfitProvider.notifier).next(from);
      final at = companionOutfits.indexOf(from);
      expect(
        worn(container),
        companionOutfits[(at + 1) % companionOutfits.length].id,
      );
    });

    test('next from the last outfit goes back to the first', () {
      final container = containerWith();
      container
          .read(companionOutfitProvider.notifier)
          .next(companionOutfits.last);
      expect(worn(container), companionOutfits.first.id);
    });

    test('holds for every subject while nothing in settings changes', () {
      final container = containerWith();
      final sub = container.listen(companionOutfitProvider, (_, _) {});
      addTearDown(sub.close);
      container
          .read(companionOutfitProvider.notifier)
          .next(companionOutfits.first);
      expect(worn(container), companionOutfits[1].id);
      expect(worn(container, 'goal-2'), companionOutfits[1].id);
    });

    test('is cleared by a new outfit chosen in settings', () {
      final container = containerWith();
      final sub = container.listen(companionOutfitProvider, (_, _) {});
      addTearDown(sub.close);
      container
          .read(companionOutfitProvider.notifier)
          .next(companionOutfits.first);
      expect(container.read(companionOutfitProvider), companionOutfits[1]);

      container
          .read(companionCustomizationProvider.notifier)
          .set(const CompanionCustomization(outfitId: 'grandma_rock'));
      expect(container.read(companionOutfitProvider), isNull);
      expect(worn(container), CompanionLook.grandmaRock.id);
    });
  });

  group('with the grandpa chosen', () {
    test('surprise me draws only his outfits, and reaches every one', () {
      final roll = CompanionLookRoll(
        customization: grandpa,
        picked: null,
        seed: 7,
      );
      final drawn = {for (var i = 0; i < 400; i++) roll.outfitFor('s-$i')};
      expect(drawn, hisOutfits.toSet());
    });

    test('his chosen outfit is worn, dressed as him', () {
      final container = containerWith(
        customization: grandpa.copyWith(outfitId: () => 'grandpa_market'),
      );
      final look = container.read(companionLookRollProvider).draw('task-1');
      expect(look.id, 'grandpa_market');
      expect(look.species, CompanionSpecies.grandpa);
      expect(look.flatCap, isTrue);
    });

    test("an outfit of Lotti's is not worn by him", () {
      final roll = CompanionLookRoll(
        customization: grandpa.copyWith(outfitId: () => 'grandma_rock'),
        picked: null,
        seed: 7,
      );
      expect(hisOutfits, contains(roll.outfitFor('task-1')));
    });

    test('next steps among his outfits and wraps from the last', () {
      final container = containerWith(customization: grandpa);
      final notifier = container.read(companionOutfitProvider.notifier)
        ..next(CompanionLook.grandpaJazz);
      expect(worn(container), CompanionLook.grandpaSeaside.id);
      notifier.next(CompanionLook.grandpaMarket);
      expect(worn(container), CompanionLook.grandpa.id);
    });

    // The regression: with "Surprise me" kept, the outfit id does not
    // change when the character does, and a pick of Lotti's outfit stayed on
    // the stage after the grandpa was chosen.
    test('choosing him clears a stage pick of her outfit', () {
      final container = containerWith();
      final sub = container.listen(companionOutfitProvider, (_, _) {});
      addTearDown(sub.close);
      container
          .read(companionOutfitProvider.notifier)
          .next(companionOutfits.first);
      expect(container.read(companionOutfitProvider), isNotNull);

      container.read(companionCustomizationProvider.notifier).set(grandpa);
      expect(container.read(companionOutfitProvider), isNull);
      expect(
        container.read(companionLookRollProvider).draw('task-1').species,
        CompanionSpecies.grandpa,
      );
    });
  });
}
