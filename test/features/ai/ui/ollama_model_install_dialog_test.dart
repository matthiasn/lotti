import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart'
    show AiConfigByTypeController;
import 'package:lotti/features/ai/ui/ollama_model_install_dialog.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart'
    show makeTestableWidgetNoScroll, resolveTestTheme;
import '../test_utils.dart';

/// A single-shot stream override for AiConfigByTypeController that uses
/// Stream.value so that provider.future resolves immediately. Needed when
/// testing code that calls ref.read(provider.future) inside an async method
/// driven by widget interaction (e.g. _installModel).
class _ImmediateAiConfigByTypeController extends AiConfigByTypeController {
  _ImmediateAiConfigByTypeController(this._configs);
  final List<AiConfig> _configs;

  @override
  Stream<List<AiConfig>> build({required AiConfigType configType}) =>
      Stream.value(_configs);
}

void main() {
  late MockCloudInferenceRepository mockCloudRepository;
  late AiConfigInferenceProvider testOllamaProvider;

  const testModelName = 'gemma3:4b';

  setUp(() {
    mockCloudRepository = MockCloudInferenceRepository();

    testOllamaProvider =
        AiConfig.inferenceProvider(
              id: 'test-ollama-provider',
              name: 'Test Ollama',
              baseUrl: 'http://localhost:11434',
              apiKey: '',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              inferenceProviderType: InferenceProviderType.ollama,
            )
            as AiConfigInferenceProvider;
  });

  /// Thin wrapper over the central [makeTestableWidgetNoScroll] (DS theme,
  /// localizations, phone media query) that adds the cloud repository
  /// override and a host Scaffold.
  Widget buildTestWidget(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return makeTestableWidgetNoScroll(
      Scaffold(body: child),
      overrides: [
        cloudInferenceRepositoryProvider.overrideWithValue(
          mockCloudRepository,
        ),
        ...overrides,
      ],
    );
  }

  /// Pumps the dialog with the keep-open [MockAiConfigByTypeController]
  /// supplying [testOllamaProvider] — mirrors how the dialog is hosted when
  /// rendered inline by the progress view.
  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        const OllamaModelInstallDialog(modelName: testModelName),
        overrides: [
          aiConfigByTypeControllerProvider(
            configType: AiConfigType.inferenceProvider,
          ).overrideWith(
            () => MockAiConfigByTypeController([testOllamaProvider]),
          ),
        ],
      ),
    );
  }

  /// Pumps an [OllamaModelInstallDialog] with a real DS theme (so the success
  /// toast can resolve design tokens), an immediate provider-type controller
  /// supplying [providers], and the cloud repository override. Used by the
  /// `_installModel` end-to-end tests below which need `context.showToast` to
  /// work.
  Future<void> pumpInstallDialog(
    WidgetTester tester, {
    required String modelName,
    required List<AiConfig> providers,
    VoidCallback? onModelInstalled,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudInferenceRepositoryProvider.overrideWithValue(
            mockCloudRepository,
          ),
          aiConfigByTypeControllerProvider(
            configType: AiConfigType.inferenceProvider,
          ).overrideWith(() => _ImmediateAiConfigByTypeController(providers)),
        ],
        child: MaterialApp(
          theme: resolveTestTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Push the dialog onto a base Scaffold route so _installModel's
          // Navigator.of(context).pop() returns to the base (which hosts the
          // ScaffoldMessenger the success toast attaches to) instead of
          // emptying the navigator and tearing down the messenger.
          home: Consumer(
            builder: (context, ref, child) {
              // Watch aiConfigByTypeControllerProvider here so it stays alive
              // (it is autoDispose). Otherwise it can be torn down mid-load
              // when _installModel reads its .future, surfacing a Riverpod
              // "disposed during loading state" error instead of the real
              // provider-lookup result.
              ref.watch(
                aiConfigByTypeControllerProvider(
                  configType: AiConfigType.inferenceProvider,
                ),
              );
              return child!;
            },
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Builder(
                    builder: (context) {
                      // Push the dialog as a second route after first frame.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              body: OllamaModelInstallDialog(
                                modelName: modelName,
                                onModelInstalled: onModelInstalled,
                              ),
                            ),
                          ),
                        );
                      });
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('OllamaModelInstallDialog - initial state', () {
    testWidgets('displays correct initial state', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Model Not Installed'), findsOneWidget);
      expect(
        find.text('The model "$testModelName" is not installed.'),
        findsOneWidget,
      );
      expect(
        find.text('To install it, run this command in your terminal:'),
        findsOneWidget,
      );
      expect(find.text('ollama pull $testModelName'), findsOneWidget);
      expect(
        find.text('Would you like to install it now from Lotti?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Install'), findsOneWidget);
    });

    testWidgets('displays command text as selectable', (tester) async {
      await pumpDialog(tester);

      // The pull command should be rendered as a SelectableText widget.
      final commandFinder = find.text('ollama pull $testModelName');
      expect(commandFinder, findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('cancel button closes dialog', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => const OllamaModelInstallDialog(
                modelName: 'test-model',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap cancel — bounded pumps until the pop transition finishes and the
      // route is removed, capped so a regression that never pops fails
      // instead of hanging.
      await tester.tap(find.text('Cancel'));
      for (var i = 0; i < 30; i++) {
        if (find.byType(OllamaModelInstallDialog).evaluate().isEmpty) break;
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Dialog should be closed
      expect(find.byType(OllamaModelInstallDialog), findsNothing);
    });
  });

  group('OllamaModelInstallDialog - install flow', () {
    testWidgets('shows installation UI when install button is pressed', (
      tester,
    ) async {
      final progressStream = Stream<OllamaPullProgress>.fromIterable([
        const OllamaPullProgress(status: 'pulling manifest', progress: 0),
      ]);

      when(
        () => mockCloudRepository.installModel(testModelName, any()),
      ).thenAnswer((_) => progressStream);

      await pumpDialog(tester);

      // Act - Press install button
      await tester.tap(find.text('Install'));
      await tester.pump();

      // Assert - Should show installation UI
      expect(find.text('Installing model...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'resets to install state when install fails',
      (tester) async {
        // thenThrow drives the catch block synchronously so bounded pumps
        // complete the full async chain.
        when(
          () => mockCloudRepository.installModel(any(), any()),
        ).thenThrow(Exception('Installation failed'));

        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'ollama-test',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434/',
        );

        await tester.pumpWidget(
          buildTestWidget(
            const OllamaModelInstallDialog(modelName: 'phi3'),
            overrides: [
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(
                () => _ImmediateAiConfigByTypeController([ollamaProvider]),
              ),
            ],
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap install – the "Installing model..." state is set first.
        await tester.tap(find.text('Install'));
        await tester.pump();
        // _isInstalling = true: the installing state is active.
        expect(find.text('Installing model...'), findsOneWidget);

        // Drive the async chain: provider.future → installModel throws
        // → catch strips 'Exception: ', sets _error, _isInstalling=false.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // After error: _isInstalling=false so Install button is back.
        expect(find.text('Install'), findsOneWidget);
        // "Installing model..." is gone
        expect(find.text('Installing model...'), findsNothing);
      },
    );

    testWidgets(
      'Install button is re-enabled after failed install enabling re-attempt',
      (tester) async {
        // This test verifies that after a failed install attempt:
        // 1. The Install button reappears (_isInstalling reset to false)
        // 2. Tapping it again starts a new _installModel call
        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'ollama-retry2',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434/',
        );

        when(
          () => mockCloudRepository.installModel(any(), any()),
        ).thenThrow(Exception('fail'));

        await tester.pumpWidget(
          buildTestWidget(
            const OllamaModelInstallDialog(modelName: 'gemma'),
            overrides: [
              aiConfigByTypeControllerProvider(
                configType: AiConfigType.inferenceProvider,
              ).overrideWith(
                () => _ImmediateAiConfigByTypeController([ollamaProvider]),
              ),
            ],
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // First install attempt
        await tester.tap(find.text('Install'));
        await tester.pump();
        // _isInstalling=true: Install button is hidden, "Installing model..." shows
        expect(find.text('Install'), findsNothing);
        expect(find.text('Installing model...'), findsOneWidget);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // After error: _isInstalling=false, Install button re-appears
        expect(find.text('Install'), findsOneWidget);

        // Second tap re-invokes _installModel (install button enables retry)
        await tester.tap(find.text('Install'));
        await tester.pump();
        // _isInstalling=true again: showing "Installing model..."
        expect(find.text('Installing model...'), findsOneWidget);
      },
    );
  });

  // ── OllamaModelInstallDialog._installModel — end-to-end with finite streams ──
  // These drive the real success/error branches of _installModel. The install
  // stream is ALWAYS finite (Stream.fromIterable / Stream.error) so the
  // `await for` loop completes and teardown never hits an open StreamController.
  group('OllamaModelInstallDialog - _installModel finite-stream branches', () {
    AiConfigInferenceProvider makeOllama() =>
        AiTestDataFactory.createTestProvider(
          id: 'ollama-e2e',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434/',
        );

    testWidgets(
      'success stream pops dialog, fires callback and shows success toast',
      (tester) async {
        // Finite success stream: a mid-progress event (0.5 → renders the "%"
        // text during the rebuild) then a terminal success event.
        when(() => mockCloudRepository.installModel(any(), any())).thenAnswer(
          (_) => Stream.fromIterable(const [
            OllamaPullProgress(status: 'downloading', progress: 0.5),
            OllamaPullProgress(status: 'success', progress: 1),
          ]),
        );

        var installedCallbackFired = false;

        await pumpInstallDialog(
          tester,
          modelName: 'llama3',
          providers: [makeOllama()],
          onModelInstalled: () => installedCallbackFired = true,
        );

        await tester.tap(find.text('Install'));
        // Drive the async chain in finite, bounded pumps (no pumpAndSettle so
        // the success SnackBar is asserted while it is still on screen rather
        // than after it has timed out and dismissed at 4s). Pump in small
        // bounded steps until the dialog pops (stream completed → toast/pop),
        // capped so a regression that never pops fails instead of hanging.
        for (var i = 0; i < 20; i++) {
          if (find.byType(OllamaModelInstallDialog).evaluate().isEmpty) break;
          await tester.pump(const Duration(milliseconds: 50));
        }
        // Let the SnackBar entrance animation render its DesignSystemToast,
        // staying well under the 4s auto-dismiss timeout.
        await tester.pump(const Duration(milliseconds: 350));

        // Dialog popped once the stream completed.
        expect(find.byType(OllamaModelInstallDialog), findsNothing);
        // onModelInstalled callback ran.
        expect(installedCallbackFired, isTrue);
        // Success toast surfaced on the parent scaffold.
        final toast = tester.widget<DesignSystemToast>(
          find.byType(DesignSystemToast),
        );
        expect(toast.tone, DesignSystemToastTone.success);
      },
    );

    testWidgets(
      'intermediate progress events update status text, bar value and '
      'percentage',
      (tester) async {
        // A StreamController lets us assert the UI between individual events,
        // which Stream.fromIterable cannot (all events flush in one pump).
        // It is closed within the test so the `await for` loop completes
        // finitely, keeping the group's no-open-controllers guarantee.
        final progressController = StreamController<OllamaPullProgress>();
        when(
          () => mockCloudRepository.installModel(any(), any()),
        ).thenAnswer((_) => progressController.stream);

        await pumpInstallDialog(
          tester,
          modelName: 'llama3',
          providers: [makeOllama()],
        );

        await tester.tap(find.text('Install'));
        // Bounded pumps until the installing UI shows: the provider .future
        // read and the stream subscription need a few event-loop turns.
        for (var i = 0; i < 20; i++) {
          if (find.text('Installing model...').evaluate().isNotEmpty) break;
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.text('Installing model...'), findsOneWidget);

        // Manifest pull at progress 0: status renders, the bar is at 0, and
        // the percentage line is suppressed by the `_progress > 0` guard.
        progressController.add(
          const OllamaPullProgress(status: 'pulling manifest', progress: 0),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('pulling manifest'), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          0,
        );
        expect(find.textContaining('%'), findsNothing);

        // Mid-download event replaces the status and renders the percentage.
        progressController.add(
          const OllamaPullProgress(status: 'downloading', progress: 0.42),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('downloading'), findsOneWidget);
        expect(find.text('pulling manifest'), findsNothing);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          closeTo(0.42, 1e-9),
        );
        expect(find.text('42.0%'), findsOneWidget);

        // A later event overwrites the previous progress (toStringAsFixed(1)
        // rounding: 0.875 → 87.5%).
        progressController.add(
          const OllamaPullProgress(
            status: 'verifying sha256 digest',
            progress: 0.875,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('verifying sha256 digest'), findsOneWidget);
        expect(find.text('87.5%'), findsOneWidget);
        expect(find.text('42.0%'), findsNothing);

        // Closing the stream completes the `await for` → success path pops
        // the dialog (same bounded-pump pattern as the success test above).
        await progressController.close();
        for (var i = 0; i < 20; i++) {
          if (find.byType(OllamaModelInstallDialog).evaluate().isEmpty) break;
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byType(OllamaModelInstallDialog), findsNothing);
      },
    );

    testWidgets(
      'no Ollama provider throws and renders the not-found error',
      (tester) async {
        // installModel must never be reached: firstOrNull is null because the
        // supplied providers contain no Ollama provider.
        await pumpInstallDialog(
          tester,
          modelName: 'phi3',
          providers: const <AiConfig>[],
        );

        await tester.tap(find.text('Install'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The thrown Exception message ('Exception: ' prefix stripped).
        expect(
          find.textContaining('Ollama provider not found'),
          findsOneWidget,
        );
        // _isInstalling reset to false → Install button visible again.
        expect(find.text('Install'), findsOneWidget);
        expect(find.text('Installing model...'), findsNothing);
        // installModel was never invoked because the provider lookup failed.
        verifyNever(() => mockCloudRepository.installModel(any(), any()));
      },
    );

    testWidgets(
      'stream error is caught and rendered with stripped prefix',
      (tester) async {
        // Finite error stream: the `await for` rethrows inside _installModel,
        // hitting the catch block which strips the "Exception: " prefix.
        when(() => mockCloudRepository.installModel(any(), any())).thenAnswer(
          (_) => Stream<OllamaPullProgress>.error(Exception('boom')),
        );

        await pumpInstallDialog(
          tester,
          modelName: 'mistral',
          providers: [makeOllama()],
        );

        await tester.tap(find.text('Install'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // "Exception: " prefix stripped → only "Error: boom" remains.
        expect(find.text('Error: boom'), findsOneWidget);
        // Install button is back (catch sets _isInstalling = false).
        expect(find.text('Install'), findsOneWidget);
      },
    );
  });
}
