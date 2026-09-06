import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/speech/sherpa_installed_models_provider.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_search_bar.dart';
import 'package:lotti/features/ai/ui/settings/widgets/sherpa_models_section.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../test_utils/screenshot_harness.dart' show loadAppFonts;
import '../../../../../widget_test_utils.dart';

void main() {
  late MockSherpaModelRepository models;
  late MockAiConfigRepository configs;
  late MockSyncNodeProfileBroadcaster broadcaster;
  setUpAll(() async {
    registerAllFallbackValues();
    await loadAppFonts();
  });
  setUp(() async {
    await setUpTestGetIt();
    broadcaster = MockSyncNodeProfileBroadcaster();
    when(() => broadcaster.broadcastIfChanged()).thenAnswer((_) async => true);
    getIt.registerSingleton<SyncNodeProfileBroadcaster>(broadcaster);
    models = MockSherpaModelRepository();
    configs = MockAiConfigRepository();
    when(() => models.models).thenReturn(sherpaModels);
    when(() => models.isAvailable(any())).thenAnswer(
      (call) => models.isInstalled(call.positionalArguments.single as String),
    );
    when(() => models.isInstalled(any())).thenAnswer((_) async => false);
    when(
      () => configs.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => []);
    when(() => configs.saveConfig(any())).thenAnswer((_) async {});
  });
  tearDown(tearDownTestGetIt);

  Finder downloadFor(String id) => find.descendant(
    of: find.byKey(ValueKey('sherpa-model-$id')),
    matching: find.widgetWithText(DesignSystemButton, 'Download'),
  );

  Future<void> pump(
    WidgetTester tester, {
    double textScale = 1,
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const Material(
            child: SherpaModelsSection(providerId: 'sherpa-provider'),
          ),
        ),
        locale: locale,
        overrides: [
          sherpaModelRepositoryProvider.overrideWithValue(models),
          aiConfigRepositoryProvider.overrideWithValue(configs),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('searches catalog and clears a query with no matches', (
    tester,
  ) async {
    await pump(tester);
    final search = find.byType(AiSettingsSearchBar);
    await tester.enterText(
      find.descendant(of: search, matching: find.byType(TextField)),
      '  MEDIUM  ',
    );
    await tester.pump();
    expect(downloadFor('medium'), findsOneWidget);
    expect(downloadFor('tiny'), findsNothing);
    await tester.enterText(
      find.descendant(of: search, matching: find.byType(TextField)),
      'unmatched-model',
    );
    await tester.pump();
    expect(downloadFor('medium'), findsNothing);
    expect(find.text('No matches'), findsOneWidget);
    tester.widget<AiSettingsSearchBar>(search).onClear!();
    await tester.pump();
    expect(downloadFor('tiny'), findsOneWidget);
  });

  testWidgets(
    'family filter and search narrow the multilingual catalog together',
    (tester) async {
      await pump(tester);
      final dropdown = find.byKey(const ValueKey('sherpa-model-family'));
      await tester.ensureVisible(dropdown);
      await tester.tap(find.text('All families'));
      await tester.pump();
      final option = find.text('Paraformer');
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
      expect(downloadFor('paraformer-bilingual'), findsOneWidget);
      expect(downloadFor('paraformer-trilingual'), findsOneWidget);
      expect(downloadFor('medium'), findsNothing);
      final search = find.byType(AiSettingsSearchBar);
      await tester.ensureVisible(search);
      await tester.enterText(
        find.descendant(of: search, matching: find.byType(TextField)),
        'Cantonese',
      );
      await tester.pump();
      expect(downloadFor('paraformer-bilingual'), findsNothing);
      expect(downloadFor('paraformer-trilingual'), findsOneWidget);
      tester.widget<AiSettingsSearchBar>(search).onClear!();
      await tester.pump();
      expect(downloadFor('paraformer-bilingual'), findsOneWidget);
      tester.widget<DesignSystemDropdown>(dropdown).onItemPressed!(
        const DesignSystemDropdownItem(id: '', label: 'All families'),
      );
      await tester.pump();
      expect(downloadFor('medium'), findsOneWidget);
    },
  );

  testWidgets(
    'adds already installed files to a new provider without downloading',
    (tester) async {
      when(() => models.isInstalled('tiny')).thenAnswer((_) async => true);
      await pump(tester);
      final row = find.byKey(const ValueKey('sherpa-model-tiny'));
      final add = find.descendant(
        of: row,
        matching: find.widgetWithText(DesignSystemButton, 'Add model'),
      );
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      final saved =
          verify(() => configs.saveConfig(captureAny())).captured.single
              as AiConfigModel;
      expect(saved.providerModelId, 'tiny');
      expect(saved.inferenceProviderId, 'sherpa-provider');
      verifyNever(
        () => models.install(any(), onProgress: any(named: 'onProgress')),
      );
      expect(add, findsNothing);
    },
  );

  testWidgets('keeps an active download alive across catalog searches', (
    tester,
  ) async {
    final finished = Completer<String>();
    late void Function(double) progress;
    when(
      () => models.install('tiny', onProgress: any(named: 'onProgress')),
    ).thenAnswer((call) {
      progress = call.namedArguments[#onProgress] as void Function(double);
      return finished.future;
    });
    await pump(tester);
    await tester.ensureVisible(downloadFor('tiny'));
    await tester.tap(downloadFor('tiny'));
    await tester.pump();
    final search = find.byType(AiSettingsSearchBar);
    await tester.ensureVisible(search);
    await tester.enterText(
      find.descendant(of: search, matching: find.byType(TextField)),
      'medium',
    );
    progress(0.6);
    await tester.pump();
    expect(find.text('60%'), findsOneWidget);
    expect(downloadFor('base'), findsNothing);
    finished.complete('/model');
    await tester.pumpAndSettle();
    tester.widget<AiSettingsSearchBar>(search).onClear!();
    await tester.pump();
    final row = find.byKey(const ValueKey('sherpa-model-tiny'));
    expect(
      find.descendant(of: row, matching: find.text('Downloaded')),
      findsOneWidget,
    );
    expect(downloadFor('tiny'), findsNothing);
    verify(
      () => models.install('tiny', onProgress: any(named: 'onProgress')),
    ).called(1);
    final saved =
        verify(() => configs.saveConfig(captureAny())).captured.single
            as AiConfigModel;
    expect(saved.providerModelId, 'tiny');
  });

  testWidgets('refreshes installed state after changes from another surface', (
    tester,
  ) async {
    var installed = false;
    when(() => models.isInstalled('tiny')).thenAnswer((_) async => installed);
    await pump(tester);
    await tester.pumpAndSettle();
    expect(downloadFor('tiny'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SherpaModelsSection)),
    );
    installed = true;
    container.invalidate(sherpaInstalledModelIdsProvider);
    await tester.pumpAndSettle();
    expect(downloadFor('tiny'), findsNothing);
    final row = find.byKey(const ValueKey('sherpa-model-tiny'));
    expect(
      find.descendant(of: row, matching: find.text('Downloaded')),
      findsOneWidget,
    );
    installed = false;
    container.invalidate(sherpaInstalledModelIdsProvider);
    await tester.pumpAndSettle();
    expect(downloadFor('tiny'), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('Downloaded')),
      findsNothing,
    );
  });

  for (final (id, name) in [
    ('large-v3', 'Whisper Large v3'),
    ('small', 'Whisper Small'),
    ('medium', 'Whisper Medium'),
    ('turbo', 'Whisper Large v3 Turbo'),
  ]) {
    testWidgets(
      'downloads $name and saves a selectable speech model',
      (
        tester,
      ) async {
        when(
          () => models.install(id, onProgress: any(named: 'onProgress')),
        ).thenAnswer((_) async => '/large-model');
        await pump(tester);
        final download = downloadFor(id);
        await tester.ensureVisible(download);
        await tester.tap(download);
        await tester.pumpAndSettle();
        final saved =
            verify(() => configs.saveConfig(captureAny())).captured.single
                as AiConfigModel;
        expect(saved.providerModelId, id);
        expect(saved.name, name);
        expect(saved.inferenceProviderId, 'sherpa-provider');
        expect(saved.inputModalities, [Modality.audio]);
        expect(saved.outputModalities, [Modality.text]);
        expect(find.text('Downloaded'), findsOneWidget);
        expect(download, findsNothing);
      },
    );
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
      await tester.ensureVisible(downloadFor('tiny'));
      await tester.tap(downloadFor('tiny'));
      await tester.pump();
      verifyNever(() => configs.saveConfig(any()));
      expect(find.text('50%'), findsOneWidget);
      expect(
        tester
            .widget<DesignSystemProgressBar>(
              find.byType(DesignSystemProgressBar),
            )
            .value,
        0.5,
      );
      expect(downloadFor('tiny'), findsNothing);
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
      await tester.ensureVisible(downloadFor('tiny'));
      await tester.tap(downloadFor('tiny'));
      await tester.pumpAndSettle();
      expect(find.text('Model operation failed. Try again.'), findsOneWidget);
      expect(downloadFor('tiny'), findsOneWidget);
      verifyNever(() => configs.saveConfig(any()));
    },
  );

  testWidgets(
    'removal deletes device files without deleting synced model configuration',
    (tester) async {
      when(() => models.isInstalled('tiny')).thenAnswer((_) async => true);
      when(() => models.remove('tiny')).thenAnswer((_) async {});
      await pump(tester);
      await tester.ensureVisible(find.byType(DesignSystemIconAction));
      await tester.tap(find.byType(DesignSystemIconAction));
      await tester.pumpAndSettle();
      verify(() => models.remove('tiny')).called(1);
      verify(() => broadcaster.broadcastIfChanged()).called(1);
      verifyNever(() => configs.saveConfig(any()));
      expect(downloadFor('tiny'), findsOneWidget);
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
      await tester.ensureVisible(find.byType(DesignSystemIconAction));
      await tester.tap(find.byType(DesignSystemIconAction));
      await tester.pumpAndSettle();
      expect(find.text('Downloaded'), findsOneWidget);
      expect(find.text('Model operation failed. Try again.'), findsOneWidget);
      expect(find.byType(DesignSystemIconAction), findsOneWidget);
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
        await tester.ensureVisible(downloadFor('tiny'));
        await tester.tap(downloadFor('tiny'));
        await tester.pumpAndSettle();
        expect(find.text('Downloaded'), findsOneWidget);
        expect(downloadFor('tiny'), findsNothing);
        expect(find.text('Model operation failed. Try again.'), findsNothing);
        expect(
          find.text(
            'Model downloaded, but its configuration could not be saved.',
          ),
          findsOneWidget,
        );
        verify(() => broadcaster.broadcastIfChanged()).called(1);
        await tester.ensureVisible(find.byType(DesignSystemIconAction));
        await tester.tap(find.byType(DesignSystemIconAction));
        await tester.pumpAndSettle();
        verify(() => models.remove('tiny')).called(1);
        expect(downloadFor('tiny'), findsOneWidget);
        expect(
          find.text(
            'Model downloaded, but its configuration could not be saved.',
          ),
          findsNothing,
        );
      },
    );
  }

  testWidgets(
    'retries configuration without downloading verified files again',
    (tester) async {
      when(
        () => models.install('tiny', onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async => '/model');
      when(
        () => configs.saveConfig(any()),
      ).thenThrow(StateError('database busy'));
      await pump(tester);
      await tester.ensureVisible(downloadFor('tiny'));
      await tester.tap(downloadFor('tiny'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Model downloaded, but its configuration could not be saved.',
        ),
        findsOneWidget,
      );
      final retryFinished = Completer<void>();
      when(
        () => configs.saveConfig(any()),
      ).thenAnswer((_) => retryFinished.future);
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(
        tester
            .widget<DesignSystemButton>(
              find.widgetWithText(DesignSystemButton, 'Retry'),
            )
            .isLoading,
        isTrue,
      );
      expect(
        tester
            .widget<DesignSystemIconAction>(find.byType(DesignSystemIconAction))
            .onPressed,
        isNull,
      );
      retryFinished.complete();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Model downloaded, but its configuration could not be saved.',
        ),
        findsNothing,
      );
      expect(find.text('Downloaded'), findsOneWidget);
      verify(
        () => models.install('tiny', onProgress: any(named: 'onProgress')),
      ).called(1);
      verify(() => configs.saveConfig(any())).called(2);
    },
  );

  testWidgets('failed removal preserves configuration retry', (tester) async {
    when(
      () => models.install('tiny', onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) async => '/model');
    when(
      () => configs.saveConfig(any()),
    ).thenThrow(StateError('database busy'));
    when(() => models.remove('tiny')).thenThrow(StateError('file busy'));
    await pump(tester);
    await tester.ensureVisible(downloadFor('tiny'));
    await tester.tap(downloadFor('tiny'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DesignSystemIconAction));
    await tester.tap(find.byType(DesignSystemIconAction));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    when(() => configs.saveConfig(any())).thenAnswer((_) async {});
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.text('Model downloaded, but its configuration could not be saved.'),
      findsNothing,
    );
    verify(() => configs.saveConfig(any())).called(2);
    verify(
      () => models.install('tiny', onProgress: any(named: 'onProgress')),
    ).called(1);
  });

  testWidgets('removal stays busy without displaying download progress', (
    tester,
  ) async {
    when(() => models.isInstalled('tiny')).thenAnswer((_) async => true);
    final removed = Completer<void>();
    when(() => models.remove('tiny')).thenAnswer((_) => removed.future);
    await pump(tester);
    final action = find.byType(DesignSystemIconAction);
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();
    expect(tester.widget<DesignSystemIconAction>(action).isBusy, isTrue);
    expect(find.byType(DesignSystemProgressBar), findsNothing);
    await tester.tap(action);
    verify(() => models.remove('tiny')).called(1);
    removed.complete();
    await tester.pumpAndSettle();
    expect(downloadFor('tiny'), findsOneWidget);
    expect(find.text('Downloaded'), findsNothing);
  });

  for (final width in [320.0, 800.0]) {
    testWidgets('download actions remain compact and usable at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(tester, textScale: 1.5, locale: const Locale('de'));
      final row = find.byKey(const ValueKey('sherpa-model-large-v3'));
      final action = find.descendant(
        of: row,
        matching: find.byType(DesignSystemButton),
      );
      final rowRect = tester.getRect(row);
      final actionRect = tester.getRect(action);
      expect(actionRect.width, lessThan(rowRect.width));
      expect(actionRect.left, greaterThanOrEqualTo(rowRect.left));
      expect(actionRect.right, lessThanOrEqualTo(rowRect.right));
      expect(
        find.descendant(of: row, matching: find.text('1,78 GB · Mehrsprachig')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      final semantics = tester.ensureSemantics();
      try {
        expect(
          find.bySemanticsLabel('Whisper Large v3 herunterladen'),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
      when(
        () => models.install('large-v3', onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async => '/model');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: row, matching: find.text('1,78 GB · Mehrsprachig')),
        findsOneWidget,
      );
      verify(
        () => models.install('large-v3', onProgress: any(named: 'onProgress')),
      ).called(1);
    });
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
    await tester.ensureVisible(downloadFor('tiny'));
    await tester.tap(downloadFor('tiny'));
    await tester.pumpAndSettle();
    verifyNever(() => configs.saveConfig(any()));
    expect(find.text('Downloaded'), findsOneWidget);
    expect(downloadFor('tiny'), findsNothing);
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
    await tester.ensureVisible(downloadFor('tiny'));
    await tester.tap(downloadFor('tiny'));
    await tester.pumpAndSettle();
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Model operation failed. Try again.'), findsNothing);
    verify(() => configs.saveConfig(any())).called(1);
  });
}
