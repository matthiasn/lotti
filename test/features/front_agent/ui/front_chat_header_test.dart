import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_stage_page.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_actions.dart';
import 'package:lotti/features/front_agent/ui/front_voice_controls.dart';
import 'package:lotti/features/front_agent/ui/front_voice_switch.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_utils/screenshot_harness.dart';
import '../../../widget_test_utils.dart';

void main() {
  // The title's room on a phone is asserted in real glyphs: the test font
  // draws every one an em wide.
  setUpAll(loadAppFonts);

  Future<void> pumpHeader(
    WidgetTester tester, {
    VoidCallback? onClose,
    bool companion = false,
    bool listBeside = false,
    double width = 400,
    FrontChatThread thread = FrontChatThread.empty,
    FrontChatThread Function()? threadOf,
    FrontConversationIndex conversations = FrontConversationIndex.empty,
    TtsPlaybackController Function()? voice,
    bool activeLoading = false,
    AgentDomainEntity? identity,
    List<Override> extra = const [],
    List<NavigatorObserver> observers = const [],
    FocusNode? drawerFocus,
  }) async {
    final mocks = await setUpTestGetIt();
    addTearDown(tearDownTestGetIt);
    // Her card hidden by the user earlier: her face is in the header.
    when(
      () => mocks.settingsDb.itemByKey(frontCompanionCardShownSettingsKey),
    ).thenAnswer((_) async => 'false');
    // On the fixtures' day: the open conversation is the one that moved
    // today, whenever the suite runs.
    await withClock(Clock.fixed(DateTime(2026, 10, 31, 12)), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                // At its own height, as the pane's column lays it out.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FrontChatHeader(
                      onClose: onClose ?? () {},
                      listBeside: listBeside,
                      drawerFocusNode: drawerFocus,
                    ),
                  ],
                ),
              ),
            ),
          ),
          navigatorObservers: observers,
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

  group('the row', () {
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
    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(FrontChatHeader)),
        );
    DesignSystemIconAction action(WidgetTester tester, Key key) =>
        tester.widget<DesignSystemIconAction>(find.byKey(key));

    testWidgets('is one line: the drawer toggle, her face, her name, a new '
        'chat and close, in that order', (tester) async {
      var closed = 0;
      await pumpHeader(tester, conversations: census, onClose: () => closed++);

      Rect at(Key key) => tester.getRect(find.byKey(key));
      final order = [
        FrontChatHeaderKeys.drawer,
        FrontChatHeaderKeys.figure,
        FrontChatHeaderKeys.title,
        FrontChatHeaderKeys.newChat,
        FrontChatHeaderKeys.close,
      ].map(at).toList();
      for (var i = 1; i < order.length; i++) {
        expect(order[i].left, greaterThanOrEqualTo(order[i - 1].right));
        expect(order[i].center.dy, closeTo(order[0].center.dy, 0.5));
      }
      // Her face, a rounded tile.
      expect(order[1].width, ControlSizes.avatarCompact);
      final tile = tester.widget<Container>(
        find.descendant(
          of: find.byKey(FrontChatHeaderKeys.figure),
          matching: find.byType(Container),
        ),
      );
      final shape = tile.decoration! as BoxDecoration;
      expect(shape.shape, BoxShape.rectangle);
      expect(shape.borderRadius, isNotNull);
      // Each control says what it does.
      expect(action(tester, FrontChatHeaderKeys.drawer).tooltip, 'Chats');
      expect(action(tester, FrontChatHeaderKeys.newChat).tooltip, 'New chat');
      expect(action(tester, FrontChatHeaderKeys.close).tooltip, 'Close');

      await tester.tap(find.byKey(FrontChatHeaderKeys.close));
      expect(closed, 1);
    });

    testWidgets('over the thread its one title names the open conversation, '
        'a step under her name in size and on two lines at most, in the same '
        'band: no overflow menu', (tester) async {
      await pumpHeader(tester, conversations: census);
      final tokens = tester.element(find.byType(FrontChatHeader)).designTokens;

      final title = tester.widget<Text>(find.byKey(FrontChatHeaderKeys.title));
      expect(title.data, 'Plan the census');
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(find.text('Companion'), findsNothing);
      expect(
        title.style!.fontSize,
        tokens.typography.styles.subtitle.subtitle2.fontSize,
      );
      expect(find.byType(FrontMenuButton), findsNothing);
      // A tap target and the band inset tall: the drawer's top row's height.
      expect(
        tester.getSize(find.byType(FrontChatHeader)).height,
        TapTargets.minimum + 2 * tokens.spacing.step2,
      );
    });

    group('her own name stays where no one conversation is the place', () {
      String title(WidgetTester tester) =>
          tester.widget<Text>(find.byKey(FrontChatHeaderKeys.title)).data!;

      testWidgets('one not begun: the index does not list it yet — on one '
          'line, in the subtitle size', (tester) async {
        await pumpHeader(tester);
        expect(title(tester), 'Companion');
        final text = tester.widget<Text>(
          find.byKey(FrontChatHeaderKeys.title),
        );
        expect(text.maxLines, 1);
        expect(
          text.style!.fontSize,
          tester
              .element(find.byType(FrontChatHeader))
              .designTokens
              .typography
              .styles
              .subtitle
              .subtitle1
              .fontSize,
        );
      });

      testWidgets('the inbox, which is every conversation at once', (
        tester,
      ) async {
        await pumpHeader(
          tester,
          conversations: census,
          extra: [frontInboxFilterProvider.overrideWith(_InboxOn.new)],
        );
        expect(title(tester), 'Companion');
      });

      testWidgets('beside the drawer, which marks the open row itself', (
        tester,
      ) async {
        await pumpHeader(tester, conversations: census, listBeside: true);
        expect(title(tester), 'Companion');
      });
    });

    testWidgets("on a wide panel the row keeps the thread's measure, centred, "
        'so its controls sit on the column they act on; beside the drawer it '
        'takes the width it is given', (tester) async {
      const wide = 900.0;
      await pumpHeader(tester, conversations: census, width: wide);
      final header = tester.getRect(find.byType(FrontChatHeader));
      final toggle = tester.getRect(find.byKey(FrontChatHeaderKeys.drawer));
      final close = tester.getRect(find.byKey(FrontChatHeaderKeys.close));
      expect(close.right - toggle.left, kProseMeasureWidth);
      expect(
        toggle.left - header.left,
        moreOrLessEquals(header.right - close.right, epsilon: 0.5),
      );

      await pumpHeader(
        tester,
        conversations: census,
        width: wide,
        listBeside: true,
      );
      final tokens = tester.element(find.byType(FrontChatHeader)).designTokens;
      expect(
        tester.getRect(find.byKey(FrontChatHeaderKeys.close)).right,
        tester.getRect(find.byType(FrontChatHeader)).right -
            tokens.spacing.step5,
      );
    });

    testWidgets('the toggle opens the drawer, and closes it again', (
      tester,
    ) async {
      await pumpHeader(tester, conversations: census);
      final listOpen = containerOf(
        tester,
      ).listen(frontConversationListOpenProvider, (_, _) {});
      addTearDown(listOpen.close);

      await tester.tap(find.byKey(FrontChatHeaderKeys.drawer));
      await tester.pump();
      expect(listOpen.read(), isTrue);

      await tester.tap(find.byKey(FrontChatHeaderKeys.drawer));
      await tester.pump();
      expect(listOpen.read(), isFalse);
    });

    testWidgets("under the drawer slid over it the row's end steps aside, "
        'keeping its room: one cross is never read for two', (tester) async {
      await pumpHeader(tester, conversations: census);
      final listOpen = containerOf(
        tester,
      ).listen(frontConversationListOpenProvider, (_, _) {});
      addTearDown(listOpen.close);
      bool painted(Key key) => tester
          .widget<Visibility>(
            find.ancestor(
              of: find.byKey(key),
              matching: find.byType(Visibility),
            ),
          )
          .visible;
      final closeAt = tester.getRect(find.byKey(FrontChatHeaderKeys.close));
      expect(painted(FrontChatHeaderKeys.close), isTrue);
      expect(painted(FrontChatHeaderKeys.newChat), isTrue);

      await tester.tap(find.byKey(FrontChatHeaderKeys.drawer));
      await tester.pump();
      expect(painted(FrontChatHeaderKeys.close), isFalse);
      expect(painted(FrontChatHeaderKeys.newChat), isFalse);
      // Nothing in the row moves.
      expect(tester.getRect(find.byKey(FrontChatHeaderKeys.close)), closeAt);

      await tester.tap(find.byKey(FrontChatHeaderKeys.drawer));
      await tester.pump();
      expect(painted(FrontChatHeaderKeys.close), isTrue);
    });

    testWidgets('hands its focus node to the toggle, so the drawer can give '
        'focus back to it', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpHeader(tester, conversations: census, drawerFocus: focus);

      // The toggle's own focus, not one around it.
      expect(
        focus.context?.findAncestorWidgetOfExactType<DesignSystemIconAction>(),
        isA<DesignSystemIconAction>().having(
          (action) => action.key,
          'key',
          FrontChatHeaderKeys.drawer,
        ),
      );
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);
    });

    testWidgets('a new chat starts an empty conversation', (tester) async {
      await pumpHeader(tester, conversations: census);
      final container = containerOf(tester);

      await tester.tap(find.byKey(FrontChatHeaderKeys.newChat));
      await tester.pump();

      expect(
        container.read(frontPickedConversationProvider),
        isNot(anyOf(isNull, 'c-1')),
      );
    });

    testWidgets('in a conversation not begun a new chat has nothing to '
        'start', (tester) async {
      await pumpHeader(tester);
      expect(action(tester, FrontChatHeaderKeys.newChat).onPressed, isNull);
    });

    testWidgets('in the inbox a new chat is offered even before any '
        'conversation: it leaves the inbox', (tester) async {
      await pumpHeader(
        tester,
        extra: [frontInboxFilterProvider.overrideWith(_InboxOn.new)],
      );
      expect(action(tester, FrontChatHeaderKeys.newChat).onPressed, isNotNull);
    });

    testWidgets('beside the drawer the row is her face, her name and close: '
        'the drawer has the rest', (tester) async {
      await pumpHeader(tester, conversations: census, listBeside: true);

      expect(find.byKey(FrontChatHeaderKeys.drawer), findsNothing);
      expect(find.byKey(FrontChatHeaderKeys.newChat), findsNothing);
      expect(find.byKey(FrontChatHeaderKeys.figure), findsOne);
      expect(find.byKey(FrontChatHeaderKeys.title), findsOne);
      expect(find.byKey(FrontChatHeaderKeys.close), findsOne);
    });

    testWidgets('carries none of her voice, her profile or her internals: '
        "they are the drawer's", (tester) async {
      await pumpHeader(
        tester,
        companion: true,
        conversations: census,
        extra: [companionCustomizationProvider.overrideWith(_KnownCustom.new)],
      );

      expect(find.byType(FrontVoiceButton), findsNothing);
      expect(find.byType(FrontVoiceSwitch), findsNothing);
      expect(find.text('AI profile'), findsNothing);
      expect(find.text('Agent internals'), findsNothing);
    });
  });

  testWidgets('with the companion off the spark every agent wears stands '
      'in for her', (tester) async {
    await pumpHeader(tester);
    expect(find.byType(CompanionView), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(FrontChatHeaderKeys.figure),
        matching: find.byIcon(LottiIcons.aiSpark),
      ),
      findsOneWidget,
    );
  });

  testWidgets('wears her face when the companion is on', (tester) async {
    await pumpHeader(tester, companion: true);
    expect(
      find.descendant(
        of: find.byKey(FrontChatHeaderKeys.figure),
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
          of: find.byKey(FrontChatHeaderKeys.figure),
          matching: find.byType(CompanionSpeaker),
        ),
      );
      expect(speaker.sourceId, 'front-chat:c-1');
      // Dressed for her surface, not the conversation: opening another
      // conversation keeps her outfit.
      expect(speaker.dressedFor, frontCompanionDressedFor);
    });

    testWidgets('she stays the same figure as she starts and stops '
        'speaking — her animator lives through it', (tester) async {
      final voice = _Voice(const TtsPlaybackState());
      await pumpHeader(
        tester,
        companion: true,
        conversations: census,
        voice: () => voice,
      );
      Element figure() => tester.element(
        find.descendant(
          of: find.byKey(FrontChatHeaderKeys.figure),
          matching: find.byType(CompanionSpeaker),
        ),
      );
      final before = figure();

      voice.play('front-chat:c-1');
      await tester.pump();
      expect(figure(), same(before));
    });

    testWidgets('a tap on her face shows her card in place: no page is '
        'pushed, her voice speaks on, and the face slides away while the card '
        'is out, the title taking its room', (tester) async {
      final semantics = tester.ensureSemantics();
      final observer = _PushObserver();
      final voice = _Voice(const TtsPlaybackState());
      await pumpHeader(
        tester,
        companion: true,
        conversations: census,
        voice: () => voice,
        observers: [observer],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FrontChatHeader)),
      );
      final shown = container.listen(
        frontCompanionCardShownProvider,
        (_, _) {},
      );
      addTearDown(shown.close);
      final toggle = find.byKey(FrontChatHeaderKeys.companion);
      voice.play('front-chat:c-1');
      await tester.pump();
      final pushesBefore = observer.pushed;
      final titleLeft = tester
          .getRect(find.byKey(FrontChatHeaderKeys.title))
          .left;

      expect(shown.read(), isFalse);
      expect(
        tester.getSemantics(toggle),
        matchesSemantics(
          label: 'Show companion',
          isButton: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(toggle);
      await tester.pump();
      expect(shown.read(), isTrue);
      expect(observer.pushed, pushesBefore, reason: 'no page of her own');
      expect(find.byType(CompanionStagePage), findsNothing);
      expect(voice.stoppedSources, isEmpty, reason: 'she speaks on');

      // Sliding away, not snapping: halfway, the face is still there.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(FrontChatHeaderKeys.figure), findsOne);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(FrontChatHeaderKeys.figure), findsNothing);
      expect(toggle, findsNothing);
      expect(
        tester.getRect(find.byKey(FrontChatHeaderKeys.title)).left,
        lessThan(titleLeft - ControlSizes.avatarCompact),
      );

      // The card put away, the face comes back.
      container.read(frontCompanionCardShownProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(toggle, findsOne);
      semantics.dispose();
    });

    testWidgets('a keyboard shows her card from her face: focused, Enter', (
      tester,
    ) async {
      await pumpHeader(tester, companion: true, conversations: census);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FrontChatHeader)),
      );
      Focus.of(
        tester.element(find.byKey(FrontChatHeaderKeys.figure)),
      ).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(container.read(frontCompanionCardShownProvider), isTrue);
    });

    testWidgets('in the inbox her face is no toggle: she has no card there', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        companion: true,
        conversations: census,
        extra: [frontInboxFilterProvider.overrideWith(_InboxOn.new)],
      );

      expect(find.byKey(FrontChatHeaderKeys.figure), findsOne);
      expect(find.byKey(FrontChatHeaderKeys.companion), findsNothing);
    });

    testWidgets('before any conversation resolves she simply stands', (
      tester,
    ) async {
      await pumpHeader(tester, companion: true, activeLoading: true);

      final standing = find.descendant(
        of: find.byKey(FrontChatHeaderKeys.figure),
        matching: find.byType(CompanionView),
      );
      expect(standing, findsOne);
      expect(find.byType(CompanionSpeaker), findsNothing);
      // Already in the outfit she keeps once a conversation resolves.
      final roll = ProviderScope.containerOf(
        tester.element(standing),
      ).read(companionLookRollProvider);
      expect(
        tester.widget<CompanionView>(standing).look.id,
        roll.outfitFor(frontCompanionDressedFor).id,
      );
    });

    testWidgets('fits a 360 dp phone with every control showing: the drawer '
        'toggle and the inbox count, her face, the title, a new chat and '
        'close', (tester) async {
      await pumpHeader(
        tester,
        companion: true,
        conversations: census,
        width: 360,
        thread: FrontChatThread(
          messages: const [],
          doorsByMessageId: {
            'u1': [
              FrontDoorEntry(
                doorId: 'd:door:0',
                record: FrontDoorRecord(
                  segmentIndex: 0,
                  text: 'A loose thought',
                  kind: FrontDestinationKind.unrouted,
                  status: FrontDoorStatus.done,
                  claimedAt: DateTime.utc(2026, 10, 26),
                  outcome: const FrontDoorInbox(),
                ),
              ),
            ],
          },
        ),
      );

      // A row that overflows reports it as an exception; none was.
      expect(tester.takeException(), isNull);
      expect(find.byKey(FrontChatHeaderKeys.inbox), findsOne);
      expect(find.byKey(FrontChatHeaderKeys.newChat), findsOne);
      final header = tester.getRect(find.byType(FrontChatHeader));
      expect(
        tester.getRect(find.byKey(FrontChatHeaderKeys.close)).right,
        lessThanOrEqualTo(header.right),
      );
      // The open conversation's title takes the room between her face and
      // the row's end, and is cut there rather than pushing a control out.
      expect(
        tester.getRect(find.byKey(FrontChatHeaderKeys.title)).right,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(FrontChatHeaderKeys.newChat)).left,
        ),
      );
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

    testWidgets('is a dot on the drawer toggle, never a count in the '
        'header, and still says how many to assistive technology', (
      tester,
    ) async {
      await pumpHeader(tester, thread: waiting(2));

      final dot = find.byKey(FrontChatHeaderKeys.inbox);
      final badge = tester.widget<DesignSystemBadge>(dot);
      expect(badge.tone, DesignSystemBadgeTone.warning);
      expect(badge.semanticLabel, 'Inbox 2');
      // On the glyph, inside its tap target, not beside it.
      final glyph = tester.getRect(find.byKey(FrontChatHeaderKeys.drawer));
      final rect = tester.getRect(dot);
      expect(glyph.contains(rect.topLeft), isTrue);
      expect(glyph.contains(rect.bottomRight), isTrue);
      // No number anywhere in the header: the drawer's Inbox row counts.
      expect(
        find.descendant(
          of: find.byType(FrontChatHeader),
          matching: find.text('2'),
        ),
        findsNothing,
      );
      expect(
        tester.getRect(find.byKey(FrontChatHeaderKeys.figure)).left,
        greaterThanOrEqualTo(glyph.right),
      );
    });

    testWidgets('a tap on the dot is a tap on the toggle: it opens the '
        'drawer', (tester) async {
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

/// Her saved customization, already known: she speaks her replies.
class _KnownCustom extends CompanionCustomizationController {
  @override
  bool get loaded => true;

  @override
  CompanionCustomization build() => const CompanionCustomization();
}

/// Counts the pages pushed over the header's own.
class _PushObserver extends NavigatorObserver {
  int pushed = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed++;
}

/// The inbox view, on.
class _InboxOn extends FrontInboxFilter {
  @override
  bool build() => true;
}
