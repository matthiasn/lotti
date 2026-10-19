import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
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
  ProviderContainer containerWith(math.Random random) {
    final container = ProviderContainer(
      overrides: [companionOutfitRandomProvider.overrideWithValue(random)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('her outfits are the grandmother looks, in order', () {
    expect(companionOutfits, CompanionLook.of(CompanionSpecies.grandma));
    expect(companionOutfits.length, greaterThanOrEqualTo(4));
  });

  test('the first outfit is drawn at random from all of hers', () {
    final random = _Fixed(2);
    final container = containerWith(random);
    expect(container.read(companionLookProvider), companionOutfits[2]);
  });

  test('it is drawn once, and kept for the session', () {
    final random = _Fixed(1);
    final container = containerWith(random)..read(companionLookProvider);
    final sub = container.listen(companionLookProvider, (_, _) {});
    addTearDown(sub.close);
    expect(container.read(companionLookProvider), companionOutfits[1]);
    expect(random.draws, 1);
  });

  test('a real random draw is always one of her outfits', () {
    for (var seed = 0; seed < 20; seed++) {
      final container = containerWith(math.Random(seed));
      expect(companionOutfits, contains(container.read(companionLookProvider)));
    }
  });

  test('next changes into the following outfit, back to the first after '
      'the last', () {
    final container = containerWith(_Fixed(companionOutfits.length - 2));
    final controller = container.read(companionLookProvider.notifier)..next();
    expect(container.read(companionLookProvider), companionOutfits.last);
    controller.next();
    expect(container.read(companionLookProvider), companionOutfits.first);
  });
}
