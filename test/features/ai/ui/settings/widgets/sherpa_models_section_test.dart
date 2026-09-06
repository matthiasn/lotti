import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:lotti/features/ai/ui/settings/widgets/sherpa_models_section.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  late MockSherpaModelRepository models;
  late MockAiConfigRepository configs;
  late MockSyncNodeProfileBroadcaster broadcaster;
  setUpAll(registerAllFallbackValues);
  setUp(() async {
    await setUpTestGetIt();
    broadcaster = MockSyncNodeProfileBroadcaster();
    when(() => broadcaster.broadcastIfChanged()).thenAnswer((_) async => true);
    getIt.registerSingleton<SyncNodeProfileBroadcaster>(broadcaster);
    models = MockSherpaModelRepository();
    configs = MockAiConfigRepository();
    when(() => models.isInstalled(any())).thenAnswer((_) async => false);
    when(
      () => configs.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => []);
    when(() => configs.saveConfig(any())).thenAnswer((_) async {});
  });
  tearDown(tearDownTestGetIt);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const SherpaModelsSection(providerId: 'sherpa-provider'),
        overrides: [
          sherpaModelRepositoryProvider.overrideWithValue(models),
          aiConfigRepositoryProvider.overrideWithValue(configs),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'downloads only on request and creates a usable model row on success',
    (tester) async {
      final finished = Completer<String>();
      when(
        () => models.install('tiny', onProgress: any(named: 'onProgress')),
      ).thenAnswer((invocation) {
        (invocation.namedArguments[#onProgress] as void Function(double))(0.5);
        return finished.future;
      });
      await pump(tester);
      verifyNever(
        () => models.install(any(), onProgress: any(named: 'onProgress')),
      );
      await tester.tap(find.text('Download (104 MB)'));
      await tester.pump();
      verifyNever(() => configs.saveConfig(any()));
      finished.complete('/model');
      await tester.pumpAndSettle();
      final saved =
          verify(() => configs.saveConfig(captureAny())).captured.single
              as AiConfigModel;
      verify(() => broadcaster.broadcastIfChanged()).called(1);
      expect(saved.inferenceProviderId, 'sherpa-provider');
      expect(saved.providerModelId, 'tiny');
      expect(saved.inputModalities, [Modality.audio]);
      expect(find.text('Downloaded'), findsOneWidget);
      expect(find.text('Model operation failed. Try again.'), findsNothing);
    },
  );

  testWidgets(
    'failed downloads show an error and remain retryable without saving configuration',
    (tester) async {
      when(
        () => models.install('tiny', onProgress: any(named: 'onProgress')),
      ).thenThrow(StateError('failed'));
      await pump(tester);
      await tester.tap(find.text('Download (104 MB)'));
      await tester.pumpAndSettle();
      expect(find.text('Model operation failed. Try again.'), findsOneWidget);
      expect(find.text('Download (104 MB)'), findsOneWidget);
      verifyNever(() => configs.saveConfig(any()));
    },
  );

  testWidgets(
    'removal deletes device files without deleting synced model configuration',
    (tester) async {
      when(() => models.isInstalled('tiny')).thenAnswer((_) async => true);
      when(() => models.remove('tiny')).thenAnswer((_) async {});
      await pump(tester);
      await tester.tap(find.text('Delete downloaded model'));
      await tester.pumpAndSettle();
      verify(() => models.remove('tiny')).called(1);
      verify(() => broadcaster.broadcastIfChanged()).called(1);
      verifyNever(() => configs.saveConfig(any()));
      expect(find.text('Download (104 MB)'), findsOneWidget);
      expect(find.text('Downloaded'), findsNothing);
      expect(find.text('Model operation failed. Try again.'), findsNothing);
    },
  );
  testWidgets(
    'a failed removal keeps the downloaded model available for retry',
    (tester) async {
      when(() => models.isInstalled('tiny')).thenAnswer((_) async => true);
      when(() => models.remove('tiny')).thenThrow(StateError('busy'));
      await pump(tester);
      await tester.tap(find.text('Delete downloaded model'));
      await tester.pumpAndSettle();
      expect(find.text('Downloaded'), findsOneWidget);
      expect(find.text('Model operation failed. Try again.'), findsOneWidget);
      expect(find.text('Delete downloaded model'), findsOneWidget);
      verifyNever(() => configs.saveConfig(any()));
    },
  );

  for (final failRead in [true, false]) {
    testWidgets(
      'configuration failure keeps installed files visible ($failRead)',
      (
        tester,
      ) async {
        when(
          () => models.install('tiny', onProgress: any(named: 'onProgress')),
        ).thenAnswer((_) async => '/model');
        if (failRead) {
          when(
            () => configs.getConfigsByType(AiConfigType.model),
          ).thenThrow(StateError('configuration read failed'));
        } else {
          when(
            () => configs.saveConfig(any()),
          ).thenThrow(StateError('configuration save failed'));
        }
        when(() => models.remove('tiny')).thenAnswer((_) async {});
        await pump(tester);
        await tester.tap(find.text('Download (104 MB)'));
        await tester.pumpAndSettle();
        expect(find.text('Downloaded'), findsOneWidget);
        expect(find.text('Download (104 MB)'), findsNothing);
        expect(find.text('Model operation failed. Try again.'), findsNothing);
        expect(
          find.text(
            'Model downloaded, but its configuration could not be saved.',
          ),
          findsOneWidget,
        );
        verify(() => broadcaster.broadcastIfChanged()).called(1);
        await tester.tap(find.text('Delete downloaded model'));
        await tester.pumpAndSettle();
        verify(() => models.remove('tiny')).called(1);
        expect(find.text('Download (104 MB)'), findsOneWidget);
        expect(
          find.text(
            'Model downloaded, but its configuration could not be saved.',
          ),
          findsNothing,
        );
      },
    );
  }

  testWidgets('redownload preserves existing model identity and user edits', (
    tester,
  ) async {
    when(
      () => models.install('tiny', onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) async => '/model');
    final existing = AiConfig.model(
      id: 'synced-custom-id',
      name: 'My Whisper',
      providerModelId: 'tiny',
      inferenceProviderId: 'sherpa-provider',
      createdAt: DateTime.utc(2026),
      inputModalities: [Modality.audio],
      outputModalities: [Modality.text],
      isReasoningModel: false,
    );
    when(
      () => configs.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => [existing]);
    await pump(tester);
    await tester.tap(find.text('Download (104 MB)'));
    await tester.pumpAndSettle();
    verifyNever(() => configs.saveConfig(any()));
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Download (104 MB)'), findsNothing);
  });
  testWidgets('a sync failure does not undo a successful model download', (
    tester,
  ) async {
    when(
      () => broadcaster.broadcastIfChanged(),
    ).thenThrow(StateError('sync unavailable'));
    when(
      () => models.install('tiny', onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) async => '/model');
    await pump(tester);
    await tester.tap(find.text('Download (104 MB)'));
    await tester.pumpAndSettle();
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Model operation failed. Try again.'), findsNothing);
    verify(() => configs.saveConfig(any())).called(1);
  });
}
