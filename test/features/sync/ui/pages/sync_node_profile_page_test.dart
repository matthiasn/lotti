import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:lotti/features/sync/ui/pages/sync_node_profile_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

final _kUpdatedAt = DateTime.utc(2026, 3, 15, 12);

SyncNodeProfile _self({
  String displayName = 'Studio Mac',
  List<NodeCapability> capabilities = const [
    NodeCapability.mlxAudio,
    NodeCapability.ollamaLlm,
  ],
}) {
  return SyncNodeProfile(
    hostId: 'self-host',
    displayName: displayName,
    platform: 'macos',
    capabilities: capabilities,
    updatedAt: _kUpdatedAt,
  );
}

SyncNodeProfile _peer({
  required String hostId,
  required String displayName,
  List<NodeCapability> capabilities = const [],
}) {
  return SyncNodeProfile(
    hostId: hostId,
    displayName: displayName,
    platform: 'linux',
    capabilities: capabilities,
    updatedAt: _kUpdatedAt,
  );
}

void main() {
  late MockSyncNodeProfileBroadcaster broadcaster;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    broadcaster = MockSyncNodeProfileBroadcaster();
    when(
      () => broadcaster.broadcastIfChanged(
        displayNameOverride: any(named: 'displayNameOverride'),
        appVersion: any(named: 'appVersion'),
      ),
    ).thenAnswer((_) async => true);

    if (GetIt.I.isRegistered<SyncNodeProfileBroadcaster>()) {
      GetIt.I.unregister<SyncNodeProfileBroadcaster>();
    }
    GetIt.I.registerSingleton<SyncNodeProfileBroadcaster>(broadcaster);
  });

  tearDown(() {
    if (GetIt.I.isRegistered<SyncNodeProfileBroadcaster>()) {
      GetIt.I.unregister<SyncNodeProfileBroadcaster>();
    }
  });

  Widget harness({
    SyncNodeProfile? self,
    List<SyncNodeProfile> directory = const [],
  }) {
    return makeTestableWidgetNoScroll(
      const SyncNodeProfilePage(),
      overrides: [
        localSyncNodeSelfProvider.overrideWith((_) => Stream.value(self)),
        knownSyncNodesProvider.overrideWith((_) => Stream.value(directory)),
      ],
    );
  }

  testWidgets(
    'seeds the display-name field from the local self profile',
    (tester) async {
      await tester.pumpWidget(
        harness(self: _self(), directory: [_self()]),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, 'Studio Mac');
    },
  );

  testWidgets(
    'renders detected capabilities as chips',
    (tester) async {
      await tester.pumpWidget(
        harness(self: _self(), directory: [_self()]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsNWidgets(2));
      expect(find.text('MLX Audio (local)'), findsOneWidget);
      expect(find.text('Ollama LLM'), findsOneWidget);
    },
  );

  testWidgets(
    'shows capabilities-empty hint when no capabilities are detected',
    (tester) async {
      await tester.pumpWidget(
        harness(
          self: _self(capabilities: const []),
          directory: [_self(capabilities: const [])],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsNothing);
      expect(
        find.textContaining('auto-trigger of synced audio inference will not'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'lists known peer nodes excluding the local self profile',
    (tester) async {
      await tester.pumpWidget(
        harness(
          self: _self(),
          directory: [
            _self(),
            _peer(
              hostId: 'peer-1',
              displayName: 'Other Mac',
              capabilities: const [NodeCapability.ollamaLlm],
            ),
            _peer(
              hostId: 'peer-2',
              displayName: 'Linux Box',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Other Mac'), findsOneWidget);
      expect(find.text('Linux Box'), findsOneWidget);
      // Self is excluded from the "known nodes" section because it already
      // appears at the top of the page.
      expect(find.text('Studio Mac'), findsOneWidget); // only in the field
    },
  );

  testWidgets(
    'Save tap forwards trimmed display name to broadcastIfChanged',
    (tester) async {
      await tester.pumpWidget(
        harness(self: _self(), directory: [_self()]),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '  New Name  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verify(
        () => broadcaster.broadcastIfChanged(
          displayNameOverride: 'New Name',
          appVersion: any(named: 'appVersion'),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'shows empty-known-nodes hint when only the self profile is in the '
    'directory',
    (tester) async {
      await tester.pumpWidget(
        harness(self: _self(), directory: [_self()]),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No other devices have published a profile'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Save with an empty display-name field surfaces the validator and '
    'does NOT invoke the broadcaster',
    (tester) async {
      await tester.pumpWidget(
        harness(self: _self(), directory: [_self()]),
      );
      await tester.pumpAndSettle();

      // Clear the seeded display name; this should fail validation on save.
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verifyNever(
        () => broadcaster.broadcastIfChanged(
          displayNameOverride: any(named: 'displayNameOverride'),
          appVersion: any(named: 'appVersion'),
        ),
      );
    },
  );

  testWidgets(
    'renders the full capability palette including voxtral and whisper',
    (tester) async {
      await tester.pumpWidget(
        harness(
          self: _self(
            capabilities: const [
              NodeCapability.mlxAudio,
              NodeCapability.ollamaLlm,
              NodeCapability.voxtral,
              NodeCapability.whisper,
            ],
          ),
          directory: [
            _self(
              capabilities: const [
                NodeCapability.mlxAudio,
                NodeCapability.ollamaLlm,
                NodeCapability.voxtral,
                NodeCapability.whisper,
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsNWidgets(4));
      expect(find.text('MLX Audio (local)'), findsOneWidget);
      expect(find.text('Ollama LLM'), findsOneWidget);
      expect(find.text('Voxtral (local)'), findsOneWidget);
      expect(find.text('Whisper (local)'), findsOneWidget);
    },
  );
}
