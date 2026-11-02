import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';

/// The outfits she changes between: the grandmother's looks, in order.
final List<CompanionLook> companionOutfits = CompanionLook.of(
  CompanionSpecies.grandma,
);

/// Where a surprise outfit is drawn from; a test swaps it for a seeded one.
final companionOutfitRandomProvider = Provider<math.Random>(
  (ref) => math.Random(),
  name: 'companionOutfitRandomProvider',
);

/// The outfit picked on her full-screen stage this session, or null while
/// she follows her customization.
///
/// [CompanionOutfitController.next] sets it; a new outfit chosen in settings
/// clears it, so the settings choice starts over.
final companionOutfitProvider =
    NotifierProvider<CompanionOutfitController, CompanionLook?>(
      CompanionOutfitController.new,
      name: 'companionOutfitProvider',
    );

class CompanionOutfitController extends Notifier<CompanionLook?> {
  @override
  CompanionLook? build() {
    ref.watch(companionCustomizationProvider.select((c) => c.outfitId));
    return null;
  }

  /// Changes into the outfit after the one she wears now, back to the first
  /// after the last. The outfit she wears now is the one her last draw
  /// showed, so the step follows what the person saw.
  void next() {
    final worn = ref.read(companionWornOutfitProvider).last;
    final at = worn == null ? -1 : companionOutfits.indexOf(worn);
    state = companionOutfits[(at + 1) % companionOutfits.length];
  }
}

/// The outfit her latest draw dressed her in, for the stage to step from.
///
/// A plain holder rather than state: a draw happens in a build, and writing
/// state there is not allowed. Nothing watches it, so it cannot cycle.
class CompanionWornOutfit {
  /// The outfit the most recent draw showed, or null before any.
  CompanionLook? last;
}

final companionWornOutfitProvider = Provider<CompanionWornOutfit>(
  (ref) => CompanionWornOutfit(),
  name: 'companionWornOutfitProvider',
);

/// One set of choices for dressing her: the stored customization, the
/// stage's pick for the session, and the random source for "Surprise me".
///
/// Nothing is drawn until [draw] is called, and every call without a pick
/// draws again. Hosts call it in their `build`, so a rebuilt widget dresses
/// her in a fresh surprise outfit; the widget only rebuilds on what changes
/// it (a setting, a voice starting or stopping), never per animation frame.
class CompanionLookRoll {
  CompanionLookRoll({
    required this.customization,
    required this.picked,
    required this.random,
    required this.worn,
  });

  final CompanionCustomization customization;

  /// The outfit picked on the stage, or null.
  final CompanionLook? picked;

  final math.Random random;

  /// Where each draw records the outfit it showed.
  final CompanionWornOutfit worn;

  /// What she wears now: the stage's pick, else the outfit chosen in her
  /// customization, else a surprise outfit drawn at random — in the skin and
  /// hair of her customization ([CompanionCustomization.dress]).
  CompanionLook draw() {
    final outfit = picked ?? _chosenOutfit() ?? _surprise();
    worn.last = outfit;
    return customization.dress(outfit);
  }

  CompanionLook? _chosenOutfit() {
    final chosen = customization.outfitId;
    for (final outfit in companionOutfits) {
      if (outfit.id == chosen) return outfit;
    }
    return null;
  }

  CompanionLook _surprise() =>
      companionOutfits[random.nextInt(companionOutfits.length)];
}

/// The roll every host dresses her with. It changes when the customization
/// or the stage's pick changes; the draw itself happens in each host's build.
final companionLookRollProvider = Provider<CompanionLookRoll>(
  (ref) => CompanionLookRoll(
    customization: ref.watch(companionCustomizationProvider),
    picked: ref.watch(companionOutfitProvider),
    random: ref.watch(companionOutfitRandomProvider),
    worn: ref.watch(companionWornOutfitProvider),
  ),
  name: 'companionLookRollProvider',
);
