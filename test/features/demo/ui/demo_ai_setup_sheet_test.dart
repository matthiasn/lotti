import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/demo/ui/demo_ai_setup_sheet.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_api_key_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_connect_panel.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_success_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// The panels run continuous backdrop animations, so tests pump fixed
/// durations instead of pumpAndSettle (which would never settle).
Future<void> settleStep(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Pumps the flow inside a Scaffold (the reused onboarding panels contain
/// InkWells, which need a Material ancestor — production provides one via
/// the sheet's own transparent Scaffold).
Future<void> pumpFlow(
  WidgetTester tester, {
  required VoidCallback onConnected,
  required VoidCallback onClose,
  DemoAiSetupStep initialStep = DemoAiSetupStep.intro,
  DemoWorldWiring? wireWorld,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: SingleChildScrollView(
          child: DemoAiSetupFlow(
            onConnected: (_) => onConnected(),
            onClose: onClose,
            initialStep: initialStep,
            wireWorld: wireWorld,
          ),
        ),
      ),
    ),
  );
  await settleStep(tester);
}

void main() {
  setUpAll(registerAllFallbackValues);

  testWidgets('intro names the deal — pretend AI, real account, key stays '
      'in the demo world — and Not now closes without connecting', (
    tester,
  ) async {
    var closed = false;
    var connected = false;
    await pumpFlow(
      tester,
      onConnected: () => connected = true,
      onClose: () => closed = true,
    );

    expect(find.text('AI in the demo is pretend'), findsOneWidget);
    // The copy must state that real AI runs on the user's real account and
    // that the key stays in the demo world unless copied over on exit.
    expect(
      find.textContaining('your own AI account'),
      findsOneWidget,
    );
    expect(
      find.textContaining('stays in this demo world'),
      findsOneWidget,
    );

    await tester.tap(find.text('Not now'));
    await settleStep(tester);

    expect(closed, isTrue);
    expect(connected, isFalse);
  });

  testWidgets('Set up real AI advances to the reused onboarding connect '
      'panel; its back button returns to the intro', (tester) async {
    await pumpFlow(tester, onConnected: () {}, onClose: () {});

    await tester.tap(find.text('Set up real AI'));
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(OnboardingConnectPanel), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('AI in the demo is pretend'), findsOneWidget);
  });

  testWidgets('picking a provider opens the reused onboarding API-key panel '
      'for exactly that provider', (tester) async {
    await pumpFlow(tester, onConnected: () {}, onClose: () {});

    await tester.tap(find.text('Set up real AI'));
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(OnboardingConnectPanel), findsOneWidget);
    await tester.tap(find.text('Gemini'), warnIfMissed: false);
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(OnboardingApiKeyPanel), findsOneWidget);
    // The key panel is headed by the chosen provider's name.
    expect(find.text('Gemini'), findsOneWidget);
  });

  testWidgets('a connected provider wires the demo world to its bundled '
      'profile and advances to the success beat', (tester) async {
    var connected = false;
    final wiredTypes = <InferenceProviderType>[];
    await pumpFlow(
      tester,
      onConnected: () => connected = true,
      onClose: () {},
      wireWorld: (type) async => wiredTypes.add(type),
    );

    await tester.tap(find.text('Set up real AI'));
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Gemini'), warnIfMissed: false);
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    // Drive the key panel's success callback directly — the panel's own
    // provider-creation path needs a live backend and is covered by its
    // own tests.
    tester
        .widget<OnboardingApiKeyPanel>(find.byType(OnboardingApiKeyPanel))
        .onConnected();
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(connected, isTrue);
    expect(
      wiredTypes,
      [InferenceProviderType.gemini],
      reason:
          'the seeded tasks/category must be pointed at the connected '
          "provider's bundled profile",
    );
    expect(find.text('Real AI is live'), findsOneWidget);
  });

  testWidgets('a wiring failure is swallowed — the success beat still '
      'shows', (tester) async {
    await pumpFlow(
      tester,
      onConnected: () {},
      onClose: () {},
      wireWorld: (_) async => throw StateError('demo db closed'),
    );

    await tester.tap(find.text('Set up real AI'));
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Gemini'), warnIfMissed: false);
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    tester
        .widget<OnboardingApiKeyPanel>(find.byType(OnboardingApiKeyPanel))
        .onConnected();
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Real AI is live'), findsOneWidget);
  });

  testWidgets('the success beat closes via its continue CTA', (tester) async {
    var closed = false;
    await pumpFlow(
      tester,
      onConnected: () {},
      onClose: () => closed = true,
      initialStep: DemoAiSetupStep.success,
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(OnboardingSuccessView), findsOneWidget);
    expect(find.text('Real AI is live'), findsOneWidget);
    // The success copy repeats the key-stays-here promise.
    expect(find.textContaining('stays here'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await settleStep(tester);

    expect(closed, isTrue);
  });

  testWidgets('DemoAiSetupSheet.show presents the intro over a dim barrier '
      'and fires onConfigured only when a provider was connected', (
    tester,
  ) async {
    var configured = false;
    late BuildContext hostContext;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final route = DemoAiSetupSheet.show(
      hostContext,
      onConfigured: () => configured = true,
    );
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('AI in the demo is pretend'), findsOneWidget);

    // Dismiss without connecting: the retry callback must NOT fire.
    await tester.tap(find.text('Not now'));
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await route;

    expect(configured, isFalse);
    expect(find.text('AI in the demo is pretend'), findsNothing);
  });

  testWidgets('the API-key panel backs out to the connect panel, not the '
      'intro', (tester) async {
    await pumpFlow(tester, onConnected: () {}, onClose: () {});

    await tester.tap(find.text('Set up real AI'));
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Gemini'), warnIfMissed: false);
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OnboardingApiKeyPanel), findsOneWidget);

    tester
        .widget<OnboardingApiKeyPanel>(find.byType(OnboardingApiKeyPanel))
        .onBack();
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(OnboardingConnectPanel), findsOneWidget);
    expect(find.text('AI in the demo is pretend'), findsNothing);
  });

  testWidgets('a wiring failure is reported to the domain logger when one '
      'is registered', (tester) async {
    final logger = MockDomainLogger();
    getIt.registerSingleton<DomainLogger>(logger);
    addTearDown(getIt.reset);
    await pumpFlow(
      tester,
      onConnected: () {},
      onClose: () {},
      wireWorld: (_) async => throw StateError('demo db closed'),
    );

    await tester.tap(find.text('Set up real AI'));
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Gemini'), warnIfMissed: false);
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));
    tester
        .widget<OnboardingApiKeyPanel>(find.byType(OnboardingApiKeyPanel))
        .onConnected();
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Real AI is live'), findsOneWidget);
    verify(
      () => logger.error(
        LogDomain.general,
        any(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'demoAiSetupWiring',
      ),
    ).called(1);
  });

  testWidgets('without a wiring seam the connected provider wires the demo '
      "world through the active generation's services", (tester) async {
    final db = MockJournalDb();
    final persistence = MockPersistenceLogic();
    when(() => db.getCategoryById(manualDemoCategoryId)).thenAnswer(
      (_) async => CategoryDefinition(
        id: manualDemoCategoryId,
        createdAt: DateTime(2026, 8, 5),
        updatedAt: DateTime(2026, 8, 5),
        name: 'Penguin Operations',
        vectorClock: null,
        private: false,
        active: true,
      ),
    );
    when(
      () => db.getJournalEntities(
        types: any(named: 'types'),
        starredStatuses: any(named: 'starredStatuses'),
        privateStatuses: any(named: 'privateStatuses'),
        flaggedStatuses: any(named: 'flaggedStatuses'),
        ids: any(named: 'ids'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((invocation) async {
      final offset = invocation.namedArguments[#offset] as int;
      return offset == 0
          ? <JournalEntity>[TestTaskFactory.create(id: 'seeded-task')]
          : const [];
    });
    when(
      () => persistence.upsertEntityDefinition(any()),
    ).thenAnswer((_) async => 1);
    when(
      () => persistence.updateTask(
        journalEntityId: any(named: 'journalEntityId'),
        taskData: any(named: 'taskData'),
      ),
    ).thenAnswer((_) async => true);
    getIt
      ..registerSingleton<JournalDb>(db)
      ..registerSingleton<PersistenceLogic>(persistence);
    addTearDown(getIt.reset);

    await pumpFlow(tester, onConnected: () {}, onClose: () {});
    await tester.tap(find.text('Set up real AI'));
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Gemini'), warnIfMissed: false);
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));
    tester
        .widget<OnboardingApiKeyPanel>(find.byType(OnboardingApiKeyPanel))
        .onConnected();
    await settleStep(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Real AI is live'), findsOneWidget);
    // The default wiring resolved Gemini's bundled profile and stamped the
    // seeded world with it.
    final upserted =
        verify(
              () => persistence.upsertEntityDefinition(captureAny()),
            ).captured.single
            as CategoryDefinition;
    expect(upserted.defaultProfileId, profileGeminiFlashId);
    verify(
      () => persistence.updateTask(
        journalEntityId: 'seeded-task',
        taskData: any(named: 'taskData'),
      ),
    ).called(1);
  });

  group('DemoAiSetupSheet.show', () {
    testWidgets('a completed connect flow fires onConfigured after the '
        'route pops', (tester) async {
      var configured = false;
      late BuildContext hostContext;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final route = DemoAiSetupSheet.show(
        hostContext,
        onConfigured: () => configured = true,
      );
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Set up real AI'));
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Gemini'), warnIfMissed: false);
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));
      tester
          .widget<OnboardingApiKeyPanel>(find.byType(OnboardingApiKeyPanel))
          .onConnected();
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        configured,
        isFalse,
        reason: 'the retry must wait until the route has popped',
      );

      await tester.tap(find.text('Continue'));
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await route;

      expect(configured, isTrue);
    });

    testWidgets('onConfigured waits for the demo-world wiring — the retried '
        'AI action must see the seeded tasks already stamped', (
      tester,
    ) async {
      final wiringGate = Completer<void>();
      var configured = false;
      late BuildContext hostContext;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final route = DemoAiSetupSheet.show(
        hostContext,
        onConfigured: () => configured = true,
        wireWorld: (_) => wiringGate.future,
      );
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Set up real AI'));
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Gemini'), warnIfMissed: false);
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));
      tester
          .widget<OnboardingApiKeyPanel>(find.byType(OnboardingApiKeyPanel))
          .onConnected();
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));

      // Route popped, but the wiring is still running: the retry must hold.
      await tester.tap(find.text('Continue'));
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        configured,
        isFalse,
        reason:
            'the intercepted-action retry must not run before the seeded '
            'tasks have their profileId stamped',
      );

      wiringGate.complete();
      await settleStep(tester);
      await route;

      expect(configured, isTrue);
    });

    testWidgets('tapping the panel itself never dismisses the route; only '
        'the outer barrier does', (tester) async {
      late BuildContext hostContext;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final route = DemoAiSetupSheet.show(hostContext);
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));

      // A tap INSIDE the panel is swallowed by its own gesture layer.
      await tester.tap(
        find.text('AI in the demo is pretend'),
        warnIfMissed: false,
      );
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('AI in the demo is pretend'), findsOneWidget);

      // A tap on the transparent scaffold outside the panel closes it.
      await tester.tapAt(const Offset(5, 5));
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await route;
      expect(find.text('AI in the demo is pretend'), findsNothing);
    });

    testWidgets('on a wide surface the panel is centered and capped at the '
        'onboarding column width', (tester) async {
      late BuildContext hostContext;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
          mediaQueryData: const MediaQueryData(size: Size(1024, 768)),
        ),
      );

      final route = DemoAiSetupSheet.show(hostContext);
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));

      final constrained = tester.widget<ConstrainedBox>(
        find
            .ancestor(
              of: find.byType(DemoAiSetupFlow),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(constrained.constraints.maxWidth, 480);

      await tester.tapAt(const Offset(5, 5));
      await settleStep(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await route;
    });
  });
}
