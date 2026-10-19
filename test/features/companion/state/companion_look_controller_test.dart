import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';

/// Draws [index] whatever the bound, and counts the draws.
class _Fixed implements math.Random {
  _Fixed(this.index);

  final int index;
  int draws = 0;

  @override
  int nextInt(int max) {
    draws++;
    return index;
  }

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

void main() {
  /// A container whose first outfit is drawn by [random] and whose
  /// customization is [customization], not read from storage.
  ProviderContainer containerWith(
    math.Random random, {
    CompanionCustomization customization = const CompanionCustomization(),
  }) {
    final container = ProviderContainer(
      overrides: [
        companionOutfitRandomProvider.overrideWithValue(random),
        companionCustomizationProvider.overrideWithBuild(
          (ref, notifier) => customization,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('her outfits are the grandmother looks, in order', () {
    expect(companionOutfits, CompanionLook.of(CompanionSpecies.grandma));
    expect(companionOutfits.length, greaterThanOrEqualTo(4));
  });

  group('the outfit', () {
    test('is drawn at random from all of hers, when none is chosen', () {
      final container = containerWith(_Fixed(2));
      expect(container.read(companionOutfitProvider), companionOutfits[2]);
    });

    test('is drawn once, and kept for the session', () {
      final random = _Fixed(1);
      final container = containerWith(random)..read(companionOutfitProvider);
      final sub = container.listen(companionOutfitProvider, (_, _) {});
      addTearDown(sub.close);
      expect(container.read(companionOutfitProvider), companionOutfits[1]);
      expect(random.draws, 1);
    });

    test('a real random draw is always one of her outfits', () {
      for (var seed = 0; seed < 20; seed++) {
        final container = containerWith(math.Random(seed));
        expect(
          companionOutfits,
          contains(container.read(companionOutfitProvider)),
        );
      }
    });

    test('is the chosen one, with no draw at all', () {
      final random = _Fixed(0);
      final container = containerWith(
        random,
        customization: const CompanionCustomization(
          outfitId: 'grandma_winter',
        ),
      );
      expect(
        container.read(companionOutfitProvider),
        CompanionLook.grandmaWinter,
      );
      expect(random.draws, 0);
    });

    test('next changes into the following outfit, back to the first after '
        'the last', () {
      final container = containerWith(_Fixed(companionOutfits.length - 2));
      final controller = container.read(companionOutfitProvider.notifier)
        ..next();
      expect(container.read(companionOutfitProvider), companionOutfits.last);
      controller.next();
      expect(container.read(companionOutfitProvider), companionOutfits.first);
    });

    test('a new choice in settings starts over from that choice', () {
      final container = containerWith(_Fixed(0));
      final sub = container.listen(companionOutfitProvider, (_, _) {});
      addTearDown(sub.close);
      container.read(companionOutfitProvider.notifier).next();
      expect(container.read(companionOutfitProvider), companionOutfits[1]);

      container
          .read(companionCustomizationProvider.notifier)
          .set(const CompanionCustomization(outfitId: 'grandma_rock'));
      expect(
        container.read(companionOutfitProvider),
        CompanionLook.grandmaRock,
      );
    });
  });

  test('she is drawn in the outfit, in the skin and hair of her '
      'customization', () {
    const custom = CompanionCustomization(
      skinTone: CompanionSkinTone.tone6,
      hairStyle: CompanionHairStyle.afro,
      hairColour: CompanionHairColour.lavender,
    );
    final container = containerWith(_Fixed(3), customization: custom);
    final look = container.read(companionLookProvider);
    expect(look.id, companionOutfits[3].id);
    expect(look.hairStyle, CompanionHairStyle.afro);
    expect(look.palette.skin, CompanionSkinTone.tone6.skin);
    expect(look.palette.hair, CompanionHairColour.lavender.hair);
    expect(look.palette.dress, companionOutfits[3].palette.dress);
  });
}
