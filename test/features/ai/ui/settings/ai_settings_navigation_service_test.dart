import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../test_utils.dart';

/// Records the most recent push so tests can assert WHICH widget was
/// pushed, not just that *something* happened.
class _PushSpy extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  group('AiSettingsNavigationService Comprehensive Tests', () {
    late AiSettingsNavigationService service;
    late AiConfig testProvider;
    late AiConfig testModel;

    late MockNavService mockNavService;

    setUpAll(AiTestSetup.registerFallbackValues);

    setUp(() {
      service = const AiSettingsNavigationService();

      // The v4 navigation service beams URLs (provider/model/profile
      // detail) through `nav_service.beamToNamed`, which calls
      // `getIt<NavService>()`. Tests that exercise `navigateToConfigEdit`
      // for any config kind would otherwise crash with a missing-
      // registration error — register a no-op mock for both arms.
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      mockNavService = MockNavService();
      when(() => mockNavService.beamToNamed(any())).thenReturn(null);
      getIt.registerSingleton<NavService>(mockNavService);

      testProvider = AiTestDataFactory.createTestProvider(
        id: 'test-provider-id',
        description: 'A test provider for navigation testing',
      );

      testModel = AiTestDataFactory.createTestModel(
        id: 'test-model-id',
        description: 'A test model for navigation testing',
      );
    });

    tearDown(() {
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
    });

    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        home: Scaffold(
          body: child ?? const Center(child: Text('Test Widget')),
        ),
      );
    }

    group('Config Type Recognition', () {
      test('should correctly identify provider configs', () {
        expect(testProvider, isA<AiConfigInferenceProvider>());
        expect(
          testProvider.runtimeType.toString(),
          contains('AiConfigInferenceProvider'),
        );
      });

      test('should correctly identify model configs', () {
        expect(testModel, isA<AiConfigModel>());
        expect(testModel.runtimeType.toString(), contains('AiConfigModel'));
      });

      test('should work with different inference provider types', () {
        final anthropicProvider = AiTestDataFactory.createTestProvider();
        final openAiProvider = AiTestDataFactory.createTestProvider(
          type: InferenceProviderType.openAi,
        );
        final genericProvider = AiTestDataFactory.createTestProvider(
          type: InferenceProviderType.genericOpenAi,
        );

        expect(anthropicProvider, isA<AiConfigInferenceProvider>());
        expect(openAiProvider, isA<AiConfigInferenceProvider>());
        expect(genericProvider, isA<AiConfigInferenceProvider>());
      });

      test('should work with different modality combinations', () {
        final textModel = AiTestDataFactory.createTestModel(
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
        );
        final multiModalModel = AiTestDataFactory.createTestModel(
          inputModalities: [Modality.text, Modality.image],
          outputModalities: [Modality.text, Modality.image],
        );

        expect(textModel, isA<AiConfigModel>());
        expect(multiModalModel, isA<AiConfigModel>());
      });
    });

    group('Navigation Method Contracts', () {
      testWidgets(
        'navigateToConfigEdit should accept valid contexts and configs',
        (WidgetTester tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(Scaffold));

          // Test that the method signature accepts the expected parameters
          expect(
            () => service.navigateToConfigEdit(context, testProvider),
            returnsNormally,
          );
          expect(
            () => service.navigateToConfigEdit(context, testModel),
            returnsNormally,
          );
        },
      );

      testWidgets('create navigation methods should accept valid contexts', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(Scaffold));

        // Test that create methods don't throw on invocation
        expect(
          () => service.navigateToCreateProvider(context),
          returnsNormally,
        );
        expect(() => service.navigateToCreateModel(context), returnsNormally);
      });
    });

    group('Profile Navigation', () {
      testWidgets('navigateToConfigEdit accepts inference profile config', (
        WidgetTester tester,
      ) async {
        final testProfile = AiTestDataFactory.createTestProfile(
          id: 'test-profile-id',
          description: 'A test profile for navigation testing',
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(Scaffold));

        expect(
          () => service.navigateToConfigEdit(context, testProfile),
          returnsNormally,
        );
      });

      testWidgets('navigateToCreateProfile accepts valid context', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(Scaffold));

        expect(
          () => service.navigateToCreateProfile(context),
          returnsNormally,
        );
      });
    });

    group('Route Creation Logic', () {
      testWidgets('should handle route creation for different config types', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Test that route creation methods can be called without throwing
        expect(
          () => service.navigateToConfigEdit(
            tester.element(find.byType(Scaffold)),
            testProvider,
          ),
          returnsNormally,
        );
        expect(
          () => service.navigateToConfigEdit(
            tester.element(find.byType(Scaffold)),
            testModel,
          ),
          returnsNormally,
        );
      });

      testWidgets('should handle page builder functions correctly', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(Scaffold));

        // These should not throw when called
        expect(
          () => service.navigateToCreateProvider(context),
          returnsNormally,
        );
        expect(() => service.navigateToCreateModel(context), returnsNormally);
      });
    });

    group('Integration with Flutter Framework', () {
      testWidgets('should work with themed MaterialApp', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(body: Container()),
          ),
        );
        await tester.pumpAndSettle();
      });
    });

    /// Modular coverage for the create-* and provider-edit push flows.
    /// These exercise the actual `_createSlideRoute` builder so the
    /// transition closure body executes (covers the otherwise-orphaned
    /// `navigateToCreateProfile` lines and the new
    /// `navigateToProviderEdit` overload added for the detail page's
    /// edit affordance).
    group('Push routing — concrete page assertions', () {
      late _PushSpy spy;

      setUp(() {
        spy = _PushSpy();
      });

      // The pushed pages (provider/model/profile edit forms) read
      // Riverpod, design tokens, and localizations from their ancestors
      // so the harness wraps the route in a `ProviderScope`, the design
      // tokens theme extension, and the AppLocalizations delegates.
      Widget harness({Widget? child}) {
        return ProviderScope(
          child: MaterialApp(
            navigatorObservers: [spy],
            theme: ThemeData(
              useMaterial3: true,
              extensions: const <ThemeExtension<dynamic>>[dsTokensLight],
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: child ?? const Center(child: Text('home')),
            ),
          ),
        );
      }

      // Each navigateTo* method returns a `Future<void>` that only
      // completes when the pushed route is popped. Tests below DO NOT
      // await that future — instead they fire-and-forget, then
      // `pumpAndSettle` so the widget tree mounts the new page, and
      // assert on what landed in the tree.
      testWidgets(
        'navigateToCreateProvider pushes InferenceProviderEditPage with the '
        'preselected type forwarded into the constructor',
        (tester) async {
          await tester.pumpWidget(harness());
          final ctx = tester.element(find.byType(Scaffold));
          unawaited(
            service.navigateToCreateProvider(
              ctx,
              preselectedType: InferenceProviderType.anthropic,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(InferenceProviderEditPage), findsOneWidget);
          final pushedPage = tester.widget<InferenceProviderEditPage>(
            find.byType(InferenceProviderEditPage),
          );
          expect(pushedPage.preselectedType, InferenceProviderType.anthropic);
          expect(pushedPage.configId, isNull);
          expect(pushedPage.focusApiKey, isFalse);
        },
      );

      testWidgets(
        'navigateToCreateModel pushes a blank InferenceModelEditPage',
        (tester) async {
          await tester.pumpWidget(harness());
          final ctx = tester.element(find.byType(Scaffold));
          unawaited(service.navigateToCreateModel(ctx));
          await tester.pumpAndSettle();
          expect(find.byType(InferenceModelEditPage), findsOneWidget);
        },
      );

      testWidgets(
        'navigateToCreateProfile pushes a blank InferenceProfileForm',
        (tester) async {
          await tester.pumpWidget(harness());
          final ctx = tester.element(find.byType(Scaffold));
          unawaited(service.navigateToCreateProfile(ctx));
          await tester.pumpAndSettle();
          expect(find.byType(InferenceProfileForm), findsOneWidget);
        },
      );

      testWidgets(
        'navigateToProviderEdit with focusApiKey=false pushes the edit page '
        'with the matching configId and the focus flag cleared — used when '
        'the user taps the detail page edit pencil',
        (tester) async {
          await tester.pumpWidget(harness());
          final ctx = tester.element(find.byType(Scaffold));
          unawaited(
            service.navigateToProviderEdit(
              ctx,
              providerId: 'gemini-1',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(InferenceProviderEditPage), findsOneWidget);
          final pushedPage = tester.widget<InferenceProviderEditPage>(
            find.byType(InferenceProviderEditPage),
          );
          expect(pushedPage.configId, 'gemini-1');
          expect(pushedPage.focusApiKey, isFalse);
        },
      );

      testWidgets(
        'navigateToProviderEdit with focusApiKey=true pushes the edit page '
        'with focusApiKey forwarded — covers the Fix-flow overlay path',
        (tester) async {
          await tester.pumpWidget(harness());
          final ctx = tester.element(find.byType(Scaffold));
          unawaited(
            service.navigateToProviderEdit(
              ctx,
              providerId: 'gemini-2',
              focusApiKey: true,
            ),
          );
          await tester.pumpAndSettle();
          final pushedPage = tester.widget<InferenceProviderEditPage>(
            find.byType(InferenceProviderEditPage),
          );
          expect(pushedPage.configId, 'gemini-2');
          expect(pushedPage.focusApiKey, isTrue);
        },
      );

      testWidgets(
        'each create/edit push installs a PageRoute via the slide-route '
        'builder — exercises the shared `_createSlideRoute` closure so '
        'the transitionsBuilder branches paint without throwing',
        (tester) async {
          await tester.pumpWidget(harness());
          final initialPushCount = spy.pushed.length;
          final ctx = tester.element(find.byType(Scaffold));

          unawaited(service.navigateToCreateModel(ctx));
          await tester.pump();
          // Mid-transition pump exercises both the incoming and
          // outgoing animations registered in `_createSlideRoute`.
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          final newPushes = spy.pushed.skip(initialPushCount).toList();
          expect(newPushes, hasLength(1));
          expect(newPushes.first, isA<PageRoute<void>>());
        },
      );

      testWidgets(
        'navigateToConfigEdit for a model config beams to the per-model URL '
        'rather than pushing — desktop master/detail panel swap path',
        (tester) async {
          await tester.pumpWidget(harness());
          final initialPushCount = spy.pushed.length;
          final ctx = tester.element(find.byType(Scaffold));
          await service.navigateToConfigEdit(ctx, testModel);
          await tester.pump();
          verify(
            () =>
                mockNavService.beamToNamed('/settings/ai/model/test-model-id'),
          ).called(1);
          // No new Navigator push beyond the initial route mount.
          expect(spy.pushed.length, initialPushCount);
        },
      );

      testWidgets(
        'navigateToConfigEdit for a profile config beams to the per-profile '
        'URL rather than pushing',
        (tester) async {
          final profile = AiTestDataFactory.createTestProfile(
            id: 'profile-x',
          );
          await tester.pumpWidget(harness());
          final ctx = tester.element(find.byType(Scaffold));
          await service.navigateToConfigEdit(ctx, profile);
          await tester.pump();
          verify(
            () => mockNavService.beamToNamed('/settings/ai/profile/profile-x'),
          ).called(1);
        },
      );

      testWidgets(
        'navigateToConfigEdit for a provider config beams to the detail URL '
        '(without focusApiKey) via navigateToProviderDetail',
        (tester) async {
          await tester.pumpWidget(harness());
          final ctx = tester.element(find.byType(Scaffold));
          await service.navigateToConfigEdit(ctx, testProvider);
          await tester.pump();
          verify(
            () => mockNavService.beamToNamed(
              '/settings/ai/provider/test-provider-id',
            ),
          ).called(1);
        },
      );

      testWidgets(
        'navigateToProviderDetail with focusApiKey=true beams the detail URL '
        'with the `?focusApiKey=true` query — Fix-flow entry point',
        (tester) async {
          await tester.pumpWidget(harness());
          final ctx = tester.element(find.byType(Scaffold));
          await service.navigateToProviderDetail(
            ctx,
            providerId: 'p-1',
            focusApiKey: true,
          );
          verify(
            () => mockNavService.beamToNamed(
              '/settings/ai/provider/p-1?focusApiKey=true',
            ),
          ).called(1);
        },
      );

      testWidgets(
        'navigateToConfigEdit for a skill config falls back to the legacy '
        'no-op slide route — skill rows are not yet editable in v2 settings, '
        'so they push an empty placeholder rather than beaming a URL',
        (tester) async {
          await tester.pumpWidget(harness());
          final initialPushCount = spy.pushed.length;
          final ctx = tester.element(find.byType(Scaffold));
          unawaited(
            service.navigateToConfigEdit(
              ctx,
              AiConfig.skill(
                id: 'skill-1',
                name: 'Skill 1',
                createdAt: DateTime(2024, 3, 15),
                skillType: SkillType.transcription,
                requiredInputModalities: const [Modality.audio],
                systemInstructions: '',
                userInstructions: '',
              ),
            ),
          );
          await tester.pumpAndSettle();
          // One additional push (the placeholder slide route).
          expect(spy.pushed.length, initialPushCount + 1);
          // No beam for the skill fallback — it's a Navigator push.
          verifyNever(() => mockNavService.beamToNamed(any()));
        },
      );
    });
  });
}
