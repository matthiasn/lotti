import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/world_handle.dart';

/// Creates and activates a guest world, honoring the required ordering:
/// the demo tree is FULLY populated (via a second, non-active set of
/// database handles) before the live documents layer is re-pointed at it —
/// the "migration" is the hot switch itself, not a data move.
class DemoWorldCreator {
  const DemoWorldCreator({
    required this.registry,
    required this.activate,
  });

  final ProfileRegistry registry;

  /// Switches the running app to the given profile id — in production this
  /// is `ProfileSwitcher.switchTo`.
  final Future<void> Function(String profileId) activate;

  /// Creates the profile, seeds its world through [seed], then switches the
  /// running app into it. If seeding throws, the half-built world is removed
  /// and the real world stays active.
  Future<Profile> createAndActivate({
    required Future<void> Function(WorldHandle world) seed,
    String name = 'Demo',
  }) async {
    final profile = await registry.createGuestProfile(name: name);
    final world = WorldHandle.open(registry.rootFor(profile));
    try {
      await seed(world);
    } catch (_) {
      await world.close();
      await registry.deleteGuestProfile(profile.id);
      rethrow;
    }
    await world.close();
    await activate(profile.id);
    return profile;
  }
}
