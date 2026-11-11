import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';
import 'package:lotti/features/front_agent/ui/front_chat_drawer.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_list.dart';
import 'package:lotti/features/front_agent/ui/front_profile_choice.dart';
import 'package:lotti/features/front_agent/ui/front_voice_switch.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../ai_consumption/test_utils.dart';

/// Her saved customization, already known: the switch that mutes her shows.
class _KnownCustom extends CompanionCustomizationController {
  @override
  bool get loaded => true;

  @override
  CompanionCustomization build() => const CompanionCustomization();
}

/// The inbox view, on.
class _InboxOn extends FrontInboxFilter {
  @override
  bool build() => true;
}

void main() {
  final now = DateTime(2026, 11, 11, 10);
  final her = makeTestIdentity(
    id: frontAgentId,
    agentId: frontAgentId,
    kind: AgentKinds.frontAgent,
  );
  final colony = FrontConversationIndex(
    conversations: [
      FrontConversation(
        id: 'c-1',
        title: 'Plan the census',
        lastActivity: now,
        archived: false,
      ),
      FrontConversation(
        id: 'c-2',
        title: 'Count the hatchlings',
        lastActivity: now.subtract(const Duration(hours: 1)),
        archived: false,
      ),
    ],
  );

  /// Pumps the drawer with `c-1` open.
  Future<ProviderContainer> pumpDrawer(
    WidgetTester tester, {
    bool beside = false,
    bool companion = false,
    FrontConversationIndex? index,
    String? active,
    AgentDomainEntity? identity,
    FrontChatThread thread = FrontChatThread.empty,
    ConsumptionTotals Function(String runKey)? runTotals,
    List<Override> extra = const [],
    EdgeInsets keyboard = EdgeInsets.zero,
  }) async {
    await setUpTestGetIt();
    addTearDown(tearDownTestGetIt);
    return withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(viewInsets: keyboard),
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                body: SizedBox(
                  width: 360,
                  child: FrontChatDrawer(beside: beside),
                ),
              ),
            ),
          ),
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flag) =>
                  Stream.value(companion && flag == enableCompanionFlag),
            ),
            companionCustomizationProvider.overrideWith(_KnownCustom.new),
            agentIdentityProvider.overrideWith(
              (ref, agentId) => identity == null
                  ? Completer<AgentDomainEntity?>().future
                  : Future.value(identity),
            ),
            agentStateProvider.overrideWith((ref, agentId) async => null),
            frontConversationsProvider.overrideWith(
              (ref) async => index ?? colony,
            ),
            frontActiveConversationProvider.overrideWith(
              (ref) async => active ?? 'c-1',
            ),
            frontMentionCategoriesProvider.overrideWithValue(const []),
            frontChatThreadProvider.overrideWith((ref) async => thread),
            frontAllChatsThreadProvider.overrideWith(
              (ref) async => FrontChatThread.empty,
            ),
            agentRunConsumptionTotalsProvider.overrideWith(
              (ref, run) => Stream.value(
                runTotals?.call(run.runKey) ?? ConsumptionTotals.empty,
              ),
            ),
            ...extra,
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      return ProviderScope.containerOf(
        tester.element(find.byType(FrontChatDrawer)),
      );
    });
  }

  ProviderSubscription<bool> keepOpen(ProviderContainer container) {
    final sub = container.listen(frontConversationListOpenProvider, (_, _) {});
    addTearDown(sub.close);
    container.read(frontConversationListOpenProvider.notifier).toggle();
    return sub;
  }

  group('the top row', () {
    testWidgets('holds the search and, over a phone, the way back to the '
        'conversation', (tester) async {
      final container = await pumpDrawer(tester);
      final open = keepOpen(container);
      await tester.pump();

      final search = tester.getRect(find.byKey(FrontChatDrawerKeys.search));
      final close = tester.getRect(find.byKey(FrontChatDrawerKeys.close));
      expect(search.center.dy, closeTo(close.center.dy, 1));
      expect(search.right, lessThanOrEqualTo(close.left));
      expect(find.text('Search chats'), findsOne);

      await tester.tap(find.byKey(FrontChatDrawerKeys.close));
      await tester.pump();
      expect(open.read(), isFalse);
    });

    testWidgets('beside the conversation it is the search alone', (
      tester,
    ) async {
      await pumpDrawer(tester, beside: true);

      expect(find.byKey(FrontChatDrawerKeys.search), findsOne);
      expect(find.byKey(FrontChatDrawerKeys.close), findsNothing);
      expect(
        tester
            .widget<FrontConversationList>(find.byType(FrontConversationList))
            .beside,
        isTrue,
      );
    });

    testWidgets('what is typed in the search narrows the list, and clearing '
        'it brings the list back', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pumpDrawer(tester);

        await tester.enterText(find.byType(TextField), 'hatch');
        await tester.pump();
        expect(
          tester
              .widget<FrontConversationList>(find.byType(FrontConversationList))
              .query,
          'hatch',
        );
        expect(find.text('Plan the census'), findsNothing);
        expect(find.text('Count the hatchlings'), findsOne);

        await tester.tap(find.byIcon(LottiIcons.closeCircled));
        await tester.pump();
        expect(
          tester
              .widget<FrontConversationList>(find.byType(FrontConversationList))
              .query,
          isEmpty,
        );
        expect(find.text('Plan the census'), findsOne);
      });
    });
  });

  group('a new chat', () {
    DesignSystemListItem newChat(WidgetTester tester) =>
        tester.widget(find.byKey(FrontChatDrawerKeys.newChat));

    testWidgets('starts an empty conversation and closes the drawer', (
      tester,
    ) async {
      final container = await pumpDrawer(tester);
      final open = keepOpen(container);
      await tester.pump();

      await tester.tap(find.byKey(FrontChatDrawerKeys.newChat));
      await tester.pump();

      expect(open.read(), isFalse);
      expect(
        container.read(frontPickedConversationProvider),
        isNot(anyOf(isNull, 'c-1', 'c-2')),
      );
    });

    testWidgets('has nothing to start in a conversation not begun', (
      tester,
    ) async {
      await pumpDrawer(tester, active: 'c-new');
      expect(newChat(tester).onTap, isNull);
    });

    testWidgets('from the inbox it leaves the inbox, begun or not', (
      tester,
    ) async {
      await pumpDrawer(
        tester,
        active: 'c-new',
        extra: [frontInboxFilterProvider.overrideWith(_InboxOn.new)],
      );
      expect(newChat(tester).onTap, isNotNull);
    });
  });

  group('the footer', () {
    testWidgets('holds her voice for the open conversation while the '
        'companion is on', (tester) async {
      await pumpDrawer(tester, companion: true);

      expect(
        tester
            .widget<FrontVoiceSwitch>(find.byType(FrontVoiceSwitch))
            .conversationId,
        'c-1',
      );
      expect(find.byKey(FrontVoiceSwitchKeys.row), findsOne);
    });

    testWidgets('in the inbox her voice has no one conversation to say '
        'again', (tester) async {
      await pumpDrawer(
        tester,
        companion: true,
        extra: [frontInboxFilterProvider.overrideWith(_InboxOn.new)],
      );

      expect(
        tester
            .widget<FrontVoiceSwitch>(find.byType(FrontVoiceSwitch))
            .conversationId,
        isNull,
      );
    });

    testWidgets('her voice, her profile and her internals, in that order, at '
        'the foot', (tester) async {
      await pumpDrawer(
        tester,
        companion: true,
        identity: her,
        extra: [
          agentSetupOptionsProvider.overrideWith(
            (ref) async => TaskAgentSetupOptions(
              profiles: [testInferenceProfile(id: 'p', name: 'Mistral (EU)')],
              models: const [],
              providers: const [],
            ),
          ),
        ],
      );

      final voice = tester.getRect(find.byKey(FrontVoiceSwitchKeys.row));
      final profile = tester.getRect(find.byKey(FrontChatDrawerKeys.profile));
      final internals = tester.getRect(
        find.byKey(FrontChatDrawerKeys.internals),
      );
      expect(voice.bottom, lessThanOrEqualTo(profile.top));
      expect(profile.bottom, lessThanOrEqualTo(internals.top));
      // Below the list.
      expect(
        tester.getRect(find.byType(FrontConversationList)).bottom,
        lessThanOrEqualTo(voice.top),
      );
    });

    testWidgets('steps aside while the keyboard is up, so the search keeps '
        'room for what it finds', (tester) async {
      await pumpDrawer(
        tester,
        keyboard: const EdgeInsets.only(bottom: 300),
      );

      expect(find.byType(FrontChatDrawerFooter), findsNothing);
      expect(find.byKey(FrontChatDrawerKeys.internals), findsNothing);
      expect(find.byType(FrontConversationList), findsOne);
    });

    group('her AI profile', () {
      final catalog = agentSetupOptionsProvider.overrideWith(
        (ref) async => TaskAgentSetupOptions(
          profiles: [
            testInferenceProfile(id: 'p-own', name: 'Mistral (EU)'),
            testInferenceProfile(id: 'p-default', name: 'Gemini Flash'),
          ],
          models: const [],
          providers: const [],
        ),
      );
      MockAiConfigRepository defaultIs(String? id) {
        final aiConfigs = MockAiConfigRepository();
        when(aiConfigs.getDefaultProfileId).thenAnswer((_) async => id);
        return aiConfigs;
      }

      String? valueOf(WidgetTester tester) {
        final texts = tester.widgetList<Text>(
          find.descendant(
            of: find.byKey(FrontChatDrawerKeys.profile),
            matching: find.byType(Text),
          ),
        );
        return texts
            .map((text) => text.data)
            .where((data) => data != 'AI profile')
            .firstOrNull;
      }

      testWidgets('names the profile she has chosen of her own', (
        tester,
      ) async {
        await pumpDrawer(
          tester,
          identity: makeTestIdentity(
            id: frontAgentId,
            agentId: frontAgentId,
            kind: AgentKinds.frontAgent,
            config: const AgentConfig(profileId: 'p-own'),
          ),
          extra: [
            catalog,
            aiConfigRepositoryProvider.overrideWithValue(
              defaultIs('p-default'),
            ),
          ],
        );
        expect(valueOf(tester), 'Mistral (EU)');
      });

      testWidgets('with none of her own, names the Settings default she '
          'follows', (tester) async {
        await pumpDrawer(
          tester,
          identity: her,
          extra: [
            catalog,
            aiConfigRepositoryProvider.overrideWithValue(
              defaultIs('p-default'),
            ),
          ],
        );
        expect(valueOf(tester), 'Gemini Flash');
      });

      testWidgets('names nothing when neither is known', (tester) async {
        await pumpDrawer(
          tester,
          identity: her,
          extra: [
            catalog,
            aiConfigRepositoryProvider.overrideWithValue(defaultIs(null)),
          ],
        );
        expect(find.byKey(FrontChatDrawerKeys.profile), findsOne);
        expect(valueOf(tester), isNull);
      });

      testWidgets('waits for the profiles: offered before they load, it would '
          'open an empty picker', (tester) async {
        await pumpDrawer(
          tester,
          identity: her,
          extra: [
            agentSetupOptionsProvider.overrideWith(
              (ref) => Completer<TaskAgentSetupOptions>().future,
            ),
          ],
        );
        expect(find.byKey(FrontChatDrawerKeys.profile), findsNothing);
      });

      testWidgets('is not offered before she exists: nothing to write it on', (
        tester,
      ) async {
        await pumpDrawer(tester, extra: [catalog]);
        expect(find.byKey(FrontChatDrawerKeys.profile), findsNothing);
      });

      testWidgets('opens the profile picker, marking the Settings default '
          'she follows', (tester) async {
        await pumpDrawer(
          tester,
          identity: her,
          extra: [
            catalog,
            aiConfigRepositoryProvider.overrideWithValue(
              defaultIs('p-default'),
            ),
          ],
        );

        await tester.tap(find.byKey(FrontChatDrawerKeys.profile));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text('Choose an inference profile'), findsOneWidget);
        bool selected(Key key) =>
            tester.widget<DesignSystemSelectionRow>(find.byKey(key)).selected;
        expect(selected(FrontProfileChoiceKeys.useDefault), isTrue);
        expect(selected(const ValueKey('p-own')), isFalse);
      });

      testWidgets('opens the picker though the profile catalog changed while '
          'it loaded: a one-off read of it never settled', (tester) async {
        final profiles = StreamController<List<AiConfig>>();
        addTearDown(profiles.close);
        // The catalog emits twice as it loads, as a sync or a seed makes it.
        profiles
          ..add([testInferenceProfile(id: 'a', name: 'First')])
          ..add([testInferenceProfile(id: 'a', name: 'Mistral (EU)')]);
        await pumpDrawer(
          tester,
          identity: her,
          extra: [
            aiConfigRepositoryProvider.overrideWithValue(defaultIs(null)),
            aiConfigsByTypeProvider.overrideWith(
              (ref, type) => type == AiConfigType.inferenceProfile
                  ? profiles.stream
                  : Stream.value(const <AiConfig>[]),
            ),
          ],
        );

        await tester.tap(find.byKey(FrontChatDrawerKeys.profile));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text('Choose an inference profile'), findsOneWidget);
        expect(find.text('Mistral (EU)'), findsWidgets);
      });
    });

    group('her internals', () {
      final answered = FrontChatThread(
        messages: [
          AgentChatMessage(
            id: 'u1',
            role: AgentChatRole.user,
            text: 'How many chicks?',
            createdAt: now,
          ),
          AgentChatMessage(
            id: 'a1',
            role: AgentChatRole.agent,
            text: 'Twelve.',
            createdAt: now,
            runKey: 'run-1',
          ),
        ],
        runKeys: const {'run-1'},
      );

      testWidgets('say what the open conversation has cost', (tester) async {
        await pumpDrawer(
          tester,
          thread: answered,
          runTotals: (_) =>
              makeConsumptionTotals(callCount: 2, totalTokens: 36800),
        );
        await tester.pump();

        expect(
          find.descendant(
            of: find.byKey(FrontChatDrawerKeys.internals),
            matching: find.text('36.8K tokens'),
          ),
          findsOne,
        );
      });

      testWidgets('say no cost for a conversation that has cost nothing', (
        tester,
      ) async {
        await pumpDrawer(tester, thread: answered);
        await tester.pump();
        expect(find.byKey(FrontChatDrawerKeys.internals), findsOne);
        expect(find.textContaining('tokens'), findsNothing);
      });

      testWidgets('say no cost in the inbox, which is no one conversation', (
        tester,
      ) async {
        await pumpDrawer(
          tester,
          thread: answered,
          runTotals: (_) =>
              makeConsumptionTotals(callCount: 2, totalTokens: 900),
          extra: [frontInboxFilterProvider.overrideWith(_InboxOn.new)],
        );
        await tester.pump();
        expect(find.byKey(FrontChatDrawerKeys.internals), findsOne);
        expect(find.textContaining('tokens'), findsNothing);
      });

      testWidgets('open her internals panel', (tester) async {
        await pumpDrawer(tester);

        await tester.tap(find.byKey(FrontChatDrawerKeys.internals));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        final panel = tester.widget<AgentInternalsPanel>(
          find.byType(AgentInternalsPanel),
        );
        expect(panel.agentId, frontAgentId);
        expect(panel.agentName, 'Companion');
      });
    });
  });
}
