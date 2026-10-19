import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/companion/model/companion_look.dart';

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
/// Drawn at random from [companionOutfits] the first time she is shown, and
/// kept until the app is closed, so she does not change clothes between
/// screens. [CompanionLookController.next] changes it, from the control on
/// her full-screen stage.
///
/// Not a setting yet: a chosen, synced look is the customization branch's
/// (plan 2026-10-12, "Revision").
final companionLookProvider =
    NotifierProvider<CompanionLookController, CompanionLook>(
      CompanionLookController.new,
      name: 'companionLookProvider',
    );

class CompanionLookController extends Notifier<CompanionLook> {
  @override
  CompanionLook build() {
    final random = ref.read(companionOutfitRandomProvider);
    return companionOutfits[random.nextInt(companionOutfits.length)];
  }

  /// Changes into the next outfit, back to the first after the last.
  void next() {
    final at = companionOutfits.indexOf(state);
    state = companionOutfits[(at + 1) % companionOutfits.length];
  }
}
