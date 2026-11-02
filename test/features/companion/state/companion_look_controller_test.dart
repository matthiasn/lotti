import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';

/// Draws the scripted indices in turn, repeating the last, and counts draws.
class _Scripted implements math.Random {
  _Scripted(this.indices);

  final List<int> indices;
  int draws = 0;

  @override
  int nextInt(int max) {
    final index = indices[draws < indices.length ? draws : indices.length - 1];
    draws++;
    return index;
  }

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

void main() {
  /// A container whose surprise outfits are drawn by [random] and whose
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

  /// What she wears on a draw of the roll, by outfit id.
  String wornAfterDraw(ProviderContainer container) =>
      container.read(companionLookRollProvider).draw().id;

  test('her outfits are the grandmother looks, in order', () {
    expect(companionOutfits, CompanionLook.of(CompanionSpecies.grandma));
    expect(companionOutfits.length, greaterThanOrEqualTo(4));
  });

  group('surprise me', () {
    test('draws one of her outfits', () {
      for (var seed = 0; seed < 20; seed++) {
        final container = containerWith(math.Random(seed));
        expect(
          companionOutfits.map((o) => o.id),
          contains(wornAfterDraw(container)),
        );
      }
    });

    test('draws again on every render, so she changes clothes each time she '
        'is shown', () {
      final random = _Scripted([0, 1, 2, 3]);
      final container = containerWith(random);
      final shown = [for (var i = 0; i < 4; i++) wornAfterDraw(container)];
      expect(shown, companionOutfits.take(4).map((o) => o.id).toList());
      expect(random.draws, 4);
    });

    test('a draw records what the host shows, when the host asks', () {
      final container = containerWith(_Scripted([2]));
      final shown = CompanionShownOutfit();
      expect(shown.last, isNull);
      container.read(companionLookRollProvider).draw(shown: shown);
      expect(shown.last, companionOutfits[2]);
    });

    test('a host drawn without a holder cannot overwrite what the stage '
        'shows', () {
      final container = containerWith(_Scripted([1, 2]));
      final stage = CompanionShownOutfit();
      final roll = container.read(companionLookRollProvider);
      roll.draw(shown: stage);
      expect(stage.last, companionOutfits[1]);
      roll.draw();
      expect(stage.last, companionOutfits[1]);
    });

    test('next steps from the outfit the stage shows', () {
      final container = containerWith(_Scripted([1]));
      final shown = CompanionShownOutfit();
      container.read(companionLookRollProvider).draw(shown: shown);
      container.read(companionOutfitProvider.notifier).next(from: shown.last);
      expect(wornAfterDraw(container), companionOutfits[2].id);
    });

    test('next from the last outfit goes back to the first', () {
      final container = containerWith(_Scripted([0]));
      container
          .read(companionOutfitProvider.notifier)
          .next(from: companionOutfits.last);
      expect(wornAfterDraw(container), companionOutfits.first.id);
    });

    test('next with nothing shown starts at the first outfit', () {
      final container = containerWith(_Scripted([0]));
      container.read(companionOutfitProvider.notifier).next();
      expect(wornAfterDraw(container), companionOutfits.first.id);
    });

    test('a stage pick holds until she is shown again with a settings '
        'change', () {
      final random = _Scripted([0, 1, 2]);
      final container = containerWith(random);
      final sub = container.listen(companionOutfitProvider, (_, _) {});
      addTearDown(sub.close);
      container
          .read(companionOutfitProvider.notifier)
          .next(from: companionOutfits.first);
      final drawsBefore = random.draws;
      expect(wornAfterDraw(container), companionOutfits[1].id);
      expect(wornAfterDraw(container), companionOutfits[1].id);
      expect(random.draws, drawsBefore, reason: 'a pick draws nothing');
    });

    test('a new choice in settings clears the stage pick', () {
      final container = containerWith(_Scripted([0]));
      final sub = container.listen(companionOutfitProvider, (_, _) {});
      addTearDown(sub.close);
      container
          .read(companionOutfitProvider.notifier)
          .next(from: companionOutfits.first);
      expect(container.read(companionOutfitProvider), companionOutfits[1]);

      container
          .read(companionCustomizationProvider.notifier)
          .set(const CompanionCustomization(outfitId: 'grandma_rock'));
      expect(container.read(companionOutfitProvider), isNull);
      expect(wornAfterDraw(container), CompanionLook.grandmaRock.id);
    });
  });

  group('a chosen outfit', () {
    test('is worn with no draw at all', () {
      final random = _Scripted([0]);
      final container = containerWith(
        random,
        customization: const CompanionCustomization(
          outfitId: 'grandma_winter',
        ),
      );
      expect(wornAfterDraw(container), CompanionLook.grandmaWinter.id);
      expect(wornAfterDraw(container), CompanionLook.grandmaWinter.id);
      expect(random.draws, 0);
    });
  });

  test('she is drawn in the outfit, in the skin and hair of her '
      'customization', () {
    const custom = CompanionCustomization(
      skinTone: CompanionSkinTone.tone6,
      hairStyle: CompanionHairStyle.afro,
      hairColour: CompanionHairColour.lavender,
    );
    final container = containerWith(_Scripted([3]), customization: custom);
    final look = container.read(companionLookRollProvider).draw();
    expect(look.id, companionOutfits[3].id);
    expect(look.hairStyle, CompanionHairStyle.afro);
    expect(look.palette.skin, CompanionSkinTone.tone6.skin);
    expect(look.palette.hair, CompanionHairColour.lavender.hair);
    expect(look.palette.dress, companionOutfits[3].palette.dress);
  });
}
