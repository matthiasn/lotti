import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Local host id provider — wraps `VectorClockService.getHost()` so the
/// pinning UI rebuilds when host id changes (e.g. after `setNewHost()`).
///
/// Pulled out as a top-level provider so widget tests can override it without
/// registering a full `VectorClockService` in get_it.
final localVectorClockHostIdProvider = FutureProvider<String?>(
  (ref) async {
    if (!getIt.isRegistered<VectorClockService>()) return null;
    return getIt<VectorClockService>().getHost();
  },
);

/// Dropdown that lets the user pin an inference profile to a specific sync
/// node so the synced-audio auto-trigger fires only on that device.
///
/// Surface contract:
/// - Renders a "Not pinned" option (value `null`) and a row per eligible
///   peer profile. The local node is included with a "(this device)" suffix
///   so the user can self-pin from any device.
/// - Eligibility filter: a node is shown only when its advertised
///   [SyncNodeProfile.capabilities] cover every provider type the profile
///   references (translated via [nodeCapabilityFromProviderType]). Cloud
///   provider types are exempted — they don't have node-capability tokens
///   and don't need a device claim, so a profile that includes a cloud
///   slot can still pin to whichever local-runtime device the user wants.
/// - Empty eligible set → "No eligible devices" hint. The user pins
///   nothing; the dispatcher will skip every entry until the user opens
///   sync-node settings on the intended device.
///
/// Stateless — the parent form owns the pinned value and persists it on
/// save. `setState` flows back through [onChanged].
class ProfilePinningSelector extends ConsumerWidget {
  const ProfilePinningSelector({
    required this.pinnedHostId,
    required this.referencedModelIds,
    required this.onChanged,
    super.key,
  });

  /// Current pinned host id (the value being edited).
  final String? pinnedHostId;

  /// Raw provider-model id strings referenced by every populated slot on the
  /// profile being edited. The selector resolves these to
  /// [InferenceProviderType]s internally and uses the resulting set to
  /// filter the dropdown to capable devices.
  final Set<String> referencedModelIds;

  /// Fired whenever the user picks a different host (or "Not pinned").
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final theme = Theme.of(context);
    final directoryAsync = ref.watch(knownSyncNodesProvider);
    final localHostAsync = ref.watch(localVectorClockHostIdProvider);
    final modelsAsync = ref.watch(
      aiConfigByTypeControllerProvider(configType: AiConfigType.model),
    );
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ),
    );

    final nodes = directoryAsync.maybeWhen<List<SyncNodeProfile>>(
      data: (value) => value,
      orElse: () => const <SyncNodeProfile>[],
    );
    final localHostId = localHostAsync.maybeWhen<String?>(
      data: (value) => value,
      orElse: () => null,
    );
    final referencedProviderTypes = _resolveReferencedProviderTypes(
      modelsAsync,
      providersAsync,
    );
    final eligible = _filterEligible(nodes, referencedProviderTypes).toList();

    // If the currently-pinned host is no longer in the eligible set (e.g.
    // the user removed a capability or the node profile was edited away),
    // keep it as a stale option so the user can see what's wrong instead
    // of having it silently snap to "Not pinned" on first paint.
    SyncNodeProfile? staleSelection;
    if (pinnedHostId != null &&
        !eligible.any((n) => n.hostId == pinnedHostId)) {
      staleSelection = nodes.firstWhere(
        (n) => n.hostId == pinnedHostId,
        orElse: () => SyncNodeProfile(
          hostId: pinnedHostId!,
          displayName: pinnedHostId!,
          platform: 'unknown',
          capabilities: const [],
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          // `initialValue: pinnedHostId` accepts null as a valid value when
          // the "Not pinned" item below also has value: null.
          initialValue: pinnedHostId,
          decoration: InputDecoration(
            labelText: messages.inferenceProfilePinnedHostLabel,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          items: [
            DropdownMenuItem<String?>(
              // ignore: avoid_redundant_argument_values
              value: null,
              child: Text(messages.inferenceProfilePinnedHostNoneLabel),
            ),
            for (final node in eligible)
              DropdownMenuItem<String?>(
                value: node.hostId,
                child: Text(_labelFor(node, localHostId, messages)),
              ),
            if (staleSelection != null)
              DropdownMenuItem<String?>(
                value: staleSelection.hostId,
                child: Text(_labelFor(staleSelection, localHostId, messages)),
              ),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Text(
          pinnedHostId == null
              ? messages.inferenceProfilePinnedHostNoneHelper
              : messages.inferenceProfilePinnedHostHelper,
          style: theme.textTheme.bodySmall,
        ),
        // Surface the no-eligible-devices hint when the selector can't offer
        // a meaningful pick yet. Wrapped in a Column rather than a spread so
        // the `pinnedHostId == null && eligible.isEmpty` predicate stays
        // boolean (the spread + null-aware form swallows the second clause).
        if (pinnedHostId == null && eligible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              messages.inferenceProfilePinnedHostNoEligibleNodes,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Iterable<SyncNodeProfile> _filterEligible(
    List<SyncNodeProfile> nodes,
    Set<InferenceProviderType> referencedProviderTypes,
  ) {
    final required = <NodeCapability>{
      for (final type in referencedProviderTypes)
        ?nodeCapabilityFromProviderType(type),
    };
    if (required.isEmpty) {
      // No local-runtime requirements — every node is eligible.
      return nodes;
    }
    return nodes.where(
      (n) => required.every(n.capabilities.contains),
    );
  }

  /// Walks the watched model + provider config lists to resolve every
  /// [referencedModelIds] entry to its provider type.
  ///
  /// Synchronous on the watched async snapshots — returns an empty set while
  /// the configs are still loading. The dispatcher's `profileIsLocal` is the
  /// load-bearing guard at trigger time, so an under-filtered dropdown during
  /// the brief loading window is acceptable.
  Set<InferenceProviderType> _resolveReferencedProviderTypes(
    AsyncValue<List<AiConfig>> modelsAsync,
    AsyncValue<List<AiConfig>> providersAsync,
  ) {
    final models = modelsAsync.maybeWhen<List<AiConfigModel>>(
      data: (value) => value.whereType<AiConfigModel>().toList(),
      orElse: () => const <AiConfigModel>[],
    );
    final providers = providersAsync.maybeWhen<List<AiConfigInferenceProvider>>(
      data: (value) => value.whereType<AiConfigInferenceProvider>().toList(),
      orElse: () => const <AiConfigInferenceProvider>[],
    );
    final providersById = {
      for (final provider in providers) provider.id: provider,
    };
    // Index models by both keys profile slots can carry — `providerModelId`
    // (the standard) and `id` (legacy / forward-compat). One pass over the
    // model list builds both maps; the loop below is then O(slots) instead
    // of O(slots × models).
    final modelsByProviderModelId = <String, AiConfigModel>{};
    final modelsById = <String, AiConfigModel>{};
    for (final model in models) {
      modelsByProviderModelId[model.providerModelId] = model;
      modelsById[model.id] = model;
    }
    final types = <InferenceProviderType>{};
    for (final id in referencedModelIds) {
      final model = modelsByProviderModelId[id] ?? modelsById[id];
      if (model == null) continue;
      final provider = providersById[model.inferenceProviderId];
      if (provider == null) continue;
      types.add(provider.inferenceProviderType);
    }
    return types;
  }

  String _labelFor(
    SyncNodeProfile node,
    String? localHostId,
    AppLocalizations messages,
  ) {
    if (localHostId != null && node.hostId == localHostId) {
      return '${node.displayName}'
          '${messages.inferenceProfilePinnedHostThisDeviceSuffix}';
    }
    return node.displayName;
  }
}
