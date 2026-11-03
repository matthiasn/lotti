import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';

/// The outfits she changes between: the grandmother's looks, in order.
final List<CompanionLook> companionOutfits = CompanionLook.of(
  CompanionSpecies.grandma,
);

/// The seed of this session's surprise outfits, drawn once when first read:
/// the same for every host while the app runs, a new one the next time it
/// starts. A test pins it.
final companionOutfitSeedProvider = Provider<int>(
  (ref) => math.Random().nextInt(1 << 31),
  name: 'companionOutfitSeedProvider',
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

  /// Changes into the outfit after [from] — the one the stage shows now
  /// ([CompanionLookRoll.outfitFor]) — back to the first after the last.
  void next(CompanionLook from) {
    final at = companionOutfits.indexOf(from);
    state = companionOutfits[(at + 1) % companionOutfits.length];
  }
}

/// One set of choices for dressing her: the stored customization, the
/// stage's pick for the session, and the session's seed for "Surprise me".
///
/// What she wears is a function of what she presents — the `subject`, the
/// id of the task, goal, day or conversation a host shows her for — and
/// never of when she is drawn. Hosts call [draw] in their `build`, and a
/// rebuild, a remount, or the full-screen stage opened from the same card
/// all dress her the same; another subject, or another session, may draw
/// another outfit.
class CompanionLookRoll {
  CompanionLookRoll({
    required this.customization,
    required this.picked,
    required this.seed,
  });

  final CompanionCustomization customization;

  /// The outfit picked on the stage, or null.
  final CompanionLook? picked;

  /// This session's seed for the surprise outfits.
  final int seed;

  /// What she wears for [subject]: the stage's pick, else the outfit chosen
  /// in her customization, else this session's surprise outfit for
  /// [subject] — in the skin and hair of her customization
  /// ([CompanionCustomization.dress]).
  CompanionLook draw(String subject) => customization.dress(outfitFor(subject));

  /// The outfit [draw] dresses her in for [subject], before her skin and
  /// hair: what the stage's palette control steps on from.
  CompanionLook outfitFor(String subject) =>
      picked ?? _chosenOutfit() ?? _surprise(subject);

  CompanionLook? _chosenOutfit() {
    final chosen = customization.outfitId;
    for (final outfit in companionOutfits) {
      if (outfit.id == chosen) return outfit;
    }
    return null;
  }

  /// One of her outfits for [subject], by an FNV-1a hash of its characters
  /// mixed with [seed]: the same for the same subject all session.
  CompanionLook _surprise(String subject) {
    var hash = 0x811C9DC5 ^ seed;
    for (final unit in subject.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7FFFFFFF;
    }
    return companionOutfits[hash % companionOutfits.length];
  }
}

/// The roll every host dresses her with. It changes when the customization
/// or the stage's pick changes; the draw itself happens in each host's build.
final companionLookRollProvider = Provider<CompanionLookRoll>(
  (ref) => CompanionLookRoll(
    customization: ref.watch(companionCustomizationProvider),
    picked: ref.watch(companionOutfitProvider),
    seed: ref.watch(companionOutfitSeedProvider),
  ),
  name: 'companionLookRollProvider',
);
