import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';

/// The outfits she changes between: the grandmother's looks, in order.
final List<CompanionLook> companionOutfits = CompanionLook.of(
  CompanionSpecies.grandma,
);

/// Where her first outfit of the session is drawn from; a test swaps it for
/// a seeded one.
final companionOutfitRandomProvider = Provider<math.Random>(
  (ref) => math.Random(),
  name: 'companionOutfitRandomProvider',
);

/// What she wears this session, on every screen she appears on.
///
/// The outfit the person chose in her customization, or — when they left it
/// to her — one drawn at random the first time she is shown and kept until
/// the app is closed, so she does not change clothes between screens.
/// [CompanionOutfitController.next] changes it for the session, from the
/// control on her full-screen stage; a new choice in settings starts over
/// from that choice.
final companionOutfitProvider =
    NotifierProvider<CompanionOutfitController, CompanionLook>(
      CompanionOutfitController.new,
      name: 'companionOutfitProvider',
    );

class CompanionOutfitController extends Notifier<CompanionLook> {
  @override
  CompanionLook build() {
    final chosen = ref.watch(
      companionCustomizationProvider.select((c) => c.outfitId),
    );
    for (final outfit in companionOutfits) {
      if (outfit.id == chosen) return outfit;
    }
    final random = ref.read(companionOutfitRandomProvider);
    return companionOutfits[random.nextInt(companionOutfits.length)];
  }

  /// Changes into the next outfit, back to the first after the last.
  void next() {
    final at = companionOutfits.indexOf(state);
    state = companionOutfits[(at + 1) % companionOutfits.length];
  }
}

/// How she is drawn on every screen: the session's outfit
/// ([companionOutfitProvider]) in the skin and hair of her customization
/// ([companionCustomizationProvider]).
final companionLookProvider = Provider<CompanionLook>(
  (ref) => ref
      .watch(companionCustomizationProvider)
      .dress(ref.watch(companionOutfitProvider)),
  name: 'companionLookProvider',
);
