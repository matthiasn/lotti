import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/ui/front_profile_choice.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../../agents/test_data/entity_factories.dart';

AgentConfig _chose(String profileId) => AgentConfig(
  profileId: profileId,
  inferenceSetup: AgentInferenceSetup(
    mode: AgentInferenceSetupMode.configured,
    origin: AgentInferenceSetupOrigin.user,
    baseProfileId: profileId,
  ),
);

/// Opens the choice for [identity] from a button, watching what her header
/// watches and handing over the catalog and the default it has loaded.
class _Host extends ConsumerWidget {
  const _Host(this.identity);

  final AgentIdentityEntity identity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..watch(agentIdentityProvider(frontAgentId))
      ..watch(agentResolvedSetupProvider(frontAgentId));
    final profiles = ref.watch(agentSetupOptionsProvider).value?.profiles;
    final defaultProfileId = ref
        .watch(defaultInferenceProfileControllerProvider)
        .value;
    return TextButton(
      onPressed: profiles == null
          ? null
          : () => FrontProfileChoice.choose(
              context,
              ref,
              identity,
              profiles: profiles,
              defaultProfileId: defaultProfileId,
            ).ignore(),
      child: const Text('choose'),
    );
  }
}

void main() {
  setUpAll(registerAllFallbackValues);

  group('ownProfileId', () {
    test('her own choice', () {
      expect(FrontProfileChoice.ownProfileId(_chose('mine')), 'mine');
    });

    test('a bare profile id, from before setups, counts as hers', () {
      expect(
        FrontProfileChoice.ownProfileId(const AgentConfig(profileId: 'legacy')),
        'legacy',
      );
    });

    test('without a choice there is none: the Settings default is not '
        'hers', () {
      expect(FrontProfileChoice.ownProfileId(const AgentConfig()), isNull);
    });
  });

  group('choose', () {
    late MockFrontAgentService service;
    late MockAiConfigRepository aiConfigs;
    late MockDomainLogger logger;

    final mistral = testInferenceProfile(
      id: 'profile-mistral',
      name: 'Mistral (EU)',
    );
    final melious = testInferenceProfile(
      id: 'profile-melious',
      name: 'Melious.ai',
    );
    final identity = makeTestIdentity(
      id: frontAgentId,
      agentId: frontAgentId,
      kind: AgentKinds.frontAgent,
    );

    setUp(() async {
      await setUpTestGetIt();
      service = MockFrontAgentService();
      aiConfigs = MockAiConfigRepository();
      logger = MockDomainLogger();
      when(() => service.chooseProfile(any())).thenAnswer((_) async => true);
      when(
        () => aiConfigs.getDefaultProfileId(),
      ).thenAnswer((_) async => 'profile-melious');
    });
    tearDown(tearDownTestGetIt);

    Future<void> pumpAndOpen(
      WidgetTester tester, {
      AgentIdentityEntity? who,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          _Host(who ?? identity),
          overrides: [
            frontAgentServiceProvider.overrideWithValue(service),
            aiConfigRepositoryProvider.overrideWithValue(aiConfigs),
            domainLoggerProvider.overrideWithValue(logger),
            agentSetupOptionsProvider.overrideWith(
              (ref) async => TaskAgentSetupOptions(
                profiles: [melious, mistral],
                models: const [],
                providers: const [],
              ),
            ),
            agentIdentityProvider.overrideWith(
              (ref, agentId) async => who ?? identity,
            ),
            agentResolvedSetupProvider.overrideWith((ref, agentId) async {
              return const ResolvedAgentSetup(
                status: AgentSetupResolutionStatus.broken,
              );
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('choose'));
      await tester.pumpAndSettle();
    }

    bool selected(WidgetTester tester, Key key) =>
        tester.widget<DesignSystemSelectionRow>(find.byKey(key)).selected;

    testWidgets('leads with the Settings default, named and marked while '
        'she has no profile of her own, then every profile', (tester) async {
      await pumpAndOpen(tester);

      expect(find.text('Choose an inference profile'), findsOneWidget);
      expect(find.text('Settings default'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(FrontProfileChoiceKeys.useDefault),
          matching: find.text('Melious.ai'),
        ),
        findsOneWidget,
      );
      expect(find.text('Mistral (EU)'), findsOneWidget);
      expect(selected(tester, FrontProfileChoiceKeys.useDefault), isTrue);
      expect(selected(tester, const ValueKey('profile-melious')), isFalse);
      expect(selected(tester, const ValueKey('profile-mistral')), isFalse);
      expect(
        tester.getTopLeft(find.byKey(FrontProfileChoiceKeys.useDefault)).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('profile-melious'))).dy,
        ),
      );
    });

    testWidgets('marks her own choice, not the default', (tester) async {
      await pumpAndOpen(
        tester,
        who: identity.copyWith(config: _chose('profile-mistral')),
      );

      expect(selected(tester, const ValueKey('profile-mistral')), isTrue);
      expect(selected(tester, FrontProfileChoiceKeys.useDefault), isFalse);
    });

    testWidgets('a pick is saved as hers and confirmed by name', (
      tester,
    ) async {
      await pumpAndOpen(tester);

      await tester.tap(find.text('Mistral (EU)'));
      await tester.pumpAndSettle();

      verify(() => service.chooseProfile('profile-mistral')).called(1);
      expect(
        find.text('The companion now uses Mistral (EU)'),
        findsOneWidget,
      );
    });

    testWidgets('the Settings default clears her own choice and says so', (
      tester,
    ) async {
      await pumpAndOpen(
        tester,
        who: identity.copyWith(config: _chose('profile-mistral')),
      );

      await tester.tap(find.byKey(FrontProfileChoiceKeys.useDefault));
      await tester.pumpAndSettle();

      verify(() => service.chooseProfile(null)).called(1);
      expect(
        find.text('The companion now follows the Settings default'),
        findsOneWidget,
      );
    });

    testWidgets('the Settings default, while she already follows it, is '
        'left to the service, which writes nothing then', (tester) async {
      await pumpAndOpen(tester);

      await tester.tap(find.byKey(FrontProfileChoiceKeys.useDefault));
      await tester.pumpAndSettle();

      verify(() => service.chooseProfile(null)).called(1);
    });

    testWidgets('a chosen profile that is gone marks the default she falls '
        'back to, and choosing it clears the stale choice', (tester) async {
      await pumpAndOpen(
        tester,
        who: identity.copyWith(config: _chose('profile-deleted')),
      );

      expect(selected(tester, FrontProfileChoiceKeys.useDefault), isTrue);

      await tester.tap(find.byKey(FrontProfileChoiceKeys.useDefault));
      await tester.pumpAndSettle();

      verify(() => service.chooseProfile(null)).called(1);
    });

    testWidgets('dismissing the picker changes nothing', (tester) async {
      await pumpAndOpen(tester);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      verifyNever(() => service.chooseProfile(any()));
      expect(find.textContaining('now uses'), findsNothing);
    });

    testWidgets('picking the profile whose id alone she keeps asks the '
        'service, which repairs a disabled setup', (tester) async {
      await pumpAndOpen(
        tester,
        who: identity.copyWith(
          config: const AgentConfig(
            profileId: 'profile-mistral',
            inferenceSetup: AgentInferenceSetup(
              mode: AgentInferenceSetupMode.disabled,
              origin: AgentInferenceSetupOrigin.user,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mistral (EU)'));
      await tester.pumpAndSettle();

      verify(() => service.chooseProfile('profile-mistral')).called(1);
    });

    testWidgets('a save that finds no companion is logged and shows an '
        'error', (tester) async {
      when(
        () => service.chooseProfile(any()),
      ).thenAnswer((_) async => false);
      await pumpAndOpen(tester);

      await tester.tap(find.text('Mistral (EU)'));
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('now uses'), findsNothing);
      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          any(that: isA<StateError>()),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'FrontProfileChoice',
          message: 'Choosing her profile failed',
        ),
      ).called(1);
    });

    testWidgets('a save that throws is logged and shows an error', (
      tester,
    ) async {
      when(
        () => service.chooseProfile(any()),
      ).thenThrow(Exception('disk full'));
      await pumpAndOpen(tester);

      await tester.tap(find.text('Mistral (EU)'));
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsOneWidget);
      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          any(that: isA<Exception>()),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'FrontProfileChoice',
          message: 'Choosing her profile failed',
        ),
      ).called(1);
    });

    testWidgets('her surface closing while the choice saves still saves it, '
        'and says nothing', (tester) async {
      final saving = Completer<bool>();
      when(
        () => service.chooseProfile(any()),
      ).thenAnswer((_) => saving.future);
      await pumpAndOpen(tester);
      await tester.tap(find.text('Mistral (EU)'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      saving.complete(true);
      await tester.pumpAndSettle();

      verify(() => service.chooseProfile('profile-mistral')).called(1);
      expect(find.textContaining('now uses'), findsNothing);
      verifyNever(
        () => logger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
          message: any(named: 'message'),
        ),
      );
    });
  });
}
