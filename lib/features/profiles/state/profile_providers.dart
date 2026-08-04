import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';

/// The active world's context. Overridden per service generation in the
/// root ProviderScope (see `buildProviderOverrides`); resolving it without
/// an override is a wiring bug and fails loudly.
final profileContextProvider = Provider<ProfileContext>(
  (ref) => throw UnimplementedError(
    'profileContextProvider must be overridden in the root ProviderScope',
  ),
);

/// Whether the active world runs the sync stack. Guest/demo worlds do not:
/// sync UI surfaces (settings section, outbox pages, verification listener,
/// activity indicator) must gate on this instead of resolving MatrixService,
/// which is not registered in guest mode.
///
/// Falls back to `true` when no profile context is overridden so the
/// long tail of existing widget tests — which pump sync surfaces with a
/// mocked MatrixService and no profile plumbing — keeps the real-profile
/// behavior. Production always has the override.
final syncFeatureAvailableProvider = Provider<bool>((ref) {
  try {
    return ref.watch(profileContextProvider).capabilities.syncEnabled;
  } catch (_) {
    return true;
  }
});

/// Whether the active world is a guest/demo world. Drives the persistent
/// demo banner and demo-only affordances. Falls back to `false` (real
/// world) when no profile context is overridden, mirroring
/// [syncFeatureAvailableProvider].
final demoModeActiveProvider = Provider<bool>((ref) {
  try {
    return ref.watch(profileContextProvider).isGuest;
  } catch (_) {
    return false;
  }
});
