// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/widgets/profile_pinning_selector.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';

import '../../../../widget_test_utils.dart';

final _kCreatedAt = DateTime.utc(2026, 3, 15, 12);

AiConfigModel _model({
  required String providerModelId,
  required String inferenceProviderId,
  String? id,
}) {
  return AiConfig.model(
        id: id ?? providerModelId,
        name: providerModelId,
        providerModelId: providerModelId,
        inferenceProviderId: inferenceProviderId,
        createdAt: _kCreatedAt,
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      )
      as AiConfigModel;
}

AiConfigInferenceProvider _provider({
  required String id,
  required InferenceProviderType type,
}) {
  return AiConfig.inferenceProvider(
        id: id,
        baseUrl: '',
        apiKey: '',
        name: type.name,
        inferenceProviderType: type,
        createdAt: _kCreatedAt,
      )
      as AiConfigInferenceProvider;
}

SyncNodeProfile _node({
  required String hostId,
  required String displayName,
  List<NodeCapability> capabilities = const [NodeCapability.mlxAudio],
}) {
  return SyncNodeProfile(
    hostId: hostId,
    displayName: displayName,
    platform: 'macos',
    capabilities: capabilities,
    updatedAt: _kCreatedAt,
  );
}

class _FakeAiConfigByTypeController extends AiConfigByTypeController {
  _FakeAiConfigByTypeController(this.items);
  final List<AiConfig> items;

  @override
  Stream<List<AiConfig>> build({required AiConfigType configType}) {
    return Stream.value(items);
  }
}

Widget _harness({
  required String? pinnedHostId,
  required Set<String> referencedModelIds,
  required void Function(String?) onChanged,
  required List<SyncNodeProfile> knownNodes,
  required List<AiConfig> models,
  required List<AiConfig> providers,
  String? localHostId,
}) {
  return makeTestableWidgetNoScroll(
    Material(
      child: ProfilePinningSelector(
        pinnedHostId: pinnedHostId,
        referencedModelIds: referencedModelIds,
        onChanged: onChanged,
      ),
    ),
    overrides: [
      knownSyncNodesProvider.overrideWith((_) => Stream.value(knownNodes)),
      localVectorClockHostIdProvider.overrideWith((_) async => localHostId),
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.model,
      ).overrideWith(() => _FakeAiConfigByTypeController(models)),
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ).overrideWith(() => _FakeAiConfigByTypeController(providers)),
    ],
  );
}

void main() {
  testWidgets(
    'renders Not-pinned option and emits null when chosen',
    (tester) async {
      String? capturedHostId = 'sentinel';
      await tester.pumpWidget(
        _harness(
          pinnedHostId: 'h1',
          referencedModelIds: const {},
          onChanged: (v) => capturedHostId = v,
          knownNodes: [_node(hostId: 'h1', displayName: 'Studio Mac')],
          models: const [],
          providers: const [],
        ),
      );
      await tester.pumpAndSettle();

      // Open the dropdown.
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      // Tap "Not pinned".
      await tester.tap(
        find.text('Not pinned (no auto-trigger)').last,
      );
      await tester.pumpAndSettle();

      expect(capturedHostId, isNull);
    },
  );

  testWidgets(
    'filters the dropdown to nodes whose capabilities cover every '
    'referenced local provider type',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          pinnedHostId: null,
          // The profile references a model whose provider is Ollama.
          referencedModelIds: const {'qwen3'},
          onChanged: (_) {},
          knownNodes: [
            _node(
              hostId: 'host-mlx-only',
              displayName: 'Mac with MLX only',
              capabilities: const [NodeCapability.mlxAudio],
            ),
            _node(
              hostId: 'host-mlx-ollama',
              displayName: 'Mac with MLX + Ollama',
              capabilities: const [
                NodeCapability.mlxAudio,
                NodeCapability.ollamaLlm,
              ],
            ),
          ],
          models: [
            _model(providerModelId: 'qwen3', inferenceProviderId: 'p1'),
          ],
          providers: [
            _provider(id: 'p1', type: InferenceProviderType.ollama),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      // The non-eligible node must NOT appear in the menu.
      expect(find.text('Mac with MLX only'), findsNothing);
      // The eligible node must appear.
      expect(find.text('Mac with MLX + Ollama'), findsOneWidget);
    },
  );

  testWidgets(
    'shows every node when the profile references no local-runtime '
    'providers (cloud-only or empty)',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          pinnedHostId: null,
          // Referenced model resolves to a cloud provider (Gemini) — no
          // local-runtime requirement → no filter.
          referencedModelIds: const {'gemini-flash'},
          onChanged: (_) {},
          knownNodes: [
            _node(
              hostId: 'h-bare',
              displayName: 'Bare Mac',
              capabilities: const [],
            ),
          ],
          models: [
            _model(
              providerModelId: 'gemini-flash',
              inferenceProviderId: 'p-gemini',
            ),
          ],
          providers: [
            _provider(id: 'p-gemini', type: InferenceProviderType.gemini),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      // The node is still eligible because the profile imposes no
      // local-runtime requirement.
      expect(find.text('Bare Mac'), findsOneWidget);
    },
  );

  testWidgets(
    'appends "(this device)" suffix when the node matches localHostId',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          pinnedHostId: null,
          referencedModelIds: const {},
          onChanged: (_) {},
          knownNodes: [
            _node(hostId: 'self-host', displayName: 'Studio Mac'),
            _node(hostId: 'other-host', displayName: 'Other Mac'),
          ],
          models: const [],
          providers: const [],
          localHostId: 'self-host',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      expect(find.text('Studio Mac (this device)'), findsOneWidget);
      expect(find.text('Other Mac'), findsOneWidget);
    },
  );

  testWidgets(
    'preserves a stale pin (host no longer in directory) as a dropdown '
    'option so the user can see what is wrong',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          pinnedHostId: 'deleted-host',
          referencedModelIds: const {},
          onChanged: (_) {},
          knownNodes: [
            _node(hostId: 'live-host', displayName: 'Live Mac'),
          ],
          models: const [],
          providers: const [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      // The stale host id appears as its own option (displayName falls
      // back to the host id since the directory has no entry).
      expect(find.text('deleted-host'), findsAtLeast(1));
    },
  );

  testWidgets(
    'shows the no-eligible-nodes hint when nothing is pinned and the '
    'directory is empty',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          pinnedHostId: null,
          referencedModelIds: const {},
          onChanged: (_) {},
          knownNodes: const [],
          models: const [],
          providers: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No known devices advertise'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'helper text switches based on whether a pin is set',
    (tester) async {
      // Not pinned → "Synced audio entries are not auto-transcribed…"
      await tester.pumpWidget(
        _harness(
          pinnedHostId: null,
          referencedModelIds: const {},
          onChanged: (_) {},
          knownNodes: [_node(hostId: 'h1', displayName: 'Studio Mac')],
          models: const [],
          providers: const [],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('not auto-transcribed when no device is pinned'),
        findsOneWidget,
      );

      // Pinned → "When set, only this device auto-runs…"
      await tester.pumpWidget(
        _harness(
          pinnedHostId: 'h1',
          referencedModelIds: const {},
          onChanged: (_) {},
          knownNodes: [_node(hostId: 'h1', displayName: 'Studio Mac')],
          models: const [],
          providers: const [],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('only this device auto-runs inference'),
        findsOneWidget,
      );
    },
  );

  group('pure helper properties', () {
    // Local-runtime provider types (mapped to node capabilities) plus a few
    // cloud-only ones (mapped to null → never required).
    const localTypes = [
      InferenceProviderType.mlxAudio,
      InferenceProviderType.ollama,
      InferenceProviderType.voxtral,
      InferenceProviderType.whisper,
    ];
    const cloudTypes = [
      InferenceProviderType.anthropic,
      InferenceProviderType.gemini,
      InferenceProviderType.openAi,
    ];

    SyncNodeProfile node(int seed) {
      final capabilities = <NodeCapability>[
        for (final c in NodeCapability.values)
          if ((seed >> c.index) & 1 == 1) c,
      ];
      return SyncNodeProfile(
        hostId: 'host-$seed',
        displayName: 'Node $seed',
        platform: 'linux',
        capabilities: capabilities,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }

    glados.Glados2<List<int>, int>(
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        8,
        glados.IntAnys(glados.any).intInRange(0, 16),
      ),
      glados.IntAnys(glados.any).intInRange(0, 1 << 7),
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'filterEligible keeps exactly the capability-superset nodes',
      (nodeSeeds, typeMask) {
        final nodes = [for (final s in nodeSeeds) node(s)];
        final types = <InferenceProviderType>{
          for (var i = 0; i < localTypes.length; i++)
            if ((typeMask >> i) & 1 == 1) localTypes[i],
          for (var i = 0; i < cloudTypes.length; i++)
            if ((typeMask >> (4 + i)) & 1 == 1) cloudTypes[i],
        };

        final eligible = ProfilePinningSelector.filterEligible(
          nodes,
          types,
        ).toList();

        final requiredCapabilities = <NodeCapability>{
          for (final t in types)
            if (nodeCapabilityFromProviderType(t) != null)
              nodeCapabilityFromProviderType(t)!,
        };

        if (requiredCapabilities.isEmpty) {
          // Cloud-only (or no) requirements: every node is eligible.
          expect(eligible, nodes);
          return;
        }
        for (final n in nodes) {
          final shouldPass = requiredCapabilities.every(
            n.capabilities.contains,
          );
          expect(
            eligible.contains(n),
            shouldPass,
            reason:
                'node ${n.hostId} caps=${n.capabilities} '
                'required=$requiredCapabilities',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.IntAnys(glados.any).intInRange(0, 1 << 12),
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'resolveReferencedProviderTypes maps resolvable ids to provider types',
      (seed) {
        // Three providers cycling through provider types; three models, one
        // per provider; reference a seed-driven subset by providerModelId,
        // by id (legacy), plus one unknown id that must resolve to nothing.
        final providerTypes = [
          localTypes[seed % localTypes.length],
          cloudTypes[seed % cloudTypes.length],
          localTypes[(seed >> 2) % localTypes.length],
        ];
        final providers = [
          for (final (i, t) in providerTypes.indexed)
            AiConfig.inferenceProvider(
              id: 'provider-$i',
              name: 'Provider $i',
              baseUrl: 'https://example.com',
              apiKey: 'k',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              inferenceProviderType: t,
            ),
        ];
        final models = [
          for (var i = 0; i < 3; i++)
            AiConfig.model(
              id: 'model-$i',
              name: 'Model $i',
              providerModelId: 'pm-$i',
              inferenceProviderId: 'provider-$i',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
            ),
        ];

        final referenced = <String>{
          if (seed & 1 == 1) 'pm-0', // by providerModelId
          if (seed & 2 == 2) 'model-1', // by id (legacy)
          if (seed & 4 == 4) 'pm-2',
          'unknown-id', // never resolves
        };

        final resolved = ProfilePinningSelector.resolveReferencedProviderTypes(
          AsyncData(models),
          AsyncData(providers),
          referencedModelIds: referenced,
        );

        final expected = <InferenceProviderType>{
          if (seed & 1 == 1) providerTypes[0],
          if (seed & 2 == 2) providerTypes[1],
          if (seed & 4 == 4) providerTypes[2],
        };
        expect(resolved, expected, reason: 'seed=$seed refs=$referenced');

        // While configs are loading, resolution yields nothing.
        expect(
          ProfilePinningSelector.resolveReferencedProviderTypes(
            const AsyncLoading(),
            const AsyncLoading(),
            referencedModelIds: referenced,
          ),
          isEmpty,
        );
      },
      tags: 'glados',
    );
  });
}
