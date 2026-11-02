import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_stage_page.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_hero.dart';
import 'package:lotti/features/front_agent/ui/front_profile_choice.dart';
import 'package:lotti/features/front_agent/ui/front_voice_controls.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    VoidCallback? onClose,
    bool companion = false,
    double width = 400,
    FrontChatThread thread = FrontChatThread.empty,
    FrontChatThread Function()? threadOf,
    FrontConversationIndex conversations = FrontConversationIndex.empty,
    TtsPlaybackController Function()? voice,
    bool activeLoading = false,
    AgentDomainEntity? identity,
    List<Override> extra = const [],
  }) async {
    await setUpTestGetIt();
    addTearDown(tearDownTestGetIt);
    // On the fixtures' day: the open conversation is the one that moved
    // today, whenever the suite runs.
    await withClock(Clock.fixed(DateTime(2026, 10, 31, 12)), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                // The header over the hero, as the pane lays them out.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FrontChatHeader(onClose: onClose ?? () {}),
                    const FrontChatHero(),
                  ],
                ),
              ),
            ),
          ),
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flag) =>
                  Stream.value(companion && flag == enableCompanionFlag),
            ),
            // The internals panel resolves the identity; it stays in flight
            // unless the test says she exists.
            agentIdentityProvider.overrideWith(
              (ref, agentId) => identity == null
                  ? Completer<AgentDomainEntity?>().future
                  : Future.value(identity),
            ),
            ...extra,
            agentStateProvider.overrideWith((ref, agentId) async => null),
            frontChatThreadProvider.overrideWith(
              (ref) async => threadOf?.call() ?? thread,
            ),
            // The inbox counts across every conversation.
            frontAllChatsThreadProvider.overrideWith(
              (ref) async => threadOf?.call() ?? thread,
            ),
            frontConversationsProvider.overrideWith(
              (ref) async => conversations,
            ),
            if (voice != null)
              ttsPlaybackControllerProvider.overrideWith(voice),
            if (activeLoading)
              frontActiveConversationProvider.overrideWith(
                (ref) => Completer<String>().future,
              ),
          ],
        ),
      );
      // Her face animates, so no settle: a few frames let the flag and the
      // thread land.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
  }

  group('conversations', () {
    final census = FrontConversationIndex(
      conversations: [
        FrontConversation(
          id: 'c-1',
          title: 'Plan the census',
          lastActivity: DateTime(2026, 10, 31, 9),
          archived: false,
        ),
      ],
    );
    String titleOf(WidgetTester tester) => tester
        .widget<Text>(
          find.byKey(FrontChatHeaderKeys.title).evaluate().isNotEmpty
              ? find.byKey(FrontChatHeaderKeys.title)
              : find.byKey(FrontChatHeroKeys.title),
        )
        .data!;
    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(FrontChatHeader)),
        );

    testWidgets('names the open conversation by its title, whole on hover '
        'however much of it fades', (tester) async {
      await pumpHeader(tester, conversations: census);
      expect(titleOf(tester), 'Plan the census');
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byKey(FrontChatHeroKeys.title),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, 'Plan the census');
    });

    testWidgets('once her hero has scrolled away the header carries her '
        'and the title in a line', (tester) async {
      await pumpHeader(tester, conversations: census);
      expect(find.byKey(FrontChatHeaderKeys.title), findsNothing);

      containerOf(tester).read(frontHeroScrolledProvider.notifier).follow(500);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final compact = find.byKey(FrontChatHeaderKeys.title);
      expect(tester.widget<Text>(compact).data, 'Plan the census');
      final more = tester.getRect(find.byKey(FrontChatHeaderKeys.more));
      expect(tester.getRect(compact).top, lessThan(more.bottom));

      // Back at the top, the line gives way to the hero again.
      containerOf(tester).read(frontHeroScrolledProvider.notifier).follow(0);
      await tester.pump();
      expect(find.byKey(FrontChatHeaderKeys.title), findsNothing);
    });

    testWidgets('names her for a conversation not begun, whose new-chat '
        'action has nothing to start', (tester) async {
      await pumpHeader(tester);
      expect(titleOf(tester), 'Companion');
      expect(
        tester
            .widget<DesignSystemIconAction>(
              find.byKey(FrontChatHeaderKeys.newChat),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('the title opens the list, whose header is back, Chats and '
        'close; back returns to the conversation', (tester) async {
      await pumpHeader(tester, conversations: census);
      final container = containerOf(tester);
      final listOpen = container.listen(
        frontConversationListOpenProvider,
        (_, _) {},
      );
      addTearDown(listOpen.close);

      await tester.tap(find.byKey(FrontChatHeaderKeys.chats));
      await tester.pump();
      expect(listOpen.read(), isTrue);
      expect(titleOf(tester), 'Chats');
      // Nothing that would duplicate the list's own new-chat row.
      expect(find.byKey(FrontChatHeaderKeys.newChat), findsNothing);
      expect(find.byKey(FrontChatHeaderKeys.more), findsNothing);
      expect(find.byKey(FrontChatHeaderKeys.close), findsOneWidget);

      await tester.tap(find.byKey(FrontChatHeaderKeys.back));
      await tester.pump();
      expect(listOpen.read(), isFalse);
      expect(titleOf(tester), 'Plan the census');
    });

    testWidgets('the overflow holds her internals, then the open '
        "conversation's own ways out, the destructive one last", (
      tester,
    ) async {
      await pumpHeader(tester, conversations: census);

      final items = tester
          .widget<DesignSystemContextMenuButton>(
            find.byKey(FrontChatHeaderKeys.more),
          )
          .items
          .map((item) => item.label)
          .toList();

      expect(items, [
        'Agent internals',
        'Rename chat',
        'Archive chat',
        'Delete chat',
      ]);
    });

    testWidgets('a conversation not begun has only her internals in the '
        'overflow', (tester) async {
      await pumpHeader(tester);

      final items = tester
          .widget<DesignSystemContextMenuButton>(
            find.byKey(FrontChatHeaderKeys.more),
          )
          .items;

      expect(items.map((item) => item.label), ['Agent internals']);
    });

    testWidgets('the inbox, which gathers every conversation, is named and '
        "offers no single conversation's actions", (tester) async {
      await pumpHeader(tester, conversations: census);
      final container = containerOf(tester);
      final filter = container.listen(frontInboxFilterProvider, (_, _) {});
      addTearDown(filter.close);

      container.read(frontInboxFilterProvider.notifier).toggle();
      await tester.pump();

      expect(titleOf(tester), 'Inbox');
      expect(
        tester
            .widget<DesignSystemContextMenuButton>(
              find.byKey(FrontChatHeaderKeys.more),
            )
            .items
            .map((item) => item.label),
        ['Agent internals'],
      );
    });

    testWidgets('an archived conversation says so before its title', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        conversations: FrontConversationIndex(
          conversations: [
            FrontConversation(
              id: 'c-0',
              title: 'Ice shelf survey',
              lastActivity: DateTime(2026, 9, 2),
              archived: true,
            ),
          ],
        ),
      );
      containerOf(
        tester,
      ).read(frontPickedConversationProvider.notifier).picked = 'c-0';
      await tester.pump();
      await tester.pump();

      expect(titleOf(tester), 'Ice shelf survey');
      final glyph = tester.getRect(find.byKey(FrontChatHeroKeys.archived));
      final title = tester.getRect(find.byKey(FrontChatHeroKeys.title));
      expect(glyph.right, lessThanOrEqualTo(title.left));
    });

    testWidgets('a new chat starts an empty conversation', (tester) async {
      await pumpHeader(tester, conversations: census);
      final container = containerOf(tester);

      await tester.tap(find.byKey(FrontChatHeaderKeys.newChat));
      await tester.pump();
      await tester.pump();

      final picked = container.read(frontPickedConversationProvider);
      expect(picked, isNot(anyOf(isNull, 'c-1')));
      expect(titleOf(tester), 'Companion');
    });
  });

  testWidgets('a row of controls — the ways to another conversation lead, '
      "this conversation's overflow and close trail — over her and the "
      'title, centred', (tester) async {
    var closed = 0;
    await pumpHeader(tester, onClose: () => closed++);

    Rect at(Key key) => tester.getRect(find.byKey(key));
    final order = [
      FrontChatHeaderKeys.chats,
      FrontChatHeaderKeys.newChat,
      FrontChatHeaderKeys.more,
      FrontChatHeaderKeys.close,
    ].map(at).toList();
    for (var i = 1; i < order.length; i++) {
      expect(order[i].left, greaterThanOrEqualTo(order[i - 1].right));
      expect(order[i].top, lessThan(order[0].bottom));
    }
    final figure = at(FrontChatHeroKeys.figure);
    final title = at(FrontChatHeroKeys.title);
    expect(figure.top, greaterThanOrEqualTo(order[0].bottom));
    expect(title.top, greaterThanOrEqualTo(figure.bottom));
    expect(title.center.dx, closeTo(figure.center.dx, 1));

    await tester.tap(find.byKey(FrontChatHeaderKeys.close));
    expect(closed, 1);
  });

  group('her AI profile', () {
    final her = makeTestIdentity(
      id: frontAgentId,
      agentId: frontAgentId,
      kind: AgentKinds.frontAgent,
    );

    List<String> overflow(WidgetTester tester) => tester
        .widget<DesignSystemContextMenuButton>(
          find.byKey(FrontChatHeaderKeys.more),
        )
        .items
        .map((item) => item.label)
        .toList();

    final catalog = agentSetupOptionsProvider.overrideWith(
      (ref) async => TaskAgentSetupOptions(
        profiles: [testInferenceProfile(id: 'p', name: 'Mistral (EU)')],
        models: const [],
        providers: const [],
      ),
    );

    testWidgets('leads the overflow once she exists and the profiles are '
        'loaded', (tester) async {
      await pumpHeader(tester, identity: her, extra: [catalog]);

      expect(overflow(tester), ['AI profile', 'Agent internals']);
    });

    testWidgets('waits for the profiles: offered before they load, it would '
        'open an empty picker', (tester) async {
      await pumpHeader(
        tester,
        identity: her,
        extra: [
          agentSetupOptionsProvider.overrideWith(
            (ref) => Completer<TaskAgentSetupOptions>().future,
          ),
        ],
      );

      expect(overflow(tester), ['Agent internals']);
    });

    testWidgets('is not offered before she exists: nothing to write it on', (
      tester,
    ) async {
      await pumpHeader(tester);

      expect(overflow(tester), isNot(contains('AI profile')));
    });

    testWidgets('opens the profile picker, marking the Settings default '
        'she follows', (tester) async {
      final aiConfigs = MockAiConfigRepository();
      when(
        aiConfigs.getDefaultProfileId,
      ).thenAnswer((_) async => 'profile-mistral');
      await pumpHeader(
        tester,
        identity: her,
        extra: [
          aiConfigRepositoryProvider.overrideWithValue(aiConfigs),
          agentSetupOptionsProvider.overrideWith(
            (ref) async => TaskAgentSetupOptions(
              profiles: [
                testInferenceProfile(
                  id: 'profile-mistral',
                  name: 'Mistral (EU)',
                ),
              ],
              models: const [],
              providers: const [],
            ),
          ),
        ],
      );

      await tester.tap(find.byKey(FrontChatHeaderKeys.more));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FrontChatHeaderKeys.profile));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Choose an inference profile'), findsOneWidget);
      bool selected(Key key) =>
          tester.widget<DesignSystemSelectionRow>(find.byKey(key)).selected;
      expect(selected(FrontProfileChoiceKeys.useDefault), isTrue);
      expect(selected(const ValueKey('profile-mistral')), isFalse);
    });
  });

  testWidgets('her AI profile opens the picker though the profile catalog '
      'changed while it loaded: a one-off read of it never settled, and '
      'the tap did nothing', (tester) async {
    final her = makeTestIdentity(
      id: frontAgentId,
      agentId: frontAgentId,
      kind: AgentKinds.frontAgent,
    );
    final aiConfigs = MockAiConfigRepository();
    when(aiConfigs.getDefaultProfileId).thenAnswer((_) async => null);
    final profiles = StreamController<List<AiConfig>>();
    addTearDown(profiles.close);
    // The catalog emits twice as it loads, as a sync or a seed makes it.
    profiles
      ..add([testInferenceProfile(id: 'a', name: 'First')])
      ..add([testInferenceProfile(id: 'a', name: 'Mistral (EU)')]);
    await pumpHeader(
      tester,
      identity: her,
      extra: [
        aiConfigRepositoryProvider.overrideWithValue(aiConfigs),
        aiConfigsByTypeProvider.overrideWith(
          (ref, type) => type == AiConfigType.inferenceProfile
              ? profiles.stream
              : Stream.value(const <AiConfig>[]),
        ),
      ],
    );

    await tester.tap(find.byKey(FrontChatHeaderKeys.more));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FrontChatHeaderKeys.profile));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Mistral (EU)'), findsOneWidget);
    expect(find.text('Choose an inference profile'), findsOneWidget);
  });

  testWidgets('her internals open from the overflow', (tester) async {
    await pumpHeader(tester);

    await tester.tap(find.byKey(FrontChatHeaderKeys.more));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FrontChatHeaderKeys.internals));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final panel = tester.widget<AgentInternalsPanel>(
      find.byType(AgentInternalsPanel),
    );
    expect(panel.agentId, frontAgentId);
    expect(panel.agentName, 'Companion');
  });

  testWidgets('with the companion off the spark every agent wears stands '
      'in for her', (tester) async {
    await pumpHeader(tester);
    expect(find.byType(CompanionView), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(FrontChatHeroKeys.figure),
        matching: find.byIcon(LottiIcons.aiSpark),
      ),
      findsOneWidget,
    );
  });

  testWidgets('wears her face when the companion is on', (tester) async {
    await pumpHeader(tester, companion: true);
    expect(
      find.descendant(
        of: find.byKey(FrontChatHeroKeys.figure),
        matching: find.byType(CompanionView),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(LottiIcons.aiSpark), findsNothing);
  });

  group('her voice', () {
    final census = FrontConversationIndex(
      conversations: [
        FrontConversation(
          id: 'c-1',
          title: 'Plan the census',
          lastActivity: DateTime(2026, 10, 31, 9),
          archived: false,
        ),
      ],
    );

    testWidgets('her lips follow her voice in the open conversation', (
      tester,
    ) async {
      await pumpHeader(tester, companion: true, conversations: census);

      final speaker = tester.widget<CompanionSpeaker>(
        find.descendant(
          of: find.byKey(FrontChatHeroKeys.figure),
          matching: find.byType(CompanionSpeaker),
        ),
      );
      expect(speaker.sourceId, 'front-chat:c-1');
    });

    testWidgets('she stays the same figure as she starts and stops '
        'speaking — her animator lives through it — and a tap on her '
        'stands her up full screen, still speaking', (tester) async {
      final voice = _Voice(const TtsPlaybackState());
      await pumpHeader(
        tester,
        companion: true,
        conversations: census,
        voice: () => voice,
      );
      Element figure() => tester.element(
        find.descendant(
          of: find.byKey(FrontChatHeroKeys.figure),
          matching: find.byType(CompanionSpeaker),
        ),
      );
      final before = figure();

      voice.play('front-chat:c-1');
      await tester.pump();
      expect(figure(), same(before));

      await tester.tap(find.byKey(FrontChatHeroKeys.openStage));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final stage = tester.widget<CompanionStagePage>(
        find.byType(CompanionStagePage),
      );
      expect(stage.sourceId, 'front-chat:c-1');
      // Her own voice control at her feet, not the summary's.
      expect(
        (stage.readAloud! as FrontVoiceButton).conversationId,
        'c-1',
      );
      expect(voice.stoppedSources, isEmpty, reason: 'she speaks on');
    });

    testWidgets('before any conversation resolves she simply stands', (
      tester,
    ) async {
      await pumpHeader(tester, companion: true, activeLoading: true);

      expect(
        find.descendant(
          of: find.byKey(FrontChatHeroKeys.figure),
          matching: find.byType(CompanionView),
        ),
        findsOne,
      );
      expect(find.byType(CompanionSpeaker), findsNothing);
    });

    testWidgets('her voice and her stage stand under her, for the open '
        'conversation, only while the companion is on', (tester) async {
      await pumpHeader(tester, companion: true, conversations: census);

      expect(
        tester
            .widget<FrontVoiceButton>(find.byType(FrontVoiceButton))
            .conversationId,
        'c-1',
      );
      expect(
        tester
            .widget<FrontStageButton>(find.byType(FrontStageButton))
            .conversationId,
        'c-1',
      );
    });

    testWidgets('with the companion off she has neither', (tester) async {
      await pumpHeader(tester, conversations: census);
      expect(find.byType(FrontVoiceButton), findsNothing);
      expect(find.byType(FrontStageButton), findsNothing);
    });
  });

  group('the inbox dot', () {
    FrontChatThread waiting(int count) => FrontChatThread(
      messages: const [],
      doorsByMessageId: {
        'u1': [
          for (var i = 0; i < count; i++)
            FrontDoorEntry(
              doorId: 'd:door:$i',
              record: FrontDoorRecord(
                segmentIndex: i,
                text: 'segment $i',
                kind: FrontDestinationKind.unrouted,
                status: FrontDoorStatus.done,
                claimedAt: DateTime.utc(2026, 10, 26),
                outcome: const FrontDoorInbox(),
              ),
            ),
        ],
      },
    );

    testWidgets('is absent while nothing waits on the user', (tester) async {
      await pumpHeader(tester);
      expect(find.byKey(FrontChatHeaderKeys.inbox), findsNothing);
    });

    testWidgets('its count on the way to the list says what waits', (
      tester,
    ) async {
      await pumpHeader(tester, thread: waiting(2));

      // After the word, never over it, on its line.
      final dot = tester.getRect(find.byKey(FrontChatHeaderKeys.inbox));
      final list = tester.getRect(find.byKey(FrontChatHeaderKeys.chats));
      expect(dot.left, greaterThanOrEqualTo(list.right));
      expect(dot.center.dy, closeTo(list.center.dy, 1));
      expect(
        find.descendant(
          of: find.byKey(FrontChatHeaderKeys.chats),
          matching: find.text('Chats'),
        ),
        findsOne,
      );
      expect(
        tester
            .widget<DesignSystemBadge>(find.byKey(FrontChatHeaderKeys.inbox))
            .semanticLabel,
        'Inbox 2',
      );
      // The count itself, as the list's Inbox row shows it.
      expect(
        find.descendant(
          of: find.byKey(FrontChatHeaderKeys.inbox),
          matching: find.text('2'),
        ),
        findsOne,
      );
    });
    testWidgets('a tap on the count opens the list too', (tester) async {
      await pumpHeader(tester, thread: waiting(2));
      final listOpen =
          ProviderScope.containerOf(
            tester.element(find.byType(FrontChatHeader)),
          ).listen(
            frontConversationListOpenProvider,
            (_, _) {},
          );
      addTearDown(listOpen.close);

      await tester.tap(find.byKey(FrontChatHeaderKeys.inbox));
      await tester.pump();
      expect(listOpen.read(), isTrue);
    });
  });

  group('the hero', () {
    final census = FrontConversationIndex(
      conversations: [
        FrontConversation(
          id: 'c-1',
          title: 'Plan the census',
          lastActivity: DateTime(2026, 10, 31, 9),
          archived: false,
        ),
      ],
    );
    FrontChatThread asked(String question) => FrontChatThread(
      messages: [
        AgentChatMessage(
          id: 'u1',
          role: AgentChatRole.user,
          text: question,
          createdAt: DateTime(2026, 10, 31, 9),
        ),
      ],
    );

    testWidgets('a title that only repeats the first question is left out: '
        'she leads alone', (tester) async {
      await pumpHeader(
        tester,
        conversations: census,
        thread: asked('Plan the census\nand the nests'),
      );

      expect(find.byKey(FrontChatHeroKeys.title), findsNothing);
      expect(find.byKey(FrontChatHeroKeys.figure), findsOne);
    });

    testWidgets('a title of its own shows, a step above the thread', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        conversations: census,
        thread: asked('How many hatchlings?'),
      );

      final title = tester.widget<Text>(find.byKey(FrontChatHeroKeys.title));
      expect(title.data, 'Plan the census');
      expect(
        title.style?.fontSize,
        tester
            .element(find.byKey(FrontChatHeroKeys.title))
            .designTokens
            .typography
            .styles
            .heading
            .heading3
            .fontSize,
      );
    });
  });
}

/// The voice, playing or not, recording what it was asked to stop.
class _Voice extends TtsPlaybackController {
  _Voice(this._initial);

  final TtsPlaybackState _initial;
  final stoppedSources = <String?>[];

  @override
  TtsPlaybackState build() => _initial;

  @override
  Future<void> stop({String? sourceId}) async {
    stoppedSources.add(sourceId);
    state = const TtsPlaybackState();
  }

  /// Starts speaking [sourceId].
  void play(String sourceId) => state = TtsPlaybackState(
    status: TtsPlaybackStatus.playing,
    sourceId: sourceId,
  );
}
