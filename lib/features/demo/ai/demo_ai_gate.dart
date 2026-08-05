import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/get_it.dart';

/// The active world's seed manifest, loaded once per service generation.
///
/// `null` in the real world (no manifest is ever written there), in bare
/// tests without a registered root [Directory], and when the manifest is
/// missing or malformed — a corrupt manifest must degrade the fixture
/// detection, never crash an AI tap.
final demoSeedManifestProvider = FutureProvider<DemoSeedManifest?>((ref) async {
  if (!getIt.isRegistered<Directory>()) return null;
  try {
    return await DemoSeedManifest.read(getIt<Directory>());
  } catch (_) {
    return null;
  }
});

/// The active world's inference-provider configs, kept live so the gate
/// reacts the moment the user connects a real provider.
final _inferenceProviderConfigsProvider = StreamProvider<List<AiConfig>>((
  ref,
) {
  final repository = ref.watch(aiConfigRepositoryProvider);
  return repository.watchConfigsByType(AiConfigType.inferenceProvider);
});

/// Whether REAL AI is available in the active world: true when at least one
/// inference-provider config exists whose id is NOT listed in the seed
/// manifest's [DemoSeedManifest.seededAiConfigIds].
///
/// In the demo world the seeded fixtures are fictional endpoints that can
/// never answer, so "any non-seeded provider" is exactly "the user connected
/// something real". Without a manifest (real world, or a corrupt one) every
/// provider counts as real — the safe direction: the nudge must never block
/// a working setup, so a broken manifest degrades to "don't nudge".
final demoRealAiAvailableProvider = FutureProvider<bool>((ref) async {
  final manifest = await ref.watch(demoSeedManifestProvider.future);
  final seeded = {...?manifest?.seededAiConfigIds};
  // Subscribed after the manifest await; safe because the repository's
  // watch stream replays the current config snapshot to every subscriber.
  final providers = await ref.watch(_inferenceProviderConfigsProvider.future);
  return providers.any((config) => !seeded.contains(config.id));
});

/// Whether an AI trigger should be intercepted with the real-AI setup nudge:
/// the demo world is active AND no real (non-fixture) inference provider is
/// configured in it. Short-circuits outside the demo without touching the
/// manifest or the AI config database.
Future<bool> shouldNudgeForRealAi(ProviderContainer container) async {
  if (!container.read(demoModeActiveProvider)) return false;
  return !await container.read(demoRealAiAvailableProvider.future);
}
